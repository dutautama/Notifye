import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/features/business/transactions/trx_form_logic.dart';
import 'package:usahakonten/widgets/form_fields.dart';

void main() {
  test('total: subtotal - diskon + pajak (dibulatkan rupiah)', () {
    final items = [
      DraftItem(name: 'A', qty: 2, price: 50000),
      DraftItem(name: 'B', qty: 1.5, price: 10000),
    ];
    final t = computeDraftTotals(items, discount: 5000, taxPercent: 11);
    expect(t.subtotal, 115000);
    expect(t.tax, 12100); // 11% x 110.000
    expect(t.total, 122100);
  });

  test('perkiraan laba di form: (subtotal − diskon) − modal', () {
    final items = [
      DraftItem(name: 'Kaos', qty: 2, price: 50000, unitCost: 30000),
      DraftItem(name: 'Jasa', qty: 1, price: 20000),
    ];
    expect(estimateProfit(items, 5000), 120000 - 5000 - 60000);
    expect(items.first.toInput().unitCost, 30000);
    expect(items.last.toInput().unitCost, 0);
  });

  test('diskon tidak boleh melebihi subtotal', () {
    final t = computeDraftTotals([DraftItem(name: 'A', qty: 1, price: 1000)], discount: 5000);
    expect(t.discount, 1000);
    expect(t.total, 0);
  });

  test('produk sama dengan harga sama digabung, item manual tidak', () {
    final items = <DraftItem>[];
    addOrMergeItem(items, DraftItem(productId: 'p1', name: 'Kaos', qty: 1, price: 50000));
    addOrMergeItem(items, DraftItem(productId: 'p1', name: 'Kaos', qty: 2, price: 50000));
    addOrMergeItem(items, DraftItem(productId: 'p1', name: 'Kaos', qty: 1, price: 45000));
    addOrMergeItem(items, DraftItem(name: 'Ongkir', qty: 1, price: 10000));
    addOrMergeItem(items, DraftItem(name: 'Ongkir', qty: 1, price: 10000));
    expect(items.map((i) => i.qty), [3, 1, 1, 1]);
  });

  test('format & baca input angka', () {
    expect(ThousandsInputFormatter.format(1500000), '1.500.000');
    expect(ThousandsInputFormatter.format(0), '');
    expect(QtyField.format(2), '2');
    expect(QtyField.format(2.5), '2,5');
    final f = ThousandsInputFormatter();
    final v = f.formatEditUpdate(const TextEditingValue(), const TextEditingValue(text: '12a345'));
    expect(v.text, '12.345');
  });
}
