import 'package:material_ui/material_ui.dart';

import '../../core/env.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ListView(
        children: [
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
        ],
      ),
    );
  }
}
