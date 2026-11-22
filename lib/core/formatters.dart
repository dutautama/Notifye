import 'package:intl/intl.dart';

/// Format angka & tanggal standar Indonesia. Selalu pakai helper ini,
/// jangan membuat NumberFormat/DateFormat baru di layar.
class Fmt {
  Fmt._();

  static final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  static final _number = NumberFormat.decimalPattern('id_ID');
  static final _compact = NumberFormat.compact(locale: 'id_ID');
  static final _date = DateFormat('d MMM yyyy', 'id_ID');
  static final _dateTime = DateFormat('d MMM yyyy, HH:mm', 'id_ID');

  /// 1500000 → "Rp 1.500.000"
  static String rupiah(num? value) => _rupiah.format(value ?? 0);

  /// 1500.5 → "1.500,5"
  static String number(num? value) => _number.format(value ?? 0);

  /// 15300 → "15,3 rb"
  static String compact(num? value) => _compact.format(value ?? 0);

  static String date(DateTime? d) => d == null ? '-' : _date.format(d.toLocal());

  static String dateTime(DateTime? d) => d == null ? '-' : _dateTime.format(d.toLocal());
}
