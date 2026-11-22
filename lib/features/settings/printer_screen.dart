import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/app_providers.dart';
import '../../services/documents/escpos.dart';
import '../../services/printer_service.dart';
import '../../widgets/form_fields.dart';

class PrinterScreen extends ConsumerStatefulWidget {
  const PrinterScreen({super.key});

  @override
  ConsumerState<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends ConsumerState<PrinterScreen> {
  List<PairedPrinter>? _paired;
  PairedPrinter? _saved;
  int _width = 58;
  String? _error;
  bool _busy = false;

  PrinterService get _svc => ref.read(printerServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _saved = await _svc.savedPrinter();
    _width = await _svc.paperWidthMm();
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _paired = await _svc.pairedPrinters();
    } on PrinterException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal membaca perangkat Bluetooth: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final p = EscPos(width: await _svc.charsPerLine())
        ..align(1)
        ..bold(true)
        ..text('UsahaKonten')
        ..bold(false)
        ..text('Tes printer berhasil')
        ..line()
        ..leftRight('Kiri', 'Kanan')
        ..feed(3)
        ..cut();
      await _svc.printBytes(p.bytes);
      if (mounted) showSnack(context, 'Halaman tes dikirim');
    } on PrinterException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Bluetooth')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_busy) const LinearProgressIndicator(),
          const Text(
            '1. Nyalakan printer thermal dan pair dulu di Setelan HP → Bluetooth.\n'
            '2. Ketuk "Cari printer", lalu pilih printer Anda.\n'
            '3. Ketuk "Cetak halaman tes".',
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.print),
            title: Text(_saved?.name ?? 'Belum ada printer dipilih'),
            subtitle: Text(_saved?.address ?? ''),
          ),
          const Text('Lebar kertas'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {_width},
            onSelectionChanged: (s) async {
              setState(() => _width = s.first);
              await _svc.setPaperWidthMm(s.first);
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Cari printer (yang sudah di-pair)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _busy || _saved == null ? null : _test,
            icon: const Icon(Icons.receipt_long),
            label: const Text('Cetak halaman tes'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_paired != null) ...[
            const SizedBox(height: 16),
            if (_paired!.isEmpty) const Text('Tidak ada perangkat Bluetooth yang di-pair.'),
            RadioGroup<String>(
              groupValue: _saved?.address,
              onChanged: (addr) async {
                final p = _paired!.firstWhere((x) => x.address == addr);
                await _svc.savePrinter(p);
                setState(() => _saved = p);
              },
              child: Column(
                children: [
                  for (final p in _paired!)
                    RadioListTile<String>(value: p.address, title: Text(p.name), subtitle: Text(p.address)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
