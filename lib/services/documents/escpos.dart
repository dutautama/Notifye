import 'dart:convert';

import '../../core/formatters.dart';
import '../../data/repositories/invoice_repository.dart';

/// Pembuat perintah ESC/POS minimal untuk printer thermal 58/80 mm.
class EscPos {
  EscPos({this.width = 32});

  /// Jumlah karakter per baris: 32 (58 mm) atau 48 (80 mm).
  final int width;
  final _bytes = <int>[0x1B, 0x40]; // ESC @ (reset)

  List<int> get bytes => List.unmodifiable(_bytes);

  void _ascii(String s) {
    // Printer thermal umumnya hanya ASCII; ganti karakter lain dengan '?'.
    _bytes.addAll(latin1.encode(s.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')));
  }

  EscPos align(int a) {
    _bytes.addAll([0x1B, 0x61, a]); // 0 kiri, 1 tengah, 2 kanan
    return this;
  }

  EscPos bold(bool on) {
    _bytes.addAll([0x1B, 0x45, on ? 1 : 0]);
    return this;
  }

  EscPos doubleSize(bool on) {
    _bytes.addAll([0x1D, 0x21, on ? 0x11 : 0x00]);
    return this;
  }

  EscPos text(String s) {
    for (final line in wrap(s, width)) {
      _ascii(line);
      _bytes.add(0x0A);
    }
    return this;
  }

  /// Teks kiri & kanan dalam satu baris (kanan diprioritaskan).
  EscPos leftRight(String left, String right) {
    final space = width - right.length - 1;
    if (space < 4) return text(left).align(2).text(right).align(0);
    final l = left.length > space ? left.substring(0, space) : left;
    _ascii(l.padRight(width - right.length) + right);
    _bytes.add(0x0A);
    return this;
  }

  EscPos line([String ch = '-']) => text(ch * width);

  EscPos feed([int n = 1]) {
    _bytes.addAll(List.filled(n, 0x0A));
    return this;
  }

  EscPos cut() {
    _bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V B 0 (partial cut + feed)
    return this;
  }

  static List<String> wrap(String s, int width) {
    final out = <String>[];
    for (final para in s.split('\n')) {
      var line = '';
      for (final word in para.split(' ')) {
        var w = word;
        while (w.length > width) {
          if (line.isNotEmpty) {
            out.add(line);
            line = '';
          }
          out.add(w.substring(0, width));
          w = w.substring(width);
        }
        if (line.isEmpty) {
          line = w;
        } else if (line.length + 1 + w.length <= width) {
          line = '$line $w';
        } else {
          out.add(line);
          line = w;
        }
      }
      out.add(line);
    }
    return out;
  }
}

String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
String _rp(double v) => Fmt.rupiah(v).replaceAll(' ', ' ');

/// Struk transaksi untuk printer thermal.
List<int> buildReceipt(InvoiceData d, {int width = 32}) {
  final p = EscPos(width: width);
  final t = d.trx;
  final party = d.customer?.name ?? d.supplier?.name;
  p.align(1).bold(true).doubleSize(true).text(d.profile.name).doubleSize(false).bold(false);
  if (d.profile.address != null) p.text(d.profile.address!);
  if (d.profile.phone != null) p.text(d.profile.phone!);
  p.align(0).line()
    ..leftRight(t.type == 'sale' ? 'No' : 'PO', t.number)
    ..leftRight('Tanggal', Fmt.date(t.trxDate));
  if (party != null) p.leftRight(t.type == 'sale' ? 'Pelanggan' : 'Supplier', party);
  p.line();
  for (final i in d.items) {
    p
      ..text(i.name)
      ..leftRight('  ${_qty(i.qty)} x ${_rp(i.price)}', _rp(i.subtotal));
  }
  p.line().leftRight('Subtotal', _rp(t.subtotal));
  if (t.discount > 0) p.leftRight('Diskon', '-${_rp(t.discount)}');
  if (t.tax > 0) p.leftRight('Pajak', _rp(t.tax));
  p.bold(true).leftRight('TOTAL', _rp(t.total)).bold(false).leftRight('Dibayar', _rp(t.paidAmount));
  final remaining = t.total - t.paidAmount;
  if (remaining > 0) {
    p.bold(true).leftRight('Sisa', _rp(remaining)).bold(false);
    if (t.dueDate != null) p.leftRight('Jatuh tempo', Fmt.date(t.dueDate));
  } else {
    p.align(1).bold(true).text('*** LUNAS ***').bold(false).align(0);
  }
  if (d.profile.bankInfo != null && remaining > 0) p.line().text(d.profile.bankInfo!);
  p.line().align(1);
  if (d.profile.invoiceFooter != null) p.text(d.profile.invoiceFooter!);
  return (p..feed(3)..cut()).bytes;
}
