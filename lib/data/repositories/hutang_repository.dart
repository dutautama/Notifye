import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Satu baris hutang (pembelian belum lunas) / piutang (penjualan belum lunas).
class DebtRow {
  const DebtRow({
    required this.transactionId,
    required this.kind,
    required this.number,
    required this.trxDate,
    required this.dueDate,
    required this.total,
    required this.paidAmount,
    required this.partyName,
    required this.partyPhone,
    required this.partyId,
  });

  final String transactionId;
  final String kind; // 'piutang' | 'hutang'
  final String number;
  final DateTime trxDate;
  final DateTime? dueDate;
  final double total;
  final double paidAmount;
  final String partyName;
  final String? partyPhone;
  final String? partyId;

  double get remaining => total - paidAmount;
  bool get isReceivable => kind == 'piutang';
  bool isOverdue(DateTime today) =>
      dueDate != null && dueDate!.isBefore(DateTime(today.year, today.month, today.day));
}

/// Hutang & piutang = transaksi yang belum lunas (diturunkan, bukan tabel terpisah).
class HutangRepository {
  HutangRepository(this._db);
  final AppDatabase _db;

  Selectable<DebtRow> _query({String? kind}) {
    final t = _db.transactions;
    final c = _db.customers;
    final s = _db.suppliers;
    final q = _db.select(t).join([
      leftOuterJoin(c, c.id.equalsExp(t.customerId)),
      leftOuterJoin(s, s.id.equalsExp(t.supplierId)),
    ])
      ..where(t.deletedAt.isNull() & t.status.isNotValue('lunas'))
      ..orderBy([OrderingTerm(expression: t.dueDate, nulls: NullsOrder.last), OrderingTerm.asc(t.trxDate)]);
    if (kind == 'piutang') q.where(t.type.equals('sale'));
    if (kind == 'hutang') q.where(t.type.equals('purchase'));
    return q.map((row) {
      final trx = row.readTable(t);
      final cust = row.readTableOrNull(c);
      final supp = row.readTableOrNull(s);
      return DebtRow(
        transactionId: trx.id,
        kind: trx.type == 'sale' ? 'piutang' : 'hutang',
        number: trx.number,
        trxDate: trx.trxDate,
        dueDate: trx.dueDate,
        total: trx.total,
        paidAmount: trx.paidAmount,
        partyName: cust?.name ?? supp?.name ?? 'Umum',
        partyPhone: cust?.phone ?? supp?.phone,
        partyId: cust?.id ?? supp?.id,
      );
    });
  }

  /// [kind]: null = semua, 'piutang', atau 'hutang'.
  Stream<List<DebtRow>> watchDebts({String? kind}) => _query(kind: kind).watch();
  Future<List<DebtRow>> getDebts({String? kind}) => _query(kind: kind).get();
}
