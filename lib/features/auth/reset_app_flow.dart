import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/app_providers.dart';
import 'app_reset_service.dart';
import 'auth_controller.dart';

const resetConfirmWord = 'HAPUS';

/// Reset aplikasi dengan konfirmasi ganda:
/// 1) dialog peringatan, 2) ketik kata "HAPUS".
Future<void> runResetAppFlow(BuildContext context, WidgetRef ref) async {
  final step1 = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber, color: Theme.of(ctx).colorScheme.error),
      title: const Text('Reset aplikasi?'),
      content: const Text(
        'SEMUA data di HP ini akan dihapus permanen: produk, pelanggan, transaksi, '
        'konten, lampiran, dan PIN.\n\n'
        'Pastikan Anda sudah punya file backup terbaru jika ingin memulihkan data.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjut')),
      ],
    ),
  );
  if (step1 != true || !context.mounted) return;

  final step2 = await showDialog<bool>(
    context: context,
    builder: (ctx) => const _TypeToConfirmDialog(),
  );
  if (step2 != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await AppResetService(ref.read(databaseProvider), ref.read(pinServiceProvider)).resetAll();
    ref.read(authControllerProvider.notifier).markReset();
    messenger.showSnackBar(const SnackBar(content: Text('Aplikasi sudah direset')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Reset gagal: $e')));
  }
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctrl.text.trim() == resetConfirmWord;
    return AlertDialog(
      title: const Text('Konfirmasi terakhir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ketik HAPUS (huruf besar) untuk menghapus semua data.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: resetConfirmWord),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size(0, 40),
          ),
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Hapus semua'),
        ),
      ],
    );
  }
}
