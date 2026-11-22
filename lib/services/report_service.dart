import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/formatters.dart';
import '../data/database/app_database.dart';
import '../data/repositories/hutang_repository.dart';
import '../data/repositories/invoice_repository.dart';
import '../data/repositories/konten_repository.dart';
import '../data/repositories/produk_repository.dart';
import '../data/repositories/transaksi_repository.dart';
import 'documents/xlsx_writer.dart';

/// Semua angka laporan untuk satu periode.
class ReportData {
  const ReportData({
    required this.from,
    required this.to,
    required this.businessName,
    required this.sales,
    required this.purchases,
    required this.soldItems,
    required this.products,
    required this.debts,
    required this.content,
  });

  final DateTime from;
  final DateTime to;
  final String businessName;
  final List<TrxListRow> sales;
  final List<TrxListRow> purchases;
  final List<ItemSummaryRow> soldItems;
  final List<Product> products; // yang melacak stok
  final List<DebtRow> debts; // semua yang belum lunas (posisi saat ini)
  final List<ContentPerformanceRow> content;

  double get omzet => sales.fold(0, (s, r) => s + r.trx.total);
  double get received => sales.fold(0, (s, r) => s + r.trx.paidAmount);
  double get purchaseTotal => purchases.fold(0, (s, r) => s + r.trx.total);
  double get receivable => debts.where((d) => d.isReceivable).fold(0, (s, d) => s + d.remaining);
  double get payable => debts.where((d) => !d.isReceivable).fold(0, (s, d) => s + d.remaining);
  double get stockValue => products.fold(0, (s, p) => s + p.stock * p.buyPrice);
  int get lowStockCount => products.where((p) => p.stock <= p.minStock).length;
  int get totalReach => content.fold(0, (s, c) => s + c.reach);
  int get totalEngagement => content.fold(0, (s, c) => s + c.engagement);
  int get totalLeads => content.fold(0, (s, c) => s + c.leads);

  String get periodLabel => '${Fmt.date(from)} - ${Fmt.date(to)}';
}

class ReportService {
  ReportService({
    required this.transaksi,
    required this.produk,
    required this.hutang,
    required this.konten,
    required this.invoice,
  });

  final TransaksiRepository transaksi;
  final ProdukRepository produk;
  final HutangRepository hutang;
  final KontenRepository konten;
  final InvoiceRepository invoice;

  Future<ReportData> load(DateTime from, DateTime to) async {
    final products = (await produk.watchAll(includeInactive: true).first).where((p) => p.trackStock).toList();
    return ReportData(
      from: from,
      to: to,
      businessName: (await invoice.getProfile()).name,
      sales: await transaksi.listForPeriod('sale', from, to),
      purchases: await transaksi.listForPeriod('purchase', from, to),
      soldItems: await transaksi.itemSummary('sale', from, to),
      products: products,
      debts: await hutang.getDebts(),
      content: await konten.performance(
        from: DateTime(from.year, from.month, from.day),
        to: DateTime(to.year, to.month, to.day).add(const Duration(days: 1)),
      ),
    );
  }
}

const _status = {'lunas': 'Lunas', 'sebagian': 'Sebagian', 'belum': 'Belum bayar'};

/// Lembar-lembar laporan dalam bentuk tabel (dipakai XLSX & PDF).
List<(String, List<List<Object?>>)> reportTables(ReportData d) => [
  (
    'Ringkasan',
    [
      ['Laporan', d.businessName],
      ['Periode', d.periodLabel],
      ['Omzet penjualan', d.omzet],
      ['Uang diterima', d.received],
      ['Jumlah transaksi penjualan', d.sales.length],
      ['Total pembelian', d.purchaseTotal],
      ['Piutang saat ini', d.receivable],
      ['Hutang saat ini', d.payable],
      ['Nilai stok (harga modal)', d.stockValue],
      ['Produk stok menipis', d.lowStockCount],
      ['Reach konten', d.totalReach],
      ['Engagement konten', d.totalEngagement],
      ['Leads dari konten', d.totalLeads],
    ],
  ),
  (
    'Penjualan',
    [
      ['Tanggal', 'Nomor', 'Pelanggan', 'Total', 'Dibayar', 'Sisa', 'Status'],
      for (final r in d.sales)
        [
          Fmt.date(r.trx.trxDate),
          r.trx.number,
          r.partyName,
          r.trx.total,
          r.trx.paidAmount,
          r.trx.total - r.trx.paidAmount,
          _status[r.trx.status],
        ],
    ],
  ),
  (
    'Item terjual',
    [
      ['Item', 'Qty', 'Nilai'],
      for (final i in d.soldItems) [i.name, i.qty, i.revenue],
    ],
  ),
  (
    'Pembelian',
    [
      ['Tanggal', 'Nomor', 'Supplier', 'Total', 'Dibayar', 'Sisa', 'Status'],
      for (final r in d.purchases)
        [
          Fmt.date(r.trx.trxDate),
          r.trx.number,
          r.partyName,
          r.trx.total,
          r.trx.paidAmount,
          r.trx.total - r.trx.paidAmount,
          _status[r.trx.status],
        ],
    ],
  ),
  (
    'Stok',
    [
      ['Produk', 'SKU', 'Stok', 'Satuan', 'Minimum', 'Harga modal', 'Nilai stok', 'Status'],
      for (final p in d.products)
        [
          p.name,
          p.sku ?? '',
          p.stock,
          p.unit,
          p.minStock,
          p.buyPrice,
          p.stock * p.buyPrice,
          p.stock <= p.minStock ? 'MENIPIS' : 'Aman',
        ],
    ],
  ),
  (
    'Hutang Piutang',
    [
      ['Jenis', 'Nomor', 'Pihak', 'Tanggal', 'Jatuh tempo', 'Total', 'Dibayar', 'Sisa', 'Terlambat'],
      for (final x in d.debts)
        [
          x.isReceivable ? 'Piutang' : 'Hutang',
          x.number,
          x.partyName,
          Fmt.date(x.trxDate),
          x.dueDate == null ? '-' : Fmt.date(x.dueDate),
          x.total,
          x.paidAmount,
          x.remaining,
          x.isOverdue(DateTime.now()) ? 'Ya' : 'Tidak',
        ],
    ],
  ),
  (
    'Konten',
    [
      ['Ide konten', 'Status', 'Publikasi', 'Views', 'Reach', 'Engagement', 'ER (%)', 'Leads', 'Follower'],
      for (final c in d.content)
        [
          c.title,
          c.status,
          c.publications,
          c.views,
          c.reach,
          c.engagement,
          double.parse(c.engagementRate.toStringAsFixed(2)),
          c.leads,
          c.followersGained,
        ],
    ],
  ),
];

Uint8List buildReportXlsx(ReportData d) =>
    XlsxWriter.build([for (final (name, rows) in reportTables(d)) XlsxSheet(name, rows)]);

String _cell(Object? v) {
  if (v == null) return '';
  if (v is double && v != v.roundToDouble()) return Fmt.number(v);
  if (v is num) return Fmt.number(v);
  return v.toString().replaceAll(' ', ' ').replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '?');
}

Future<Uint8List> buildReportPdf(ReportData d) async {
  final doc = pw.Document(title: 'Laporan ${d.businessName}', creator: 'UsahaKonten');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (ctx) => pw.Text(
        '${_cell(d.businessName)} - Laporan ${_cell(d.periodLabel)}',
        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
      ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Halaman ${ctx.pageNumber}/${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
      ),
      build: (ctx) => [
        for (final (name, rows) in reportTables(d)) ...[
          pw.Header(level: 1, text: name),
          if (rows.length <= 1 && name != 'Ringkasan')
            pw.Text('Tidak ada data.')
          else
            pw.TableHelper.fromTextArray(
              headers: name == 'Ringkasan' ? null : [for (final h in rows.first) _cell(h)],
              data: [
                for (final r in name == 'Ringkasan' ? rows : rows.skip(1)) [for (final c in r) _cell(c)],
              ],
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          pw.SizedBox(height: 12),
        ],
      ],
    ),
  );
  return doc.save();
}
