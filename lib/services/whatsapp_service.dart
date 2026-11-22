import 'package:url_launcher/url_launcher.dart';

/// Membuka WhatsApp (wa.me) dengan pesan terisi. Tanpa API berbayar.
class WhatsAppService {
  WhatsAppService._();

  /// "0812-3456-789" / "+62 812..." / "812..." → "62812..."
  static String? normalizePhone(String? raw) {
    if (raw == null) return null;
    var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (p.isEmpty) return null;
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (p.startsWith('8')) p = '62$p';
    return p.length >= 10 ? p : null;
  }

  /// Mengembalikan false bila nomor tidak valid / WhatsApp tidak bisa dibuka.
  static Future<bool> send({String? phone, required String message}) async {
    final normalized = normalizePhone(phone);
    final uri = Uri.https(
      'wa.me',
      normalized == null ? '/' : '/$normalized',
      {'text': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
