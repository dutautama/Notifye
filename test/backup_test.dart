import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/database/migrations/migration_strategy.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/meta_repository.dart';
import 'package:usahakonten/data/repositories/produk_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';
import 'package:usahakonten/services/backup/backup_codec.dart';
import 'package:usahakonten/services/backup/backup_service.dart';

/// Satu "HP" virtual: database + folder penyimpanan sendiri.
class Phone {
  Phone(this.root)
      : db = AppDatabase(NativeDatabase.memory()),
        attachments = Directory('${root.path}/attachments');
  final Directory root;
  final AppDatabase db;
  final Directory attachments;
  DateTime clock = DateTime(2026, 11, 22, 10, 30);

  late final backup = BackupService(db, MetaRepository(db),
      baseDir: () async => root, attachmentsDir: () async => attachments, now: () => clock);
  late final produk = ProdukRepository(db);
  late final trx = TransaksiRepository(db, InvoiceRepository(db));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late Phone a;
  late Phone b;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('uk_backup_test');
    a = Phone(await Directory('${tmp.path}/a').create());
    b = Phone(await Directory('${tmp.path}/b').create());
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
    await tmp.delete(recursive: true);
  });

  Future<void> seed(Phone p) async {
    final kaos = await p.produk.save(ProductsCompanion.insert(
        name: 'Kaos', kind: const Value('barang'), trackStock: const Value(true),
        stock: const Value(10), imagePath: const Value('produk/kaos.jpg')));
    final c = await p.db.into(p.db.customers).insertReturning(CustomersCompanion.insert(name: 'Budi'));
    final t = await p.trx.createTransaction(TrxInput(
        type: 'sale', customerId: c.id, discount: 5000, initialPayment: 20000,
        items: [TrxItemInput(productId: kaos, name: 'Kaos', qty: 3, price: 50000)]));
    final cancelled = await p.trx.createTransaction(TrxInput(
        type: 'sale', items: [TrxItemInput(productId: kaos, name: 'Kaos', qty: 1, price: 50000)]));
    await p.trx.softDelete(cancelled.id);
    await p.trx.addPayment(t.id, amount: 10000, method: 'transfer');
    final idea = await p.db.into(p.db.contentIdeas).insertReturning(
        ContentIdeasCompanion.insert(title: 'Tips', platforms: const Value('["instagram"]')));
    await p.db.into(p.db.contentProductLinks)
        .insert(ContentProductLinksCompanion.insert(ideaId: idea.id, productId: kaos));
    await p.db.into(p.db.contentAssets).insert(ContentAssetsCompanion.insert(
        ideaId: idea.id, title: 'Foto', kind: const Value('gambar'),
        filePath: const Value('konten/foto.png')));
    // Data skema v2: catatan + tag + lampiran + tautan, koleksi ↔ ide.
    final note = await p.db.into(p.db.notes).insertReturning(NotesCompanion.insert(
        title: const Value('Resep kopi'), body: const Value('- [ ] beli gula aren\n**penting**'),
        isPinned: const Value(true)));
    await p.db.into(p.db.noteTags).insert(NoteTagsCompanion.insert(noteId: note.id, tag: 'resep'));
    await p.db.into(p.db.noteAttachments).insert(NoteAttachmentsCompanion.insert(
        noteId: note.id, filePath: 'catatan/struk.pdf', fileName: 'struk.pdf'));
    await p.db.into(p.db.noteLinks).insert(
        NoteLinksCompanion.insert(noteId: note.id, entityType: 'product', entityId: kaos));
    final item = await p.db.into(p.db.watchlistItems).insertReturning(WatchlistItemsCompanion.insert(
        title: 'Atomic Habits', type: const Value('buku'), status: const Value('sedang'),
        progress: const Value(120), progressTotal: const Value(320), rating: const Value(5)));
    await p.db.into(p.db.watchlistItemIdeas).insert(WatchlistItemIdeasCompanion.insert(itemId: item.id, ideaId: idea.id));
    await File('${p.attachments.path}/catatan/struk.pdf').create(recursive: true)
        .then((f) => f.writeAsBytes([37, 80, 68, 70]));
    await File('${p.attachments.path}/produk/kaos.jpg').create(recursive: true)
        .then((f) => f.writeAsBytes([1, 2, 3]));
    await File('${p.attachments.path}/konten/foto.png').create(recursive: true)
        .then((f) => f.writeAsBytes(List.generate(1000, (i) => i % 256)));
  }

  Future<Map<String, List<Map<String, Object?>>>> dump(AppDatabase db) async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final t in backupTableOrder) {
      out[t] = (await db.customSelect('SELECT * FROM "$t" ORDER BY 1, 2').get()).map((r) => r.data).toList();
    }
    return out;
  }

  test('HP A export → HP B (baru) import Replace → data & lampiran identik', () async {
    await seed(a);
    final file = await a.backup.createBackup();
    expect(file.uri.pathSegments.last, 'UsahaKonten-backup-20261122-1030.zip');

    final zip = ZipDecoder().decodeBytes(await file.readAsBytes());
    final names = zip.files.map((f) => f.name).toSet();
    expect(names, containsAll(['data.json', 'meta.json', 'attachments/produk/kaos.jpg', 'attachments/konten/foto.png']));
    final meta = jsonDecode(utf8.decode(zip.findFile('meta.json')!.content)) as Map;
    expect(meta['schema_version'], currentSchemaVersion);
    expect(meta.containsKey('app_version'), isTrue);

    final parsed = await b.backup.parse(file);
    final result = await b.backup.restore(parsed, RestoreMode.replace);
    expect(result.totalInserted, greaterThan(5));

    expect(await dump(b.db), await dump(a.db), reason: 'semua tabel identik termasuk stok & status');
    expect(await File('${b.attachments.path}/produk/kaos.jpg').readAsBytes(), [1, 2, 3]);
    expect((await File('${b.attachments.path}/konten/foto.png').readAsBytes()).length, 1000);
    expect(await File('${b.attachments.path}/catatan/struk.pdf').readAsBytes(), [37, 80, 68, 70]);
    // Indeks pencarian dibangun ulang di HP B.
    final hits = await b.db.customSelect("SELECT note_id FROM notes_fts WHERE notes_fts MATCH 'gula*'").get();
    expect(hits, hasLength(1));

    // Database hasil restore tetap berfungsi normal (trigger aktif lagi).
    final kaos = (await b.db.select(b.db.products).get()).single;
    expect(kaos.stock, 7);
    await b.trx.createTransaction(TrxInput(type: 'sale', items: [TrxItemInput(productId: kaos.id, name: 'Kaos', qty: 2, price: 1)]));
    expect((await b.produk.getById(kaos.id))!.stock, 5);
    final nums = (await b.db.select(b.db.transactions).get()).map((t) => t.number).toSet();
    expect(nums, contains('INV-202611-0003'), reason: 'penomoran lanjut dari backup');
  });

  test('Replace menimpa data lama di HP tujuan', () async {
    await seed(a);
    await b.produk.save(ProductsCompanion.insert(name: 'Data lama B'));
    final parsed = await b.backup.parse(await a.backup.createBackup());
    await b.backup.restore(parsed, RestoreMode.replace);
    final names = (await b.db.select(b.db.products).get()).map((p) => p.name);
    expect(names, ['Kaos']);
  });

  test('Merge: tambah data baru, data lokal dipertahankan, stok produk lokal ikut transaksi baru', () async {
    await seed(a);
    final fileA = await a.backup.createBackup();
    // B memulihkan dulu (punya produk yang sama), lalu A membuat penjualan baru.
    await b.backup.restore(await b.backup.parse(fileA), RestoreMode.replace);
    final kaosId = (await a.db.select(a.db.products).get()).single.id;
    await a.trx.createTransaction(TrxInput(
        type: 'sale', trxDate: DateTime(2026, 11, 23),
        items: [TrxItemInput(productId: kaosId, name: 'Kaos', qty: 2, price: 50000)]));
    await b.produk.save(ProductsCompanion.insert(name: 'Hanya di B'));
    a.clock = DateTime(2026, 11, 23, 9);
    final fileA2 = await a.backup.createBackup();

    final r = await b.backup.restore(await b.backup.parse(fileA2), RestoreMode.merge);
    expect(r.inserted['transactions'], 1);
    expect(r.skipped, greaterThan(0));
    final names = (await b.db.select(b.db.products).get()).map((p) => p.name).toSet();
    expect(names, {'Kaos', 'Hanya di B'});
    expect((await b.produk.getById(kaosId))!.stock, 5, reason: '7 - 2 dari transaksi hasil merge');

    // Merge ulang file yang sama tidak menggandakan apa pun.
    final again = await b.backup.restore(await b.backup.parse(fileA2), RestoreMode.merge);
    expect(again.totalInserted, 0);
    expect((await b.produk.getById(kaosId))!.stock, 5);
  });

  test('Import export Supabase (fixture) ke HP baru', () async {
    final file = File('test/fixtures/supabase-export-sample.json');
    final parsed = await b.backup.parse(file);
    expect(parsed.source, 'supabase');
    await b.backup.restore(parsed, RestoreMode.replace);
    final products = await b.db.select(b.db.products).get();
    expect(products.map((p) => p.name).toSet(), containsAll(['Kaos', 'Desain Logo']));
    final trx = await (b.db.select(b.db.transactions)..orderBy([(t) => OrderingTerm.asc(t.number)])).get();
    expect(trx.map((t) => t.number), ['PO-202611-0001', 'PO-202611-0002']);
    final kaos = products.firstWhere((p) => p.name == 'Kaos');
    expect(kaos.stock, 13, reason: 'stok dari export dipakai apa adanya (trigger tidak menghitung ulang)');
    expect(kaos.trackStock, isTrue);
    final idea = (await b.db.select(b.db.contentIdeas).get()).single;
    expect(jsonDecode(idea.platforms), ['instagram', 'tiktok']);
    expect((await b.db.select(b.db.contentProductLinks).get()), hasLength(1));
  });

  test('file tidak valid ditolak dengan pesan jelas & data tidak berubah', () async {
    await b.produk.save(ProductsCompanion.insert(name: 'Aman'));
    Future<void> expectReject(String content, String expected) async {
      final f = File('${tmp.path}/x.json')..writeAsStringSync(content);
      await expectLater(b.backup.parse(f),
          throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains(expected))));
    }

    await expectReject('bukan json', 'JSON');
    await expectReject('{"format":"lain"}', 'bukan backup');
    await expectReject('{"format":"usahakonten-backup","schema_version":99,"tables":{}}', 'lebih baru');
    await expectReject('{"format":"usahakonten-backup","schema_version":1,"tables":{"hacker":[]}}', 'tidak dikenal');

    // Referensi rusak → rollback total.
    final broken = File('${tmp.path}/broken.json')..writeAsStringSync(jsonEncode({
          'format': 'usahakonten-backup', 'schema_version': 1,
          'tables': {'transaction_items': [{'id': 'x', 'transaction_id': 'tidak-ada', 'name': 'X', 'qty': 1, 'price': 1}]},
        }));
    await expectLater(b.backup.restore(await b.backup.parse(broken), RestoreMode.replace),
        throwsA(isA<BackupFormatException>()));
    expect((await b.db.select(b.db.products).get()).single.name, 'Aman');
  });

  test('zip slip: path lampiran berbahaya ditolak', () async {
    expect(BackupService.safeAttachmentPath('produk/a.jpg'), 'produk/a.jpg');
    for (final bad in ['../x', 'a/../../x', '/etc/passwd', 'C:/x', 'a//b', '']) {
      expect(BackupService.safeAttachmentPath(bad), isNull, reason: bad);
    }
    final archive = Archive()
      ..addFile(ArchiveFile.string('data.json', jsonEncode({'format': 'usahakonten-backup', 'schema_version': 1, 'tables': {}})))
      ..addFile(ArchiveFile.bytes('attachments/../../evil.sh', [1]));
    final f = File('${tmp.path}/evil.zip')..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    await expectLater(b.backup.parse(f), throwsA(isA<BackupFormatException>()));
  });

  test('backup otomatis mingguan + rotasi 4 file', () async {
    expect(await a.backup.runAutoBackupIfDue(), isNotNull, reason: 'belum pernah → langsung backup');
    a.clock = a.clock.add(const Duration(days: 3));
    expect(await a.backup.runAutoBackupIfDue(), isNull, reason: 'belum 7 hari');
    for (var i = 0; i < 5; i++) {
      a.clock = a.clock.add(const Duration(days: 7));
      expect(await a.backup.runAutoBackupIfDue(), isNotNull);
    }
    final autos = await a.backup.listBackups(includeManual: false);
    expect(autos, hasLength(BackupService.autoKeep));
    expect(autos.first.name, BackupService.fileNameFor(a.clock));
  });
}
