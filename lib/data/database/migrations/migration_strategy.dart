import 'package:drift/drift.dart';

import '../app_database.dart';
import 'schema_v1.dart';

/// Versi skema saat ini. NAIKKAN saat mengubah skema + tambahkan langkah
/// di [_upgradeSteps] + file baru migrations/schema_vN.dart.
/// Nilai ini juga ditulis ke backup (meta.json) untuk validasi restore.
const int currentSchemaVersion = 1;

MigrationStrategy buildMigrationStrategy(AppDatabase db) {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in [...schemaV1Indexes, ...schemaV1Triggers]) {
        await db.customStatement(sql);
      }
      await db.into(db.businessProfile).insert(const BusinessProfileCompanion());
    },
    onUpgrade: (m, from, to) async {
      for (var v = from + 1; v <= to; v++) {
        final step = _upgradeSteps[v];
        if (step == null) {
          throw StateError('Langkah migrasi ke skema v$v belum ditulis');
        }
        await step(m, db);
      }
    },
    beforeOpen: (details) async {
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db
          .into(db.meta)
          .insertOnConflictUpdate(MetaCompanion.insert(key: 'schema_version', value: '$currentSchemaVersion'));
    },
  );
}

/// Langkah upgrade per versi: kunci = versi tujuan.
/// Contoh v2: `2: (m, db) async { await m.addColumn(db.products, db.products.weight); }`
final Map<int, Future<void> Function(Migrator m, AppDatabase db)> _upgradeSteps = {};
