import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/meta_repository.dart';

/// Isi QR tanda tangan invoice (format teks, terbaca oleh scanner QR apa pun).
///
/// ```
/// UsahaKonten INVOICE TERVERIFIKASI
/// No: INV-202611-0001
/// Tgl: 2026-11-22
/// Dari: Toko Maju Jaya
/// Kepada: Budi
/// Total: Rp640000
/// Dibayar: Rp200000
/// Status: SEBAGIAN
/// TTD: Andi (Pemilik)
/// Kunci: 1a2b3c4d
/// Sig: <tanda tangan Ed25519, base64url>
/// ```
/// Tanda tangan dibuat atas semua baris di atas "Sig:" (kanonik, UTF-8).
class InvoiceQrPayload {
  const InvoiceQrPayload({
    required this.number,
    required this.date,
    required this.issuer,
    required this.party,
    required this.total,
    required this.paid,
    required this.status,
    required this.signer,
    required this.keyId,
    this.signature,
    this.isPurchase = false,
  });

  static const header = 'UsahaKonten INVOICE TERVERIFIKASI';
  static const headerPo = 'UsahaKonten PO TERVERIFIKASI';

  final String number;
  final String date; // yyyy-MM-dd
  final String issuer;
  final String party;
  final int total; // rupiah bulat
  final int paid;
  final String status; // LUNAS | SEBAGIAN | BELUM
  final String signer;
  final String keyId;
  final String? signature;
  final bool isPurchase; // dokumen pembelian (PO), bukan invoice penjualan

  /// Baris yang ditandatangani. Nilai dibersihkan dari baris baru agar format tidak bisa disusupi.
  String get signedText => [
        isPurchase ? headerPo : header,
        'No: ${_clean(number)}',
        'Tgl: $date',
        'Dari: ${_clean(issuer)}',
        'Kepada: ${_clean(party)}',
        'Total: Rp$total',
        'Dibayar: Rp$paid',
        'Status: $status',
        'TTD: ${_clean(signer)}',
        'Kunci: $keyId',
      ].join('\n');

  String encode() => '$signedText\nSig: ${signature ?? ''}';

  InvoiceQrPayload withSignature(String sig) => InvoiceQrPayload(
      number: number, date: date, issuer: issuer, party: party, total: total, paid: paid,
      status: status, signer: signer, keyId: keyId, signature: sig, isPurchase: isPurchase);

  static String _clean(String s) {
    final t = s.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return t.length > 80 ? t.substring(0, 80) : t;
  }

  /// Urai teks QR. Mengembalikan null bila bukan QR invoice UsahaKonten.
  static InvoiceQrPayload? parse(String raw) {
    final lines = raw.replaceAll('\r', '').split('\n');
    if (lines.isEmpty || (lines.first.trim() != header && lines.first.trim() != headerPo)) return null;
    final f = <String, String>{};
    for (final l in lines.skip(1)) {
      final i = l.indexOf(': ');
      if (i > 0) f[l.substring(0, i)] = l.substring(i + 2);
    }
    int? rp(String? v) => v == null ? null : int.tryParse(v.replaceFirst('Rp', ''));
    final total = rp(f['Total']), paid = rp(f['Dibayar']);
    if ([f['No'], f['Tgl'], f['Dari'], f['Kepada'], f['Status'], f['TTD'], f['Kunci'], f['Sig']].contains(null) ||
        total == null ||
        paid == null) {
      return null;
    }
    return InvoiceQrPayload(
      number: f['No']!, date: f['Tgl']!, issuer: f['Dari']!, party: f['Kepada']!, total: total, paid: paid,
      status: f['Status']!, signer: f['TTD']!, keyId: f['Kunci']!, signature: f['Sig'],
      isPurchase: lines.first.trim() == headerPo,
    );
  }

  static InvoiceQrPayload fromInvoice(InvoiceData d, {required String signer, required String keyId}) {
    final t = d.trx;
    String two(int v) => v.toString().padLeft(2, '0');
    return InvoiceQrPayload(
      number: t.number,
      date: '${t.trxDate.year}-${two(t.trxDate.month)}-${two(t.trxDate.day)}',
      issuer: d.profile.name,
      party: d.customer?.name ?? d.supplier?.name ?? 'Umum',
      total: t.total.round(),
      paid: t.paidAmount.round(),
      status: switch (t.status) { 'lunas' => 'LUNAS', 'sebagian' => 'SEBAGIAN', _ => 'BELUM' },
      signer: signer,
      keyId: keyId,
      isPurchase: t.type == 'purchase',
    );
  }
}

enum VerifyResult { valid, invalidSignature, otherKey, notInvoiceQr }

/// Pengelola kunci & tanda tangan invoice (Ed25519, offline).
/// Kunci rahasia (seed 32 byte) disimpan di Android Keystore/iOS Keychain lewat flutter_secure_storage;
/// kunci publik disimpan di tabel meta untuk verifikasi.
class InvoiceSigner {
  InvoiceSigner(this._meta, [FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final MetaRepository _meta;
  final FlutterSecureStorage _storage;
  final _algo = Ed25519();

  static const _kSeed = 'invoice_sign_seed_v1';
  static const metaPublicKey = 'invoice_sign_pub';
  static const metaSignerName = 'invoice_signer_name';
  static const metaSignerTitle = 'invoice_signer_title';
  static const metaQrEnabled = 'invoice_qr_enabled';

  static String keyIdFor(List<int> publicKey) =>
      crypto.sha256.convert(publicKey).toString().substring(0, 8);

  Future<SimpleKeyPair> _keyPair() async {
    var seedB64 = await _storage.read(key: _kSeed);
    if (seedB64 == null) {
      final r = Random.secure();
      seedB64 = base64Encode(List.generate(32, (_) => r.nextInt(256)));
      await _storage.write(key: _kSeed, value: seedB64);
    }
    final kp = await _algo.newKeyPairFromSeed(base64Decode(seedB64));
    final pub = (await kp.extractPublicKey()).bytes;
    if (await _meta.get(metaPublicKey) != base64Encode(pub)) await _meta.set(metaPublicKey, base64Encode(pub));
    return kp;
  }

  Future<String> keyId() async => keyIdFor((await (await _keyPair()).extractPublicKey()).bytes);

  Future<bool> qrEnabled() async => await _meta.get(metaQrEnabled) != '0';
  Future<void> setQrEnabled(bool v) => _meta.set(metaQrEnabled, v ? '1' : '0');

  /// "Nama (Jabatan)" penanda tangan; default nama usaha.
  Future<String> signerLabel(String fallback) async {
    final name = (await _meta.get(metaSignerName))?.trim();
    final title = (await _meta.get(metaSignerTitle))?.trim();
    final n = (name == null || name.isEmpty) ? fallback : name;
    return (title == null || title.isEmpty) ? n : '$n ($title)';
  }

  Future<InvoiceQrPayload> sign(InvoiceData d) async {
    final kp = await _keyPair();
    final kid = keyIdFor((await kp.extractPublicKey()).bytes);
    final payload = InvoiceQrPayload.fromInvoice(d, signer: await signerLabel(d.profile.name), keyId: kid);
    final sig = await _algo.sign(utf8.encode(payload.signedText), keyPair: kp);
    return payload.withSignature(base64Url.encode(sig.bytes).replaceAll('=', ''));
  }

  /// Verifikasi teks QR dengan kunci publik HP ini.
  Future<(VerifyResult, InvoiceQrPayload?)> verify(String raw) async {
    final p = InvoiceQrPayload.parse(raw);
    if (p == null) return (VerifyResult.notInvoiceQr, null);
    final kp = await _keyPair();
    final pub = await kp.extractPublicKey();
    if (keyIdFor(pub.bytes) != p.keyId) return (VerifyResult.otherKey, p);
    final ok = await verifyWithPublicKey(p, pub.bytes);
    return (ok ? VerifyResult.valid : VerifyResult.invalidSignature, p);
  }

  static Future<bool> verifyWithPublicKey(InvoiceQrPayload p, List<int> publicKey) async {
    final sigText = p.signature ?? '';
    List<int> sigBytes;
    try {
      sigBytes = base64Url.decode(base64Url.normalize(sigText));
    } on FormatException {
      return false;
    }
    if (sigBytes.length != 64) return false;
    return Ed25519().verify(
      utf8.encode(p.signedText),
      signature: Signature(sigBytes, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
    );
  }

  /// Hapus kunci (bagian dari Reset aplikasi).
  Future<void> clear() => _storage.delete(key: _kSeed);
}
