import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/database/migrations/migration_strategy.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';

const _v2Tables = ['notes', 'note_tags', 'note_attachments', 'note_links', 'watchlist_items', 'watchlist_item_ideas'];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('upgrade v1 → v2: data lama utuh, tabel & pencarian baru berfungsi', () async {
    final dir = await Directory.systemTemp.createTemp('uk_mig');
    final file = File('${dir.path}/db.sqlite');

    // 1) Buat database lalu "turunkan" ke bentuk v1 persis: hapus objek v2 & set user_version = 1.
    var db = AppDatabase(NativeDatabase(file));
    final p = await db.into(db.products).insertReturning(ProductsCompanion.insert(
        name: 'Kaos', trackStock: const Value(true), stock: const Value(10)));
    final t = await TransaksiRepository(db, InvoiceRepository(db)).createTransaction(TrxInput(
        type: 'sale', initialPayment: 5000, items: [TrxItemInput(productId: p.id, name: 'Kaos', qty: 2, price: 10000)]));
    for (final trg in ['trg_notes_fts_ai', 'trg_notes_fts_au', 'trg_notes_fts_ad']) {
      await db.customStatement('DROP TRIGGER $trg');
    }
    await db.customStatement('DROP TABLE notes_fts');
    for (final tbl in _v2Tables.reversed) {
      await db.customStatement('DROP TABLE $tbl');
    }
    await db.customStatement('PRAGMA user_version = 1');
    await db.close();

    // 2) Buka dengan aplikasi v2 → onUpgrade 1 → 2.
    db = AppDatabase(NativeDatabase(file));
    final tables = (await db.customSelect("SELECT name FROM sqlite_master WHERE type IN ('table')").get())
        .map((r) => r.read<String>('name'))
        .toSet();
    expect(tables, containsAll([..._v2Tables, 'notes_fts']));
    final ver = await db.customSelect('PRAGMA user_version').getSingle();
    expect(ver.data.values.first, currentSchemaVersion);
    expect((await db.select(db.meta).get()).firstWhere((m) => m.key == 'schema_version').value, '2');

    // Data v1 utuh & trigger v1 tetap bekerja.
    final trx = await (db.select(db.transactions)..where((x) => x.id.equals(t.id))).getSingle();
    expect(trx.total, 20000);
    expect(trx.status, 'sebagian');
    expect((await db.select(db.products).getSingle()).stock, 8);

    // Fitur v2 bekerja di database hasil upgrade.
    await db.into(db.notes).insert(NotesCompanion.insert(title: const Value('Resep'), body: const Value('kopi susu gula aren')));
    final hit = await db.customSelect("SELECT note_id FROM notes_fts WHERE notes_fts MATCH 'kop*'").get();
    expect(hit, hasLength(1));
    await db.close();
    await dir.delete(recursive: true);
  });

  test('instalasi baru langsung v2 dengan FTS & trigger', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final n = await db.into(db.notes).insertReturning(NotesCompanion.insert(title: const Value('Halo'), body: const Value('dunia')));
    await (db.update(db.notes)..where((x) => x.id.equals(n.id))).write(const NotesCompanion(body: Value('semesta')));
    expect(await db.customSelect("SELECT * FROM notes_fts WHERE notes_fts MATCH 'dunia'").get(), isEmpty);
    expect(await db.customSelect("SELECT * FROM notes_fts WHERE notes_fts MATCH 'semesta'").get(), hasLength(1));
    await (db.delete(db.notes)..where((x) => x.id.equals(n.id))).go();
    expect(await db.customSelect('SELECT * FROM notes_fts').get(), isEmpty);
    await db.close();
  });
}
