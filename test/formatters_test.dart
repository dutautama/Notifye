import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:usahakonten/core/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('format rupiah tanpa desimal', () {
    expect(Fmt.rupiah(1500000), 'Rp 1.500.000');
    expect(Fmt.rupiah(null), 'Rp 0');
  });

  test('format tanggal Indonesia', () {
    expect(Fmt.date(DateTime(2026, 11, 22)), '22 Nov 2026');
  });
}
