import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/env.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda perlu login lagi untuk membuka aplikasi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (ok == true) await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.person, color: scheme.onPrimaryContainer),
            ),
            title: Text(user?.email ?? '-'),
            subtitle: const Text('Admin'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.business),
            title: Text('Profil Usaha'),
            subtitle: Text('Segera hadir'),
          ),
          const ListTile(
            leading: Icon(Icons.print),
            title: Text('Printer Bluetooth'),
            subtitle: Text('Segera hadir'),
          ),
          const ListTile(
            leading: Icon(Icons.backup),
            title: Text('Backup & Export Data'),
            subtitle: Text('Segera hadir'),
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Ganti Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ganti-password'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_done_outlined),
            title: const Text('Server Supabase'),
            subtitle: Text(Uri.parse(Env.supabaseUrl).host),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versi Aplikasi'),
            subtitle: Text(Env.appVersion),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text('Keluar', style: TextStyle(color: scheme.error)),
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
