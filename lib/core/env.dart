/// Konfigurasi yang disuntikkan saat build:
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
/// SUPABASE_KEY = "Publishable key" (sb_publishable_...) atau "anon key" lama.
/// Di GitHub Actions nilainya diambil dari repository secrets.
/// JANGAN menulis URL/key langsung di kode.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && supabaseKey.isNotEmpty;
}
