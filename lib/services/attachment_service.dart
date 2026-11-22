import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../data/database/app_database.dart';
import '../features/auth/app_reset_service.dart';

/// Lampiran lokal (gambar produk, logo, aset konten) di `<documents>/attachments/`.
/// Database menyimpan path RELATIF agar ikut backup & tetap valid di HP lain.
class AttachmentService {
  AttachmentService._();

  static const maxBytes = 25 * 1024 * 1024;

  static Future<File> fileFor(String relativePath) async =>
      File('${(await AppResetService.attachmentsDir()).path}/$relativePath');

  /// Pilih file lalu salin ke `attachments/<folder>/<uuid>.<ext>`.
  /// Mengembalikan (pathRelatif, namaAsli) atau null bila batal.
  static Future<(String, String)?> pick(String folder, {FileType type = FileType.any}) async {
    final picked = await FilePicker.pickFile(type: type);
    if (picked == null) return null;
    final size = await picked.length();
    if (size != null && size > maxBytes) {
      throw StateError('File terlalu besar (maksimal 25 MB).');
    }
    final ext = (picked.extension ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final rel = '$folder/${newId()}${ext.isEmpty ? '' : '.$ext'}';
    final file = await fileFor(rel);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await picked.readAsBytes(), flush: true);
    return (rel, picked.name);
  }

  static Future<void> delete(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final f = await fileFor(relativePath);
    if (await f.exists()) await f.delete();
  }
}
