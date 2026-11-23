import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'invoice_repository.dart';

class TrxItemInput {
  const TrxItemInput({this.productId, required this.name, required this.qty, required this.price, this.unitCost});
  final String? productId;
  final String name;
  final double qty;
  final double price;

  /// Modal per unit. null → diambil dari harga modal produk saat ini (penjualan) / 0.
  final double? unitCost;
}

/// Laba (margin) satu penjualan: (subtotal − diskon) − total modal. Pajak bukan laba.
double marginOf({required double subtotal, required double discount, required double cost}) =>
    subtotal - discount - cost;

class TrxInput {
  const TrxInput({
    required this.type,
    required this.items,
    this.trxDate,
    this.dueDate,
    this.customerId,
    this.supplierId,
    this.discount = 0,
    this.tax = 0,
    this.notes,
    this.initialPayment = 0,
    this.paymentMethod = 'tunai',
  });

  final String type; // 'sale' | 'purchase'
  final List<TrxItemInput> items;
  final DateTime? trxDate;
  final DateTime? dueDate;
  final String? customerId;
  final String? supplierId;
  final double discount;
  final double tax;
  final String? notes;
  final double initialPayment; // DP / pelunasan langsung
  final String paymentMethod;
}

/// Ringkasan penjualan per hari (untuk dashboard & laporan).
class DailySalesRow {
  const DailySalesRow(this.date, this.omzet, this.trxCount, [this.profit = 0]);
  final DateTime date;
  final double omzet;
  final int trxCount;
  final double profit; // laba (margin)
}

/// Baris daftar transaksi + nama pihak (pelanggan/supplier).
class TrxListRow {
  const TrxListRow(this.trx, this.partyName);
  final Trx trx;
  final String partyName;
}

/// Rekap per item untuk laporan (produk terlaris / terbanyak dibeli).
class ItemSummaryRow {
  const ItemSummaryRow(this.name, this.qty, this.revenue, [this.cost = 0]);
  final String name;
  final double qty;
  final double revenue;
  final double cost;
  double get profit => revenue - cost;
  double get marginPercent => revenue == 0 ? 0 : profit * 100 / revenue;
}

/// Transaksi penjualan/pembelian & pembayaran.
/// Stok, total, dan status lunas dihitung TRIGGER database.
class TransaksiRepository {
  TransaksiRepository(this._db, this._invoices);
  final AppDatabase _db;
  final InvoiceRepository _invoices;

  /// Buat transaksi lengkap secara atomik (header + item + pembayaran awal).
  Future<Trx> createTransaction(TrxInput input) {
    if (input.type != 'sale' && input.type != 'purchase') {
      throw ArgumentError('Jenis transaksi tidak valid: ${input.type}');
    }
    if (input.items.isEmpty) {
      throw ArgumentError('Transaksi harus memiliki minimal 1 item');
    }
    final date = _dateOnly(input.trxDate ?? DateTime.now());

    return _db.transaction(() async {
      final id = newId();
      await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: Value(id),
              type: input.type,
              number: await _invoices.nextDocNumber(input.type, date),
              trxDate: date,
              dueDate: Value(input.dueDate == null ? null : _dateOnly(input.dueDate!)),
              customerId: Value(input.type == 'sale' ? input.customerId : null),
              supplierId: Value(input.type == 'purchase' ? input.supplierId : null),
              discount: Value(input.discount),
              tax: Value(input.tax),
              notes: Value(input.notes),
            ),
          );
      for (final item in input.items) {
        await _db
            .into(_db.transactionItems)
            .insert(
              TransactionItemsCompanion.insert(
                transactionId: id,
                productId: Value(item.productId),
                name: item.name,
                qty: item.qty,
                price: item.price,
                unitCost: Value(await _unitCostFor(input.type, item)),
              ),
            );
      }
      if (input.initialPayment > 0) {
        await _db
            .into(_db.payments)
            .insert(
              PaymentsCompanion.insert(
                transactionId: id,
                payDate: date,
                amount: input.initialPayment,
                method: Value(input.paymentMethod),
              ),
            );
      }
      return (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingle();
    });
  }

  Stream<List<Trx>> watchRecent({String? type, int limit = 100}) {
    final q = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.trxDate), (t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    if (type != null) q.where((t) => t.type.equals(type));
    return q.watch();
  }

  /// Daftar transaksi untuk layar riwayat. [type]: 'sale'/'purchase'/null.
  /// [unpaidOnly] hanya yang belum lunas, [includeDeleted] tampilkan yang dibatalkan.
  Stream<List<TrxListRow>> watchList({
    String? type,
    bool unpaidOnly = false,
    bool includeDeleted = false,
    String search = '',
    int limit = 300,
  }) {
    final t = _db.transactions;
    final c = _db.customers;
    final s = _db.suppliers;
    final q =
        _db.select(t).join([
            leftOuterJoin(c, c.id.equalsExp(t.customerId)),
            leftOuterJoin(s, s.id.equalsExp(t.supplierId)),
          ])
          ..orderBy([OrderingTerm.desc(t.trxDate), OrderingTerm.desc(t.createdAt)])
          ..limit(limit);
    if (!includeDeleted) q.where(t.deletedAt.isNull());
    if (type != null) q.where(t.type.equals(type));
    if (unpaidOnly) q.where(t.status.isNotValue('lunas') & t.deletedAt.isNull());
    final term = search.trim().toLowerCase();
    if (term.isNotEmpty) {
      q.where(t.number.lower().contains(term) | c.name.lower().contains(term) | s.name.lower().contains(term));
    }
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          TrxListRow(r.readTable(t), r.readTableOrNull(c)?.name ?? r.readTableOrNull(s)?.name ?? 'Umum'),
      ],
    );
  }

  /// Transaksi aktif bertipe [type] dalam rentang tanggal [from]..[to] (inklusif).
  Future<List<TrxListRow>> listForPeriod(String type, DateTime from, DateTime to) async {
    final t = _db.transactions;
    final c = _db.customers;
    final s = _db.suppliers;
    final q =
        _db.select(t).join([
            leftOuterJoin(c, c.id.equalsExp(t.customerId)),
            leftOuterJoin(s, s.id.equalsExp(t.supplierId)),
          ])
          ..where(
            t.deletedAt.isNull() &
                t.type.equals(type) &
                t.trxDate.isBiggerOrEqualValue(_dateOnly(from)) &
                t.trxDate.isSmallerThanValue(_dateOnly(to).add(const Duration(days: 1))),
          )
          ..orderBy([OrderingTerm.asc(t.trxDate), OrderingTerm.asc(t.number)]);
    final rows = await q.get();
    return [
      for (final r in rows)
        TrxListRow(r.readTable(t), r.readTableOrNull(c)?.name ?? r.readTableOrNull(s)?.name ?? 'Umum'),
    ];
  }

  /// Rekap item (nama, total qty, total nilai) untuk transaksi aktif dalam periode.
  Future<List<ItemSummaryRow>> itemSummary(String type, DateTime from, DateTime to) async {
    final rows = await _db
        .customSelect(
          'SELECT ti.name AS name, SUM(ti.qty) AS qty, SUM(ti.subtotal) AS revenue, '
          'SUM(ti.qty * ti.unit_cost) AS cost '
          'FROM transaction_items ti JOIN transactions t ON t.id = ti.transaction_id '
          'WHERE t.deleted_at IS NULL AND t.type = ? AND t.trx_date >= ? AND t.trx_date < ? '
          'GROUP BY lower(ti.name) ORDER BY revenue DESC',
          variables: [
            Variable.withString(type),
            Variable.withDateTime(_dateOnly(from)),
            Variable.withDateTime(_dateOnly(to).add(const Duration(days: 1))),
          ],
          readsFrom: {_db.transactionItems, _db.transactions},
        )
        .get();
    return [
      for (final r in rows)
        ItemSummaryRow(r.read<String>('name'), r.read<double>('qty'), r.read<double>('revenue'), r.read<double>('cost')),
    ];
  }

  Future<Trx?> getByNumber(String number) =>
      (_db.select(_db.transactions)..where((t) => t.number.equals(number))).getSingleOrNull();

  Future<Trx?> getById(String id) => (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Batalkan transaksi (soft delete) → trigger mengembalikan stok.
  Future<void> softDelete(String id) =>
      (_db.update(_db.transactions)..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
        TransactionsCompanion(deletedAt: Value(DateTime.now())),
      );

  /// Pulihkan transaksi yang dibatalkan → trigger menerapkan stok lagi.
  Future<void> restore(String id) =>
      (_db.update(_db.transactions)..where((t) => t.id.equals(id) & t.deletedAt.isNotNull())).write(
        const TransactionsCompanion(deletedAt: Value(null)),
      );

  Future<void> addPayment(
    String transactionId, {
    required double amount,
    String method = 'tunai',
    DateTime? date,
    String? notes,
  }) async {
    if (amount <= 0) throw ArgumentError('Jumlah bayar harus lebih dari 0');
    await _db
        .into(_db.payments)
        .insert(
          PaymentsCompanion.insert(
            transactionId: transactionId,
            payDate: _dateOnly(date ?? DateTime.now()),
            amount: amount,
            method: Value(method),
            notes: Value(notes),
          ),
        );
  }

  Future<void> deletePayment(String paymentId) => (_db.update(_db.payments)..where((p) => p.id.equals(paymentId)))
      .write(PaymentsCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  /// Omzet penjualan per hari dalam rentang [from]..[to] (inklusif, tanggal lokal).
  /// Snapshot modal per unit: nilai eksplisit, atau harga modal produk saat ini (penjualan).
  /// Pembelian: modal = harga beli itu sendiri.
  Future<double> _unitCostFor(String type, TrxItemInput item) async {
    if (item.unitCost != null) return item.unitCost! < 0 ? 0 : item.unitCost!;
    if (type == 'purchase') return item.price;
    if (item.productId == null) return 0;
    final p = await (_db.select(_db.products)..where((x) => x.id.equals(item.productId!))).getSingleOrNull();
    return p?.buyPrice ?? 0;
  }

  /// Omzet, jumlah transaksi & laba penjualan per hari dalam [from]..[to] (inklusif, tanggal lokal).
  Future<List<DailySalesRow>> dailySales(DateTime from, DateTime to) async {
    final rows = await _db.customSelect(
      'SELECT t.trx_date AS d, t.total AS total, t.subtotal AS subtotal, t.discount AS discount, '
      'COALESCE((SELECT SUM(ti.qty * ti.unit_cost) FROM transaction_items ti WHERE ti.transaction_id = t.id), 0) AS cost '
      "FROM transactions t WHERE t.type = 'sale' AND t.deleted_at IS NULL AND t.trx_date >= ? AND t.trx_date < ?",
      variables: [
        Variable.withDateTime(_dateOnly(from)),
        Variable.withDateTime(_dateOnly(to).add(const Duration(days: 1))),
      ],
      readsFrom: {_db.transactions, _db.transactionItems},
    ).get();
    final byDay = <DateTime, (double, int, double)>{};
    for (final r in rows) {
      final d = _dateOnly(r.read<DateTime>('d'));
      final profit = marginOf(
          subtotal: r.read<double>('subtotal'), discount: r.read<double>('discount'), cost: r.read<double>('cost'));
      final cur = byDay[d] ?? (0.0, 0, 0.0);
      byDay[d] = (cur.$1 + r.read<double>('total'), cur.$2 + 1, cur.$3 + profit);
    }
    return [for (final e in byDay.entries) DailySalesRow(e.key, e.value.$1, e.value.$2, e.value.$3)]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Total modal per transaksi (untuk laporan laba per transaksi).
  Future<Map<String, double>> costByTransaction(List<String> trxIds) async {
    final out = <String, double>{};
    for (var i = 0; i < trxIds.length; i += 500) {
      final chunk = trxIds.sublist(i, i + 500 > trxIds.length ? trxIds.length : i + 500);
      final rows = await _db.customSelect(
        'SELECT transaction_id AS id, SUM(qty * unit_cost) AS cost FROM transaction_items '
        'WHERE transaction_id IN (${List.filled(chunk.length, '?').join(',')}) GROUP BY transaction_id',
        variables: [for (final id in chunk) Variable.withString(id)],
        readsFrom: {_db.transactionItems},
      ).get();
      for (final r in rows) {
        out[r.read<String>('id')] = r.read<double>('cost');
      }
    }
    return out;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
