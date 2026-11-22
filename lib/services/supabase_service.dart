import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// Titik akses tunggal ke Supabase. Layar TIDAK boleh memanggil
/// Supabase.instance langsung — gunakan service per modul yang memakai [db].
class SupabaseService {
  SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static String? get userId => auth.currentUser?.id;
}
