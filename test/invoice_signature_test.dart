import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/meta_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';
import 'package:usahakonten/services/documents/invoice_pdf.dart';
import 'package:usahakonten/services/documents/invoice_signature.dart';

import 'helpers/fake_secure_storage.dart';

List<int> _hex(String h) => [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('id_ID'));

  late AppDatabase db;
  late InvoiceRepository inv;
  late InvoiceSigner signer;
  late FakeSecureStorage store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    inv = InvoiceRepository(db);
    store = FakeSecureStorage();
    signer = InvoiceSigner(MetaRepository(db), store);
  });
  tearDown(() => db.close());

  Future<InvoiceData> invoice({String party = 'Budi Santoso'}) async {
    await inv.updateProfile(const BusinessProfileCompanion(name: Value('Toko Maju Jaya')));
    final c = await db.into(db.customers).insertReturning(CustomersCompanion.insert(name: party));
    final t = await TransaksiRepository(db, inv).createTransaction(TrxInput(
        type: 'sale', customerId: c.id, trxDate: DateTime(2026, 11, 22), initialPayment: 200000,
        items: const [TrxItemInput(name: 'Desain logo', qty: 1, price: 640000)]));
    return (await inv.getInvoiceData(t.id))!;
  }

  test('Ed25519 sesuai vektor uji resmi RFC 8032 (test 1)', () async {
    final kp = await Ed25519().newKeyPairFromSeed(_hex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'));
    final pub = await kp.extractPublicKey();
    expect(pub.bytes, _hex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'));
    final sig = await Ed25519().sign(const [], keyPair: kp);
    expect(sig.bytes, _hex('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155'
        '5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b'));
  });

  test('tanda tangan → QR → verifikasi ASLI; isi QR terbaca manusia', () async {
    final qr = await signer.sign(await invoice());
    final text = qr.encode();
    expect(text, startsWith('UsahaKonten INVOICE TERVERIFIKASI\nNo: INV-202611-0001\nTgl: 2026-11-22'));
    expect(text, contains('Total: Rp640000\nDibayar: Rp200000\nStatus: SEBAGIAN'));
    expect(text, contains('TTD: Toko Maju Jaya'));
    final (result, parsed) = await signer.verify(text);
    expect(result, VerifyResult.valid);
    expect(parsed!.party, 'Budi Santoso');
    expect(text.length, lessThan(400), reason: 'QR tetap mudah dipindai');
  });

  test('angka diubah, tanda tangan dirusak, kunci lain, QR lain', () async {
    final text = (await signer.sign(await invoice())).encode();
    expect((await signer.verify(text.replaceFirst('Total: Rp640000', 'Total: Rp64000'))).$1, VerifyResult.invalidSignature);
    expect((await signer.verify(text.replaceFirst('Status: SEBAGIAN', 'Status: LUNAS'))).$1, VerifyResult.invalidSignature);
    final sigLine = text.split('\n').last;
    final broken = text.replaceFirst(sigLine, 'Sig: ${sigLine.substring(5, 20)}');
    expect((await signer.verify(broken)).$1, VerifyResult.invalidSignature);
    // HP lain (kunci berbeda) → bukan "palsu", tapi tidak bisa dipastikan.
    final other = InvoiceSigner(MetaRepository(db), FakeSecureStorage());
    expect((await other.verify(text)).$1, VerifyResult.otherKey);
    expect((await signer.verify('https://contoh.com')).$1, VerifyResult.notInvoiceQr);
    expect((await signer.verify('UsahaKonten INVOICE TERVERIFIKASI\nNo: X')).$1, VerifyResult.notInvoiceQr);
  });

  test('nama berisi baris baru tidak bisa menyusupkan baris palsu', () async {
    final qr = await signer.sign(await invoice(party: 'Budi\nTotal: Rp1'));
    final text = qr.encode();
    expect(text.split('\n').where((l) => l.startsWith('Total:')), hasLength(1));
    expect((await signer.verify(text)).$1, VerifyResult.valid);
  });

  test('kunci tetap sama antar panggilan, nama & jabatan penanda tangan, reset menghapus kunci', () async {
    final k1 = await signer.keyId();
    expect(await signer.keyId(), k1);
    final meta = MetaRepository(db);
    await meta.set(InvoiceSigner.metaSignerName, 'Andi');
    await meta.set(InvoiceSigner.metaSignerTitle, 'Pemilik');
    final qr = await signer.sign(await invoice());
    expect(qr.signer, 'Andi (Pemilik)');
    await signer.clear();
    expect(await signer.keyId(), isNot(k1));
  });

  test('PDF invoice berisi blok tanda tangan & QR', () async {
    final d = await invoice();
    final qr = await signer.sign(d);
    final bytes = await buildInvoicePdf(d, qr: qr);
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    final out = Platform.environment['UK_DOC_OUT'];
    if (out != null) {
      File('$out/invoice-ttd.pdf').writeAsBytesSync(bytes);
      File('$out/invoice-ttd-qr.txt').writeAsStringSync(qr.encode());
    }
  });
}
