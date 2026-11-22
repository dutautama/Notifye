/// Validator form berbahasa Indonesia. Kembalikan null bila valid.
class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? v, [String message = 'Wajib diisi']) =>
      (v == null || v.trim().isEmpty) ? message : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
    if (!_emailRe.hasMatch(v.trim())) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password wajib diisi';
    if (v.length < 8) return 'Minimal 8 karakter';
    return null;
  }

  /// Angka ≥ 0. Menerima format "1.500.000" atau "1500000".
  static String? nonNegativeNumber(String? v, {bool required = true}) {
    if (v == null || v.trim().isEmpty) return required ? 'Wajib diisi' : null;
    final n = parseNumber(v);
    if (n == null) return 'Angka tidak valid';
    if (n < 0) return 'Tidak boleh negatif';
    return null;
  }

  /// "1.500.000" → 1500000, "12,5" → 12.5
  static double? parseNumber(String v) =>
      double.tryParse(v.trim().replaceAll('.', '').replaceAll(',', '.'));
}
