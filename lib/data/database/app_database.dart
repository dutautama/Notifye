import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'migrations/migration_strategy.dart';
import 'tables.dart';

export 'tables.dart' show newId;

part 'app_database.g.dart';

/// Daftar tabel yang ikut backup/restore & reset, urut aman untuk INSERT
/// (induk dulu). Hapus dilakukan dengan urutan terbalik.
const backupTableOrder = <String>[
  'business_profile',
  'doc_counters',
  'categories',
  'products',
  'customers',
  'suppliers',
  'transactions',
  'transaction_items',
  'payments',
  'stock_movements',
  'content_ideas',
  'content_assets',
  'content_schedules',
  'content_publications',
  'content_product_links',
];

@DriftDatabase(tables: [
  Meta,
  BusinessProfile,
  DocCounters,
  Categories,
  Products,
  Customers,
  Suppliers,
  Transactions,
  TransactionItems,
  Payments,
  StockMovements,
  ContentIdeas,
  ContentAssets,
  ContentSchedules,
  ContentPublications,
  ContentProductLinks,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static const fileName = 'usahakonten';

  static QueryExecutor _openDefault() => driftDatabase(name: fileName);

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);

  /// Hapus SEMUA data (dipakai "Reset aplikasi" & restore mode Replace).
  /// Menghapus item transaksi memicu trigger stok yang menulis riwayat baru,
  /// jadi stock_movements dikosongkan sekali lagi di akhir.
  Future<void> wipeAllData() async {
    await customStatement('PRAGMA foreign_keys = OFF');
    try {
      await transaction(() async {
        for (final table in backupTableOrder.reversed) {
          await customStatement('DELETE FROM "$table"');
        }
        await customStatement('DELETE FROM stock_movements');
        await into(businessProfile).insert(const BusinessProfileCompanion());
      });
    } finally {
      await customStatement('PRAGMA foreign_keys = ON');
    }
  }
}
