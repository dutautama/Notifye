import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_info.dart';
import '../auth/auth_controller.dart';
import '../auth/reset_app_flow.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _Header('Usaha'),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Profil Usaha'),
            subtitle: const Text('Nama, logo, alamat, info pembayaran di invoice'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profil-usaha'),
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Printer Bluetooth'),
            subtitle: const Text('Printer struk thermal 58/80 mm'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/printer'),
          ),
          const _Header('Data'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Simpan ke Drive, pindah HP, backup otomatis mingguan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/backup'),
          ),
          const _Header('Keamanan'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Ubah PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ubah-pin'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Kunci sekarang'),
            subtitle: const Text('Otomatis terkunci 1 menit setelah aplikasi ditinggal'),
            onTap: () => ref.read(authControllerProvider.notifier).lock(),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text('Reset aplikasi', style: TextStyle(color: scheme.error)),
            subtitle: const Text('Hapus semua data lokal di HP ini'),
            onTap: () => runResetAppFlow(context, ref),
          ),
          const _Header('Tentang'),
          const ListTile(
            leading: Icon(Icons.offline_bolt_outlined),
            title: Text('Mode penyimpanan'),
            subtitle: Text('100% offline — data hanya tersimpan di HP ini'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versi Aplikasi'),
            subtitle: Text(AppInfo.version),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
