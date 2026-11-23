import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/produk_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late TransaksiRepository trx;
  late ProdukRepository produk;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trx = TransaksiRepository(db, InvoiceRepository(db));
    produk = ProdukRepository(db);
  });
  tearDown(() => db.close());

  test('rumus laba: (subtotal − diskon) − modal; pajak bukan laba', () {
    expect(marginOf(subtotal: 100000, discount: 10000, cost: 60000), 30000);
    expect(marginOf(subtotal: 50000, discount: 0, cost: 70000), -20000, reason: 'jual rugi tetap terlihat');
  });

  test('modal di-snapshot saat jual; harga modal berubah kemudian tidak mengubah laba lama', () async {
    final kaos = await produk.save(ProductsCompanion.insert(name: 'Kaos', buyPrice: const Value(30000), sellPrice: const Value(50000)));
    final day = DateTime(2026, 11, 22);
    await trx.createTransaction(TrxInput(type: 'sale', trxDate: day, discount: 5000, tax: 11000, items: [
      TrxItemInput(productId: kaos, name: 'Kaos', qty: 2, price: 50000), // modal 60.000
      const TrxItemInput(name: 'Jasa sablon', qty: 1, price: 20000, unitCost: 8000), // manual, modal 8.000
      const TrxItemInput(name: 'Ongkir', qty: 1, price: 10000), // manual tanpa modal
    ]));
    // subtotal 130.000 − diskon 5.000 − modal 68.000 = 57.000 (pajak 11.000 tidak dihitung)
    var rows = await trx.dailySales(day, day);
    expect(rows.single.omzet, 136000);
    expect(rows.single.profit, 57000);

    await produk.save(ProductsCompanion(id: Value(kaos), buyPrice: const Value(45000)));
    rows = await trx.dailySales(day, day);
    expect(rows.single.profit, 57000, reason: 'snapshot modal tidak ikut berubah');

    final items = await trx.itemSummary('sale', day, day);
    final k = items.firstWhere((i) => i.name == 'Kaos');
    expect((k.revenue, k.cost, k.profit), (100000, 60000, 40000));
    expect(k.marginPercent, 40);
  });

  test('transaksi batal tidak dihitung; pembelian tidak dihitung sebagai laba', () async {
    final day = DateTime(2026, 11, 22);
    final t = await trx.createTransaction(TrxInput(type: 'sale', trxDate: day, items: const [
      TrxItemInput(name: 'A', qty: 1, price: 100000, unitCost: 40000),
    ]));
    await trx.createTransaction(TrxInput(type: 'purchase', trxDate: day, items: const [
      TrxItemInput(name: 'Bahan', qty: 1, price: 500000),
    ]));
    expect((await trx.dailySales(day, day)).single.profit, 60000);
    await trx.softDelete(t.id);
    expect(await trx.dailySales(day, day), isEmpty);
    final costs = await trx.costByTransaction([t.id]);
    expect(costs[t.id], 40000);
  });

  test('modal negatif dari input diabaikan (jadi 0)', () async {
    final t = await trx.createTransaction(const TrxInput(type: 'sale', items: [
      TrxItemInput(name: 'X', qty: 1, price: 1000, unitCost: -500),
    ]));
    final item = await (db.select(db.transactionItems)..where((i) => i.transactionId.equals(t.id))).getSingle();
    expect(item.unitCost, 0);
  });
}
