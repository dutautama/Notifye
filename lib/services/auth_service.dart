import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Autentikasi admin tunggal (email + password).
/// Akun dibuat manual di Supabase Dashboard; pendaftaran publik dimatikan.
class AuthService {
  AuthService(this._auth);

  final GoTrueClient _auth;

  factory AuthService.instance() => AuthService(SupabaseService.auth);

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentSession != null;
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      await _ensureBusinessProfile();
    } on AuthException catch (e) {
      throw AuthFailure(translateAuthError(e.message, e.code));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> changePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(translateAuthError(e.message, e.code));
    }
  }

  /// Membuat baris profil usaha pada login pertama (idempoten).
  Future<void> _ensureBusinessProfile() async {
    await SupabaseService.client
        .from('business_profile')
        .upsert({'owner_id': currentUser!.id}, ignoreDuplicates: true);
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Menerjemahkan pesan error Supabase Auth ke Bahasa Indonesia.
String translateAuthError(String message, [String? code]) {
  final m = message.toLowerCase();
  if (code == 'invalid_credentials' || m.contains('invalid login credentials')) {
    return 'Email atau password salah.';
  }
  if (code == 'email_not_confirmed' || m.contains('email not confirmed')) {
    return 'Email belum dikonfirmasi. Konfirmasi user di Supabase Dashboard.';
  }
  if (code == 'over_request_rate_limit' || m.contains('rate limit') || m.contains('too many')) {
    return 'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.';
  }
  if (code == 'weak_password' || m.contains('password should be')) {
    return 'Password terlalu lemah (minimal 8 karakter).';
  }
  if (code == 'same_password' || m.contains('different from the old')) {
    return 'Password baru harus berbeda dari password lama.';
  }
  if (m.contains('socket') || m.contains('network') || m.contains('failed host lookup')) {
    return 'Tidak ada koneksi internet.';
  }
  return 'Gagal masuk: $message';
}
