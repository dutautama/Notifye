import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../data/database/migrations/migration_strategy.dart';
import '../../data/database/migrations/schema_v2.dart';

const backupFormat = 'usahakonten-backup';

enum RestoreMode { replace, merge }

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RestoreResult {
  const RestoreResult({required this.inserted, required this.skipped, required this.source});
  final Map<String, int> inserted;
  final int skipped;
  final String source; // 'usahakonten' | 'supabase'
  int get totalInserted => inserted.values.fold(0, (a, b) => a + b);
}

/// Urutan INSERT saat restore: anak SEBELUM induk untuk transaksi & konten,
/// sehingga trigger stok/total/sinkron konten tidak terpicu ulang (induk belum
/// ada) dan nilai di backup dipakai apa adanya. FK dimatikan selama restore lalu
/// diperiksa dengan PRAGMA foreign_key_check sebelum commit.
const restoreOrder = <String>[
  'business_profile',
  'doc_counters',
  'categories',
  'products',
  'customers',
  'suppliers',
  'transaction_items',
  'payments',
  'transactions',
  'stock_movements',
  'content_publications',
  'content_assets',
  'content_schedules',
  'content_ideas',
  'content_product_links',
  'notes',
  'note_tags',
  'note_attachments',
  'note_links',
  'watchlist_items',
  'watchlist_item_ideas',
];

/// Serialisasi seluruh database ⇄ JSON (data.json) dan restore Replace/Merge.
class BackupCodec {
  BackupCodec(this._db);
  final AppDatabase _db;

  Map<String, TableInfo> get _tables => {for (final t in _db.allTables) t.actualTableName: t};

  // ------------------------------------------------------------- export
  Future<Map<String, Object?>> exportData() async {
    final tables = <String, Object?>{};
    for (final name in backupTableOrder) {
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      tables[name] = [for (final r in rows) r.data];
    }
    return {
      'format': backupFormat,
      'schema_version': currentSchemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  Future<Map<String, int>> rowCounts() async {
    final out = <String, int>{};
    for (final name in backupTableOrder) {
      final r = await _db.customSelect('SELECT COUNT(*) AS n FROM "$name"').getSingle();
      out[name] = r.read<int>('n');
    }
    return out;
  }

  // ------------------------------------------------------------ restore
  /// Validasi isi data.json; lempar [BackupFormatException] berbahasa Indonesia.
  static ({int schemaVersion, String source, Map<String, dynamic> tables}) validate(Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      throw BackupFormatException('File bukan backup UsahaKonten (format JSON tidak dikenal).');
    }
    if (decoded['format'] != backupFormat) {
      throw BackupFormatException('File bukan backup UsahaKonten.');
    }
    final version = decoded['schema_version'];
    if (version is! int || version < 1) {
      throw BackupFormatException('Versi skema backup tidak valid.');
    }
    if (version > currentSchemaVersion) {
      throw BackupFormatException(
        'Backup dibuat oleh versi aplikasi yang lebih baru (skema v$version). '
        'Perbarui aplikasi dulu, lalu ulangi restore.',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw BackupFormatException('Isi backup rusak: bagian "tables" tidak ditemukan.');
    }
    for (final e in tables.entries) {
      if (!backupTableOrder.contains(e.key)) {
        throw BackupFormatException('Tabel tidak dikenal di backup: ${e.key}');
      }
      if (e.value is! List) throw BackupFormatException('Isi tabel ${e.key} rusak.');
    }
    return (
      schemaVersion: version,
      source: decoded['source'] == 'supabase' ? 'supabase' : 'usahakonten',
      tables: tables,
    );
  }

  Future<RestoreResult> restore(Object? decoded, RestoreMode mode) async {
    final v = validate(decoded);
    final isSupabase = v.source == 'supabase';
    final preexistingProducts = mode == RestoreMode.merge
        ? (await _db.customSelect('SELECT id FROM products').get()).map((r) => r.read<String>('id')).toSet()
        : <String>{};

    final inserted = <String, int>{};
    var skipped = 0;
    final newTrxIds = <String>[];

    await _db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await _db.transaction(() async {
        if (mode == RestoreMode.replace) await _db.wipeAllData();

        for (final name in restoreOrder) {
          final rows = (v.tables[name] as List?) ?? const [];
          final table = _tables[name]!;
          var count = 0;
          for (final raw in rows) {
            if (raw is! Map<String, dynamic>) {
              throw BackupFormatException('Baris rusak di tabel $name.');
            }
            final row = normalizeRow(table, raw, fromSupabase: isSupabase);
            if (row.isEmpty) continue;
            final cols = row.keys.toList();
            // business_profile selalu 1 baris → ditimpa (Replace) / dibiarkan (Merge).
            final verb = name == 'business_profile' && mode == RestoreMode.replace
                ? 'INSERT OR REPLACE'
                : 'INSERT OR IGNORE';
            await _db.customInsert(
              '$verb INTO "$name" (${cols.map((c) => '"$c"').join(', ')}) '
              'VALUES (${List.filled(cols.length, '?').join(', ')})',
              variables: [for (final c in cols) _variable(row[c])],
            );
            if (await _lastInsertChanged()) {
              count++;
              if (name == 'transactions' && row['deleted_at'] == null) {
                newTrxIds.add(row['id'] as String);
              }
            } else {
              skipped++;
            }
          }
          inserted[name] = count;
        }

        if (mode == RestoreMode.merge) {
          await _applyStockForMergedTransactions(newTrxIds, preexistingProducts);
        }

        for (final sql in rebuildNotesFts) {
          await _db.customStatement(sql);
        }

        final violations = await _db.customSelect('PRAGMA foreign_key_check').get();
        if (violations.isNotEmpty) {
          final t = violations.first.data['table'];
          throw BackupFormatException(
            'Backup tidak konsisten: ada data yang merujuk data lain yang hilang (tabel $t). '
            'Restore dibatalkan, data di HP tidak berubah.',
          );
        }
      });
    } finally {
      await _db.customStatement('PRAGMA foreign_keys = ON');
    }
    // Beritahu semua stream drift bahwa data berubah.
    _db.notifyUpdates({for (final t in _db.allTables) TableUpdate.onTable(t)});
    return RestoreResult(inserted: inserted, skipped: skipped, source: v.source);
  }

  Future<bool> _lastInsertChanged() async {
    final r = await _db.customSelect('SELECT changes() AS c').getSingle();
    return r.read<int>('c') > 0;
  }

  /// Merge: transaksi baru dari HP lain ikut mengubah stok produk yang SUDAH ada
  /// di HP ini (produk baru dari backup sudah membawa stok akhirnya sendiri).
  Future<void> _applyStockForMergedTransactions(List<String> trxIds, Set<String> preexistingProducts) async {
    if (trxIds.isEmpty || preexistingProducts.isEmpty) return;
    for (final trxId in trxIds) {
      final items = await _db
          .customSelect(
            'SELECT ti.product_id AS pid, ti.qty AS qty, t.type AS type '
            'FROM transaction_items ti JOIN transactions t ON t.id = ti.transaction_id '
            'WHERE ti.transaction_id = ? AND ti.product_id IS NOT NULL',
            variables: [Variable.withString(trxId)],
          )
          .get();
      for (final it in items) {
        final pid = it.read<String>('pid');
        if (!preexistingProducts.contains(pid)) continue;
        final isSale = it.read<String>('type') == 'sale';
        final delta = (isSale ? -1 : 1) * it.read<double>('qty');
        final n = await _db.customUpdate(
          'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ? AND track_stock = 1',
          variables: [Variable.withReal(delta), Variable.withDateTime(DateTime.now()), Variable.withString(pid)],
        );
        if (n > 0) {
          await _db
              .into(_db.stockMovements)
              .insert(
                StockMovementsCompanion.insert(
                  productId: pid,
                  transactionId: Value(trxId),
                  qtyChange: delta,
                  reason: isSale ? 'penjualan' : 'pembelian',
                  notes: const Value('Digabung dari backup'),
                ),
              );
        }
      }
    }
  }

  static Variable<Object> _variable(Object? v) => switch (v) {
    null => const Variable(null),
    int i => Variable.withInt(i),
    double d => Variable.withReal(d),
    String s => Variable.withString(s),
    _ => Variable.withString(v.toString()),
  };

  /// Sesuaikan satu baris (dari backup lokal ATAU export Supabase) dengan kolom
  /// tabel lokal: buang kolom asing/generated, ubah tipe (ISO → detik Unix,
  /// bool → 0/1, array → JSON).
  static Map<String, Object?> normalizeRow(TableInfo table, Map<String, dynamic> raw, {bool fromSupabase = false}) {
    final src = Map<String, dynamic>.of(raw);
    if (fromSupabase) _adaptSupabaseRow(table.actualTableName, src);

    final out = <String, Object?>{};
    for (final col in table.$columns) {
      if (col.generatedAs != null) continue;
      if (!src.containsKey(col.name)) continue;
      out[col.name] = _convert(col.type, src[col.name], table.actualTableName, col.name);
    }
    return out;
  }

  static void _adaptSupabaseRow(String table, Map<String, dynamic> row) {
    row.remove('owner_id');
    switch (table) {
      case 'business_profile':
        row['id'] = 1;
        final bank = row.remove('bank_info_enc');
        row['bank_info'] = bank; // tidak pernah terisi di versi cloud
      case 'customers' || 'suppliers':
        row.remove('private_notes_enc');
      case 'content_assets':
        final storagePath = row.remove('storage_path');
        if (storagePath != null) {
          // File di Supabase Storage tidak ikut terekspor → simpan jejaknya di catatan.
          row['notes'] = [row['notes'], 'File cloud lama: $storagePath'].whereType<String>().join('\n');
          if (row['url'] == null) row['kind'] = 'naskah';
        }
    }
  }

  static Object? _convert(Object type, Object? v, String table, String column) {
    if (v == null) return null;
    try {
      if (type == DriftSqlType.dateTime) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        final d = DateTime.parse(v.toString());
        return d.millisecondsSinceEpoch ~/ 1000;
      }
      if (type == DriftSqlType.bool) {
        if (v is bool) return v ? 1 : 0;
        if (v is num) return v == 0 ? 0 : 1;
        return v.toString() == 'true' ? 1 : 0;
      }
      if (type == DriftSqlType.double) {
        return v is num ? v.toDouble() : double.parse(v.toString());
      }
      if (type == DriftSqlType.int) {
        return v is num ? v.toInt() : int.parse(v.toString());
      }
      if (v is List || v is Map) return jsonEncode(v);
      return v.toString();
    } on FormatException {
      throw BackupFormatException('Nilai tidak valid di $table.$column: $v');
    }
  }
}
