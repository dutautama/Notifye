import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../providers/app_providers.dart';
import '../../services/backup/backup_codec.dart';
import '../../services/backup/backup_service.dart';
import '../../widgets/section_card.dart';

final _backupListProvider = FutureProvider.autoDispose<(List<BackupFileInfo>, DateTime?)>((ref) async {
  final svc = ref.watch(backupServiceProvider);
  return (await svc.listBackups(), await svc.lastAutoBackupAt());
});

const _tableLabels = {
  'products': 'Produk/jasa',
  'customers': 'Pelanggan',
  'suppliers': 'Supplier',
  'transactions': 'Transaksi',
  'payments': 'Pembayaran',
  'content_ideas': 'Ide konten',
  'content_schedules': 'Jadwal konten',
  'content_publications': 'Publikasi',
};

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  String? _busy;

  BackupService get _svc => ref.read(backupServiceProvider);

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } on BackupFormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
      ref.invalidate(_backupListProvider);
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createAndShare() => _run('Membuat backup…', () async {
        final file = await _svc.createBackup();
        await _svc.share(file);
      });

  Future<void> _shareLatest() => _run('Menyiapkan…', () async {
        final list = await _svc.listBackups();
        final file = list.isEmpty ? await _svc.createBackup() : list.first.file;
        await _svc.share(file);
      });

  Future<void> _pickAndRestore() async {
    final picked = await FilePicker.pickFile(dialogTitle: 'Pilih file backup (.zip / .json)');
    if (picked == null) return;
    ParsedBackup? parsed;
    await _run('Membaca file…', () async {
      parsed = await _svc.parseBytes(await picked.readAsBytes());
    });
    if (parsed != null) await _confirmRestore(parsed!, picked.name);
  }

  Future<void> _restoreLocal(BackupFileInfo info) async {
    ParsedBackup? parsed;
    await _run('Membaca file…', () async => parsed = await _svc.parse(info.file));
    if (parsed != null) await _confirmRestore(parsed!, info.name);
  }

  Future<void> _confirmRestore(ParsedBackup backup, String fileName) async {
    if (!mounted) return;
    final counts = backup.rowCounts;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Pulihkan data?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (backup.createdAt != null) Text('Dibuat: ${Fmt.dateTime(backup.createdAt)}'),
                Text('Sumber: ${backup.source == 'supabase' ? 'Export Supabase (lama)' : 'Backup UsahaKonten'}'
                    ' • skema v${backup.schemaVersion}'),
                const SizedBox(height: 8),
                for (final e in _tableLabels.entries)
                  if ((counts[e.key] ?? 0) > 0) Text('• ${e.value}: ${counts[e.key]}'),
                if (backup.attachments.isNotEmpty) Text('• Lampiran: ${backup.attachments.length} file'),
                const SizedBox(height: 12),
                Text('Ganti semua (Replace)', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error)),
                const Text('Data di HP ini dihapus lalu diganti persis dengan isi backup. '
                    'Cocok untuk pindah HP / mengembalikan data.'),
                const SizedBox(height: 8),
                const Text('Gabungkan (Merge)', style: TextStyle(fontWeight: FontWeight.w600)),
                const Text('Hanya menambah data dari backup yang belum ada di HP ini. '
                    'Data di HP ini tidak diubah; transaksi baru ikut memperbarui stok.'),
                const SizedBox(height: 8),
                Text('Sebelum memulihkan, backup otomatis data saat ini dibuat dulu.',
                    style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, RestoreMode.merge), child: const Text('Gabungkan')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error, minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(ctx, RestoreMode.replace),
              child: const Text('Ganti semua'),
            ),
          ],
        );
      },
    );
    if (mode == null) return;
    await _run('Memulihkan data…', () async {
      final r = await _svc.restore(backup, mode);
      _snack(mode == RestoreMode.replace
          ? 'Data berhasil dipulihkan (${r.totalInserted} baris).'
          : 'Penggabungan selesai: ${r.totalInserted} baris baru, ${r.skipped} sudah ada.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_backupListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: AbsorbPointer(
        absorbing: _busy != null,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy != null) ...[
              LinearProgressIndicator(semanticsLabel: _busy),
              const SizedBox(height: 8),
              Text(_busy!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Data hanya tersimpan di HP ini. Simpan backup di Google Drive secara rutin '
                  'agar data aman jika HP hilang, rusak, atau aplikasi ter-uninstall.',
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _createAndShare,
              icon: const Icon(Icons.backup_outlined),
              label: const Text('Buat backup & bagikan'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _shareLatest,
              icon: const Icon(Icons.add_to_drive),
              label: const Text('Kirim backup terakhir ke Drive'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _pickAndRestore,
              icon: const Icon(Icons.restore),
              label: const Text('Pulihkan dari file…'),
            ),
            const SizedBox(height: 20),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Gagal membaca daftar backup: $e'),
              data: (d) {
                final (list, lastAuto) = d;
                return SectionCard(
                  title: 'Backup tersimpan di HP',
                  icon: Icons.folder_zip_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Backup otomatis dibuat setiap 7 hari saat aplikasi dibuka '
                          '(${BackupService.autoKeep} terakhir disimpan). '
                          'Terakhir: ${lastAuto == null ? 'belum pernah' : Fmt.dateTime(lastAuto)}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (list.isEmpty) const EmptyHint('Belum ada backup.'),
                      for (final b in list)
                        ListTile(
                          leading: Icon(b.isAuto ? Icons.schedule : Icons.backup_outlined),
                          title: Text(b.name, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${b.isAuto ? 'Otomatis' : 'Manual'} • '
                              '${Fmt.dateTime(b.modified)} • ${(b.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Pilihan',
                            onSelected: (v) => v == 'share'
                                ? _run('Menyiapkan…', () => _svc.share(b.file).then((_) {}))
                                : _restoreLocal(b),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'share', child: Text('Bagikan / kirim ke Drive')),
                              PopupMenuItem(value: 'restore', child: Text('Pulihkan')),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
