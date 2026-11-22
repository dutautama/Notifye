import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/hutang_repository.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/konten_repository.dart';
import 'package:usahakonten/data/repositories/produk_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';
import 'package:usahakonten/services/report_service.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('laporan periode: angka benar, transaksi batal & di luar periode tidak dihitung, export valid', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final inv = InvoiceRepository(db);
    final trx = TransaksiRepository(db, inv);
    final produk = ProdukRepository(db);
    final konten = KontenRepository(db);
    final kaos = await produk.save(ProductsCompanion.insert(
        name: 'Kaos', trackStock: const Value(true), stock: const Value(10), minStock: const Value(9),
        buyPrice: const Value(30000)));

    await trx.createTransaction(TrxInput(type: 'sale', trxDate: DateTime(2026, 11, 5), initialPayment: 100000,
        items: [TrxItemInput(productId: kaos, name: 'Kaos', qty: 2, price: 75000)]));
    final batal = await trx.createTransaction(TrxInput(type: 'sale', trxDate: DateTime(2026, 11, 6),
        items: [TrxItemInput(productId: kaos, name: 'Kaos', qty: 1, price: 75000)]));
    await trx.softDelete(batal.id);
    await trx.createTransaction(TrxInput(type: 'sale', trxDate: DateTime(2026, 10, 30),
        items: const [TrxItemInput(name: 'Di luar periode', qty: 1, price: 999)]));
    await trx.createTransaction(TrxInput(type: 'purchase', trxDate: DateTime(2026, 11, 7),
        items: [TrxItemInput(productId: kaos, name: 'Kaos', qty: 5, price: 30000)]));
    final idea = await konten.saveIdea(ContentIdeasCompanion.insert(title: 'Video tips'));
    await db.into(db.contentPublications).insert(ContentPublicationsCompanion.insert(
        ideaId: idea, platform: 'tiktok', publishedAt: Value(DateTime(2026, 11, 10)),
        reach: const Value(2000), likes: const Value(150), comments: const Value(30), leads: const Value(4)));

    final svc = ReportService(transaksi: trx, produk: produk, hutang: HutangRepository(db), konten: konten, invoice: inv);
    final d = await svc.load(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
    expect(d.sales.length, 1);
    expect(d.omzet, 150000);
    expect(d.received, 100000);
    expect(d.purchaseTotal, 150000);
    expect(d.soldItems.single.qty, 2);
    expect(d.products.single.stock, 13); // 10 - 2 + 5 (batal dikembalikan)
    expect(d.stockValue, 13 * 30000);
    expect(d.receivable, 50000 + 999); // piutang = posisi saat ini, semua periode
    expect(d.content.single.engagementRate, closeTo(9.0, 0.001));
    expect(d.totalLeads, 4);

    final xlsx = buildReportXlsx(d);
    final pdf = await buildReportPdf(d);
    expect(utf8.decode(pdf.sublist(0, 5)), '%PDF-');
    final out = Platform.environment['UK_DOC_OUT'];
    if (out != null) {
      File('$out/laporan-periode.xlsx').writeAsBytesSync(xlsx);
      File('$out/laporan-periode.pdf').writeAsBytesSync(pdf);
    }
    await db.close();
  });
}
