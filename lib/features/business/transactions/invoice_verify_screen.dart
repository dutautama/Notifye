import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../services/documents/invoice_signature.dart';
import '../../../widgets/barcode_scanner_page.dart';

/// Pindai QR tanda tangan invoice → cek keaslian & bandingkan dengan data transaksi di HP ini.
class InvoiceVerifyScreen extends ConsumerStatefulWidget {
  const InvoiceVerifyScreen({super.key});

  @override
  ConsumerState<InvoiceVerifyScreen> createState() => _InvoiceVerifyScreenState();
}

class _InvoiceVerifyScreenState extends ConsumerState<InvoiceVerifyScreen> {
  VerifyResult? _result;
  InvoiceQrPayload? _payload;
  Trx? _local;
  bool _busy = false;

  Future<void> _scan() async {
    final raw = await BarcodeScannerPage.scan(context);
    if (raw == null || !mounted) return;
    setState(() => _busy = true);
    final (result, payload) = await ref.read(invoiceSignerProvider).verify(raw);
    final local = payload == null ? null : await ref.read(transaksiRepositoryProvider).getByNumber(payload.number);
    if (!mounted) return;
    setState(() {
      _result = result;
      _payload = payload;
      _local = local;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Pindai QR di pojok kanan bawah invoice PDF (dari layar atau kertas cetakan).'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Pindai QR invoice'),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_result != null && !_busy) ...[
            const SizedBox(height: 16),
            _ResultCard(result: _result!),
            if (_payload != null) ...[
              const SizedBox(height: 12),
              _PayloadCard(p: _payload!, local: _local),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, title, body) = switch (result) {
      VerifyResult.valid => (
          Icons.verified,
          Colors.green.shade700,
          'ASLI',
          'Tanda tangan cocok dengan kunci HP ini. Isi QR tidak diubah sejak ditandatangani.'
        ),
      VerifyResult.invalidSignature => (
          Icons.gpp_bad,
          scheme.error,
          'TIDAK VALID',
          'Isi QR sudah diubah atau tanda tangannya palsu. Jangan percayai angka di invoice ini.'
        ),
      VerifyResult.otherKey => (
          Icons.help_outline,
          Colors.orange.shade800,
          'DIBUAT DENGAN KUNCI LAIN',
          'Invoice ini ditandatangani di HP/instalasi lain (mis. sebelum ganti HP atau reset). '
              'Keaslian tidak bisa dipastikan dari HP ini.'
        ),
      VerifyResult.notInvoiceQr => (
          Icons.qr_code_2,
          scheme.onSurfaceVariant,
          'BUKAN QR INVOICE',
          'QR yang dipindai bukan tanda tangan invoice UsahaKonten.'
        ),
    };
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(body),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PayloadCard extends StatelessWidget {
  const _PayloadCard({required this.p, required this.local});
  final InvoiceQrPayload p;
  final Trx? local;

  @override
  Widget build(BuildContext context) {
    final l = local;
    final changed = l != null && (l.total.round() != p.total || l.paidAmount.round() != p.paid);
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 90, child: Text(a, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(b)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Isi QR', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          row('Nomor', p.number),
          row('Tanggal', p.date),
          row('Dari', p.issuer),
          row('Kepada', p.party),
          row('Total', Fmt.rupiah(p.total)),
          row('Dibayar', Fmt.rupiah(p.paid)),
          row('Status', p.status),
          row('Ditandatangani', p.signer),
          row('ID kunci', p.keyId),
          const Divider(),
          if (l == null)
            const Text('Transaksi dengan nomor ini tidak ada di HP ini.')
          else ...[
            Text(
              changed
                  ? 'Data di HP sekarang berbeda (total ${Fmt.rupiah(l.total)}, dibayar ${Fmt.rupiah(l.paidAmount)}'
                      '${l.deletedAt != null ? ', DIBATALKAN' : ''}) — invoice ini versi lama.'
                  : l.deletedAt != null
                      ? 'Transaksi ini sudah DIBATALKAN di HP ini.'
                      : 'Sesuai dengan data transaksi terkini di HP ini.',
              style: TextStyle(
                  color: changed || l.deletedAt != null ? Colors.orange.shade800 : Colors.green.shade700,
                  fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () => context.push('/usaha/transaksi/${l.id}'),
              child: const Text('Buka transaksi'),
            ),
          ],
        ]),
      ),
    );
  }
}
