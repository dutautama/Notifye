import 'package:material_ui/material_ui.dart';

/// Tampilan error penuh dengan tombol "Coba lagi".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  static String friendly(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('unique constraint')) return 'Data dengan nilai yang sama sudah ada.';
    if (s.contains('foreign key constraint')) {
      return 'Data ini masih dipakai data lain sehingga tidak bisa dihapus.';
    }
    if (s.contains('check constraint')) return 'Ada nilai yang tidak valid.';
    return 'Terjadi kesalahan: $error';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.error_outline, size: 56, color: scheme.error),
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
