import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';

/// Ditampilkan bila APK dibangun tanpa secret SUPABASE_URL / SUPABASE_KEY.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UsahaKonten',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Konfigurasi Belum Lengkap')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Icon(Icons.settings_suggest, size: 64),
            SizedBox(height: 16),
            Text(
              'APK ini dibangun tanpa alamat server Supabase.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 16),
            Text(
              '1. Buka github.com → repo → Settings → Secrets and variables → Actions.\n'
              '2. Tambahkan secret SUPABASE_URL dan SUPABASE_KEY '
              '(Supabase → Project Settings → API Keys → Publishable key).\n'
              '3. Buka tab Actions → Build APK → Run workflow.\n'
              '4. Unduh & instal APK yang baru.',
              style: TextStyle(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
