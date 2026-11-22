import '../../../data/repositories/transaksi_repository.dart';

/// Baris item yang sedang diedit di form transaksi.
class DraftItem {
  DraftItem({this.productId, required this.name, required this.qty, required this.price, this.unit = 'pcs'});
  final String? productId;
  String name;
  double qty;
  double price;
  String unit;

  double get subtotal => qty * price;
  TrxItemInput toInput() => TrxItemInput(productId: productId, name: name, qty: qty, price: price);
}

/// Pratinjau total di form (angka final tetap dihitung trigger database).
class DraftTotals {
  const DraftTotals(this.subtotal, this.discount, this.tax, this.total);
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
}

DraftTotals computeDraftTotals(List<DraftItem> items, {double discount = 0, double taxPercent = 0}) {
  final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
  final d = discount.clamp(0, subtotal).toDouble();
  final tax = ((subtotal - d) * taxPercent / 100).roundToDouble();
  return DraftTotals(subtotal, d, tax, subtotal - d + tax);
}

/// Tambah item; produk yang sama digabung (qty dijumlah).
void addOrMergeItem(List<DraftItem> items, DraftItem item) {
  if (item.productId != null) {
    final i = items.indexWhere((e) => e.productId == item.productId && e.price == item.price);
    if (i >= 0) {
      items[i].qty += item.qty;
      return;
    }
  }
  items.add(item);
}
