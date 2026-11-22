import '../database/app_database.dart';

/// Pengaturan internal aplikasi (key-value di tabel meta).
class MetaRepository {
  MetaRepository(this._db);
  final AppDatabase _db;

  static const lastAutoBackup = 'last_auto_backup';
  static const printerAddress = 'printer_address';
  static const printerName = 'printer_name';
  static const printerWidth = 'printer_width_mm';

  Future<String?> get(String key) async =>
      (await (_db.select(_db.meta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> set(String key, String value) =>
      _db.into(_db.meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));

  Future<void> remove(String key) => (_db.delete(_db.meta)..where((m) => m.key.equals(key))).go();
}
