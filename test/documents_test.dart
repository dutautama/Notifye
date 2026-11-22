import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';
import 'package:usahakonten/services/documents/escpos.dart';
import 'package:usahakonten/services/documents/invoice_pdf.dart';
import 'package:usahakonten/services/documents/xlsx_writer.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<InvoiceData> sampleInvoice(AppDatabase db) async {
    final inv = InvoiceRepository(db);
    await inv.updateProfile(const BusinessProfileCompanion(
        name: Value('Toko Maju Jaya'), address: Value('Jl. Merdeka 1, Bandung'),
        phone: Value('0812-1111-2222'), bankInfo: Value('BCA 123 a.n. Maju'),
        invoiceFooter: Value('Terima kasih!')));
    final c = await db.into(db.customers).insertReturning(CustomersCompanion.insert(name: 'Budi Santoso'));
    final t = await TransaksiRepository(db, inv).createTransaction(TrxInput(
      type: 'sale', customerId: c.id, discount: 10000, dueDate: DateTime(2026, 12, 1),
      initialPayment: 100000,
      items: const [
        TrxItemInput(name: 'Desain logo premium dengan 3 revisi', qty: 1, price: 750000),
        TrxItemInput(name: 'Kaos', qty: 2.5, price: 85000),
      ],
    ));
    return (await inv.getInvoiceData(t.id))!;
  }

  test('PDF invoice valid', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final bytes = await buildInvoicePdf(await sampleInvoice(db));
    expect(utf8.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(1500));
    final out = Platform.environment['UK_DOC_OUT'];
    if (out != null) File('$out/invoice.pdf').writeAsBytesSync(bytes);
    await db.close();
  });

  test('struk ESC/POS: lebar baris, total, potong kertas', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final bytes = buildReceipt(await sampleInvoice(db));
    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    final text = latin1.decode(bytes.where((b) => b == 0x0A || (b >= 0x20 && b < 0x7F)).toList());
    final lines = text.split('\n');
    expect(lines.every((l) => l.length <= 32 + 3), isTrue, reason: lines.where((l) => l.length > 35).join('|'));
    expect(text, contains('TOTAL'));
    expect(text, contains('Sisa'));
    expect(text, contains('Budi Santoso'));
    await db.close();
  });

  test('pembungkus teks ESC/POS', () {
    expect(EscPos.wrap('halo dunia yang indah', 10), ['halo dunia', 'yang indah']);
    expect(EscPos.wrap('abcdefghijklmno', 5), ['abcde', 'fghij', 'klmno']);
  });

  test('XLSX: struktur zip & nama kolom', () {
    expect(XlsxWriter.columnName(0), 'A');
    expect(XlsxWriter.columnName(25), 'Z');
    expect(XlsxWriter.columnName(26), 'AA');
    expect(XlsxWriter.columnName(701), 'ZZ');
    final bytes = XlsxWriter.build([
      XlsxSheet('Penjualan', [
        ['Tanggal', 'Nomor', 'Pelanggan', 'Total'],
        ['22/11/2026', 'INV-1', 'Budi & <Ani> "CV"', 1250000],
        ['23/11/2026', 'INV-2', null, 99.5],
      ]),
      XlsxSheet('Stok/Gudang?', [
        ['Produk', 'Stok'],
        ['Kaos', 7],
      ]),
      XlsxSheet('Penjualan', [['x']]),
    ]);
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(zip.files.map((f) => f.name), containsAll(['[Content_Types].xml', 'xl/workbook.xml', 'xl/worksheets/sheet3.xml']));
    final out = Platform.environment['UK_DOC_OUT'];
    if (out != null) File('$out/laporan.xlsx').writeAsBytesSync(bytes);
  });
}
