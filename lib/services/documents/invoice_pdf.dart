import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formatters.dart';
import '../../data/repositories/invoice_repository.dart';

String _safe(String s) => s.replaceAll(' ', ' ').replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '?');
String _rp(double v) => _safe(Fmt.rupiah(v));
String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

const _statusLabel = {'lunas': 'LUNAS', 'sebagian': 'DIBAYAR SEBAGIAN', 'belum': 'BELUM DIBAYAR'};

/// PDF invoice (penjualan) / purchase order (pembelian) ukuran A4.
Future<Uint8List> buildInvoicePdf(InvoiceData d, {File? logoFile}) async {
  final t = d.trx;
  final isSale = t.type == 'sale';
  final party = isSale
      ? (d.customer == null ? null : (d.customer!.name, d.customer!.phone, d.customer!.email, d.customer!.address))
      : (d.supplier == null ? null : (d.supplier!.name, d.supplier!.phone, d.supplier!.email, d.supplier!.address));
  pw.MemoryImage? logo;
  if (logoFile != null && await logoFile.exists()) {
    try {
      logo = pw.MemoryImage(await logoFile.readAsBytes());
    } catch (_) {
      logo = null;
    }
  }
  final remaining = t.total - t.paidAmount;
  final accent = PdfColor.fromHex('#4F46E5');

  final doc = pw.Document(title: '${isSale ? 'Invoice' : 'Purchase Order'} ${t.number}', creator: 'UsahaKonten');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (logo != null) pw.Container(width: 64, height: 64, margin: const pw.EdgeInsets.only(right: 12), child: pw.Image(logo)),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_safe(d.profile.name), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (d.profile.address != null) pw.Text(_safe(d.profile.address!)),
            pw.Text(_safe([d.profile.phone, d.profile.email].whereType<String>().join('  |  '))),
          ]),
        ),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(isSale ? 'INVOICE' : 'PURCHASE ORDER',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.Text(_safe(t.number)),
          pw.Text('Tanggal: ${_safe(Fmt.date(t.trxDate))}'),
          if (t.dueDate != null) pw.Text('Jatuh tempo: ${_safe(Fmt.date(t.dueDate))}'),
        ]),
      ]),
      pw.SizedBox(height: 20),
      pw.Text(isSale ? 'Kepada:' : 'Supplier:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      if (party == null)
        pw.Text('Umum')
      else ...[
        pw.Text(_safe(party.$1)),
        if (party.$4 != null) pw.Text(_safe(party.$4!)),
        pw.Text(_safe([party.$2, party.$3].whereType<String>().join('  |  '))),
      ],
      pw.SizedBox(height: 16),
      pw.TableHelper.fromTextArray(
        headers: ['No', 'Item', 'Qty', 'Harga', 'Subtotal'],
        data: [
          for (var i = 0; i < d.items.length; i++)
            [
              '${i + 1}',
              _safe(d.items[i].name),
              _qty(d.items[i].qty),
              _rp(d.items[i].price),
              _rp(d.items[i].subtotal),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: accent),
        cellAlignments: {
          0: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
        columnWidths: {
          0: const pw.FixedColumnWidth(28),
          1: const pw.FlexColumnWidth(4),
          2: const pw.FixedColumnWidth(40),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(2),
        },
      ),
      pw.SizedBox(height: 12),
      pw.Row(children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: accent, width: 1.5)),
            child: pw.Text(_statusLabel[t.status] ?? t.status,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accent)),
          ),
        ),
        pw.SizedBox(width: 24),
        pw.SizedBox(
          width: 220,
          child: pw.Column(children: [
            _sum('Subtotal', _rp(t.subtotal)),
            if (t.discount > 0) _sum('Diskon', '- ${_rp(t.discount)}'),
            if (t.tax > 0) _sum('Pajak', _rp(t.tax)),
            pw.Divider(),
            _sum('TOTAL', _rp(t.total), bold: true),
            _sum('Dibayar', _rp(t.paidAmount)),
            if (remaining > 0) _sum('Sisa tagihan', _rp(remaining), bold: true),
          ]),
        ),
      ]),
      if (d.payments.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('Riwayat pembayaran', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        for (final p in d.payments)
          pw.Text('${_safe(Fmt.date(p.payDate))}  -  ${_rp(p.amount)}  (${p.method})'),
      ],
      if (d.profile.bankInfo != null && remaining > 0) ...[
        pw.SizedBox(height: 16),
        pw.Text('Pembayaran ke:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(_safe(d.profile.bankInfo!)),
      ],
      if (t.notes != null) ...[
        pw.SizedBox(height: 12),
        pw.Text('Catatan: ${_safe(t.notes!)}'),
      ],
      if (d.profile.invoiceFooter != null) ...[
        pw.SizedBox(height: 24),
        pw.Center(child: pw.Text(_safe(d.profile.invoiceFooter!), style: const pw.TextStyle(color: PdfColors.grey700))),
      ],
    ],
  ));
  return doc.save();
}

pw.Widget _sum(String label, String value, {bool bold = false}) {
  final style = pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(children: [pw.Text(label, style: style), pw.Spacer(), pw.Text(value, style: style)]),
  );
}
