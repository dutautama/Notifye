import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/app_providers.dart';
import '../../services/documents/invoice_signature.dart';
import '../../widgets/form_fields.dart';

/// Pengaturan tanda tangan QR di invoice PDF.
class InvoiceSignatureScreen extends ConsumerStatefulWidget {
  const InvoiceSignatureScreen({super.key});

  @override
  ConsumerState<InvoiceSignatureScreen> createState() => _InvoiceSignatureScreenState();
}

class _InvoiceSignatureScreenState extends ConsumerState<InvoiceSignatureScreen> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  bool _enabled = true;
  String? _keyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meta = ref.read(metaRepositoryProvider);
    final signer = ref.read(invoiceSignerProvider);
    _name.text = await meta.get(InvoiceSigner.metaSignerName) ?? '';
    _title.text = await meta.get(InvoiceSigner.metaSignerTitle) ?? '';
    _enabled = await signer.qrEnabled();
    try {
      _keyId = await signer.keyId();
    } catch (_) {
      _keyId = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final meta = ref.read(metaRepositoryProvider);
    await meta.set(InvoiceSigner.metaSignerName, _name.text.trim());
    await meta.set(InvoiceSigner.metaSignerTitle, _title.text.trim());
    await ref.read(invoiceSignerProvider).setQrEnabled(_enabled);
    if (mounted) {
      showSnack(context, 'Pengaturan tanda tangan tersimpan');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tanda tangan invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Invoice PDF diberi QR tanda tangan digital. Isinya (nomor, tanggal, total, dibayar, status) '
                'bisa dibaca dengan scanner QR apa pun. Keasliannya dicek di menu "Verifikasi invoice" '
                'di aplikasi ini — angka yang diubah setelah ditandatangani akan ketahuan.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan QR tanda tangan di invoice'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nama penanda tangan', hintText: 'Kosongkan = nama usaha'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Jabatan', hintText: 'mis. Pemilik'),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: const Text('ID kunci tanda tangan HP ini'),
            subtitle: Text(_keyId ?? 'Belum tersedia'),
          ),
          const Text(
            'Kunci rahasia tersimpan aman di HP ini dan tidak ikut file backup. Setelah pindah HP atau '
            'reset aplikasi, kunci baru dibuat: invoice lama tetap sah, tetapi hanya bisa diverifikasi '
            'sebagai "dibuat dengan kunci lain".',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Simpan')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => context.push('/verifikasi-invoice'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Verifikasi invoice (pindai QR)'),
          ),
        ],
      ),
    );
  }
}
