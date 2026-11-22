import 'package:material_ui/material_ui.dart';

/// Penanda sementara untuk modul yang belum dibangun.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.features,
  });

  final IconData icon;
  final String title;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(icon, size: 64, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Modul ini sedang dibangun.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final f in features)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.check_circle_outline, color: scheme.primary),
                    title: Text(f),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
