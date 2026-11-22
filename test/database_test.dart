import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/database/migrations/migration_strategy.dart';
import 'package:usahakonten/data/repositories/hutang_repository.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/konten_repository.dart';
import 'package:usahakonten/data/repositories/produk_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';

void main() {
  late AppDatabase db;
  late ProdukRepository produk;
  late TransaksiRepository trx;
  late HutangRepository hutang;
  late KontenRepository konten;
  late InvoiceRepository invoice;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    produk = ProdukRepository(db);
    invoice = InvoiceRepository(db);
    trx = TransaksiRepository(db, invoice);
    hutang = HutangRepository(db);
    konten = KontenRepository(db);
  });
  tearDown(() => db.close());

  Future<String> addProduct({double stock = 10, bool track = true}) => produk.save(
      ProductsCompanion.insert(
          name: 'Kaos', kind: const Value('barang'), trackStock: Value(track), stock: Value(stock),
          minStock: const Value(5), sellPrice: const Value(50000)));

  Future<double> stockOf(String id) async => (await produk.getById(id))!.stock;

  test('schema_version tersimpan di meta & PRAGMA foreign_keys aktif', () async {
    final meta = await db.select(db.meta).get();
    expect(meta.single.key, 'schema_version');
    expect(meta.single.value, '$currentSchemaVersion');
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
  });

  test('penjualan: nomor, total, stok, status bayar, piutang', () async {
    final p = await addProduct();
    final t = await trx.createTransaction(TrxInput(
      type: 'sale',
      trxDate: DateTime(2026, 11, 22),
      discount: 10000,
      items: [
        TrxItemInput(productId: p, name: 'Kaos', qty: 3, price: 50000),
        const TrxItemInput(name: 'Desain Logo', qty: 1, price: 500000),
      ],
      initialPayment: 200000,
    ));
    expect(t.number, 'INV-202611-0001');
    expect(t.subtotal, 650000);
    expect(t.total, 640000);
    expect(t.paidAmount, 200000);
    expect(t.status, 'sebagian');
    expect(await stockOf(p), 7);

    final debts = await hutang.getDebts();
    expect(debts.single.kind, 'piutang');
    expect(debts.single.remaining, 440000);

    await trx.addPayment(t.id, amount: 440000);
    expect((await trx.getById(t.id))!.status, 'lunas');
    expect(await hutang.getDebts(), isEmpty);

    final t2 = await trx.createTransaction(TrxInput(
        type: 'sale', trxDate: DateTime(2026, 11, 23), items: [TrxItemInput(productId: p, name: 'Kaos', qty: 1, price: 1)]));
    expect(t2.number, 'INV-202611-0002');
  });

  test('pembelian menambah stok, nomor PO terpisah', () async {
    final p = await addProduct();
    final t = await trx.createTransaction(TrxInput(
        type: 'purchase', trxDate: DateTime(2026, 11, 1),
        items: [TrxItemInput(productId: p, name: 'Kaos', qty: 5, price: 30000)]));
    expect(t.number, 'PO-202611-0001');
    expect(await stockOf(p), 15);
    expect((await hutang.getDebts(kind: 'hutang')).single.remaining, 150000);
  });

  test('batal (soft delete) mengembalikan stok, pulihkan menerapkan lagi', () async {
    final p = await addProduct();
    final t = await trx.createTransaction(TrxInput(
        type: 'sale', items: [TrxItemInput(productId: p, name: 'Kaos', qty: 4, price: 1000)]));
    expect(await stockOf(p), 6);
    await trx.softDelete(t.id);
    expect(await stockOf(p), 10);
    expect(await hutang.getDebts(), isEmpty);
    await trx.restore(t.id);
    expect(await stockOf(p), 6);
    final reasons = (await db.select(db.stockMovements).get()).map((m) => m.reason).toList();
    expect(reasons, containsAll(['penjualan', 'batal_penjualan']));
  });

  test('hapus permanen transaksi aktif mengembalikan stok tepat sekali', () async {
    final p = await addProduct();
    final t = await trx.createTransaction(TrxInput(
        type: 'sale', items: [TrxItemInput(productId: p, name: 'Kaos', qty: 2, price: 1000)]));
    await (db.delete(db.transactions)..where((x) => x.id.equals(t.id))).go();
    expect(await stockOf(p), 10);
    expect(await db.select(db.transactionItems).get(), isEmpty);
  });

  test('produk tanpa lacak stok tidak berubah; penyesuaian manual tercatat', () async {
    final jasa = await addProduct(track: false, stock: 0);
    await trx.createTransaction(TrxInput(
        type: 'sale', items: [TrxItemInput(productId: jasa, name: 'Jasa', qty: 1, price: 1)]));
    expect(await stockOf(jasa), 0);

    final p = await addProduct();
    await produk.adjustStock(p, -6, notes: 'rusak');
    expect(await stockOf(p), 4);
    expect((await produk.watchLowStock().first).map((e) => e.id), [p]);
  });

  test('hapus pembayaran (soft) menghitung ulang status', () async {
    final t = await trx.createTransaction(const TrxInput(
        type: 'sale', items: [TrxItemInput(name: 'X', qty: 1, price: 100)], initialPayment: 100));
    expect(t.status, 'lunas');
    final pay = (await db.select(db.payments).get()).single;
    await trx.deletePayment(pay.id);
    final after = (await trx.getById(t.id))!;
    expect(after.paidAmount, 0);
    expect(after.status, 'belum');
  });

  test('constraint: qty harus > 0 & transaksi tanpa item ditolak', () async {
    expect(
        () => trx.createTransaction(const TrxInput(type: 'sale', items: [TrxItemInput(name: 'X', qty: 0, price: 1)])),
        throwsA(isA<SqliteException>()));
    expect(() => trx.createTransaction(const TrxInput(type: 'sale', items: [])), throwsArgumentError);
    expect(await db.select(db.transactions).get(), isEmpty, reason: 'rollback atomik');
  });

  test('foreign key: pelanggan yang dipakai transaksi tidak bisa dihapus permanen', () async {
    final c = await db.into(db.customers).insertReturning(CustomersCompanion.insert(name: 'Budi'));
    await trx.createTransaction(TrxInput(
        type: 'sale', customerId: c.id, items: const [TrxItemInput(name: 'X', qty: 1, price: 1)]));
    expect(() => (db.delete(db.customers)..where((x) => x.id.equals(c.id))).go(),
        throwsA(isA<SqliteException>()));
  });

  test('konten: publikasi → jadwal tayang & ide publish; relasi produk; hitung status', () async {
    final p = await addProduct();
    final idea = await konten.saveIdea(ContentIdeasCompanion.insert(title: 'Tips'));
    await konten.linkProduct(idea, p);
    expect((await konten.watchLinkedProducts(idea).first).single.id, p);
    expect((await konten.watchIdeasForProduct(p).first).single.id, idea);

    final when = DateTime.now().add(const Duration(days: 1));
    final sch = await db.into(db.contentSchedules).insertReturning(
        ContentSchedulesCompanion.insert(ideaId: idea, platform: 'instagram', scheduledAt: when));
    final upcoming = await konten.schedulesBetween(DateTime.now(), DateTime.now().add(const Duration(days: 7)));
    expect(upcoming.single.ideaTitle, 'Tips');

    await db.into(db.contentPublications).insert(ContentPublicationsCompanion.insert(
        ideaId: idea, scheduleId: Value(sch.id), platform: 'instagram', reach: const Value(1000)));
    final s = await (db.select(db.contentSchedules)..where((x) => x.id.equals(sch.id))).getSingle();
    expect(s.status, 'tayang');
    expect(await konten.statusCounts(), {'ide': 0, 'produksi': 0, 'review': 0, 'publish': 1});
  });

  test('wipeAllData mengosongkan semua tabel kecuali profil default', () async {
    final p = await addProduct();
    await trx.createTransaction(TrxInput(type: 'sale', items: [TrxItemInput(productId: p, name: 'K', qty: 1, price: 1)]));
    await db.wipeAllData();
    for (final t in backupTableOrder) {
      final n = await db.customSelect('SELECT COUNT(*) AS n FROM "$t"').getSingle();
      expect(n.read<int>('n'), t == 'business_profile' ? 1 : 0, reason: t);
    }
    final t2 = await trx.createTransaction(const TrxInput(type: 'sale', items: [TrxItemInput(name: 'X', qty: 1, price: 1)]));
    expect(t2.number, endsWith('-0001'), reason: 'penomoran ikut direset');
  });
}
