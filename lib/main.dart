import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/env.dart';
import 'screens/setup/config_missing_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  // URL & anon key Supabase disuntikkan saat build oleh GitHub Actions
  // (--dart-define). Jika kosong, tampilkan panduan konfigurasi.
  if (!Env.isConfigured) {
    runApp(const ConfigMissingApp());
    return;
  }

  await SupabaseService.init();
  runApp(const ProviderScope(child: UsahaKontenApp()));
}
