import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import 'pin_service.dart';

/// "Reset aplikasi": hapus seluruh data lokal (database, lampiran, PIN).
class AppResetService {
  AppResetService(this._db, this._pins);

  final AppDatabase _db;
  final PinService _pins;

  /// Folder lampiran (gambar produk, aset konten) — ikut backup.
  static Future<Directory> attachmentsDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/attachments');
  }

  Future<void> resetAll() async {
    await _db.wipeAllData();
    final dir = await attachmentsDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    await _pins.clear();
  }
}
