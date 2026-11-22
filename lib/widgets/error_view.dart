import 'package:material_ui/material_ui.dart';

/// Tampilan error penuh dengan tombol "Coba lagi".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  static String friendly(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('socket') || s.contains('failed host lookup') || s.contains('network')) {
      return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
    }
    if (s.contains('jwt') || s.contains('401')) {
      return 'Sesi berakhir. Silakan keluar lalu login kembali.';
    }
    if (s.contains('does not exist') || s.contains('42p01') || s.contains('pgrst205')) {
      return 'Tabel database belum dibuat. Jalankan file SQL migrasi di Supabase SQL Editor.';
    }
    return 'Terjadi kesalahan: $error';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.cloud_off, size: 56, color: scheme.error),
        const SizedBox(height: 16),
        Text(friendly(error), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba lagi'),
          ),
        ),
      ],
    );
  }
}
