import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Simpan dokumen sementara lalu buka menu bagikan (WhatsApp, email, Drive, ...).
class ShareService {
  ShareService._();

  static String safeFileName(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');

  static Future<File> saveTemp(String fileName, List<int> bytes) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/dokumen');
    await dir.create(recursive: true);
    final f = File('${dir.path}/${safeFileName(fileName)}');
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  static Future<void> shareFile(File file, {required String mime, String? subject, String? text}) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mime)],
          subject: subject,
          text: text,
        ),
      );
}
