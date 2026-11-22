import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Data lengkap satu dokumen (invoice penjualan / PO pembelian).
class InvoiceData {
  const InvoiceData({
    required this.trx,
    required this.items,
    required this.payments,
    required this.profile,
    this.customer,
    this.supplier,
  });

  final Trx trx;
  final List<TrxItem> items;
  final List<Payment> payments;
  final BusinessProfileRow profile;
  final Customer? customer;
  final Supplier? supplier;
}

/// Penomoran dokumen, profil usaha, dan data invoice.
class InvoiceRepository {
  InvoiceRepository(this._db);
  final AppDatabase _db;

  /// Nomor berikutnya: INV-YYYYMM-0001 / PO-YYYYMM-0001.
  /// Panggil di dalam transaksi database agar penomoran tidak bentrok.
  Future<String> nextDocNumber(String type, DateTime date) async {
    final period = '${date.year}${date.month.toString().padLeft(2, '0')}';
    final row = await _db.customSelect(
      'INSERT INTO doc_counters (doc_type, period, last_no) VALUES (?, ?, 1) '
      'ON CONFLICT (doc_type, period) DO UPDATE SET last_no = last_no + 1 '
      'RETURNING last_no',
      variables: [Variable.withString(type), Variable.withString(period)],
      readsFrom: {_db.docCounters},
    ).getSingle();
    final no = row.read<int>('last_no');
    final profile = await getProfile();
    final prefix = type == 'sale' ? profile.invoicePrefix : profile.purchasePrefix;
    return '$prefix-$period-${no.toString().padLeft(4, '0')}';
  }

  Future<BusinessProfileRow> getProfile() async {
    final row = await (_db.select(_db.businessProfile)..where((b) => b.id.equals(1)))
        .getSingleOrNull();
    if (row != null) return row;
    await _db.into(_db.businessProfile).insert(const BusinessProfileCompanion());
    return getProfile();
  }

  Stream<BusinessProfileRow?> watchProfile() =>
      (_db.select(_db.businessProfile)..where((b) => b.id.equals(1))).watchSingleOrNull();

  Future<void> updateProfile(BusinessProfileCompanion data) =>
      (_db.update(_db.businessProfile)..where((b) => b.id.equals(1)))
          .write(data.copyWith(updatedAt: Value(DateTime.now())));

  /// Stream data invoice; ikut berubah saat pembayaran/batal (baris transaksi
  /// diperbarui trigger).
  Stream<InvoiceData?> watchInvoiceData(String transactionId) =>
      (_db.select(_db.transactions)..where((t) => t.id.equals(transactionId)))
          .watchSingleOrNull()
          .asyncMap((_) => getInvoiceData(transactionId));

  Future<InvoiceData?> getInvoiceData(String transactionId) async {
    final trx = await (_db.select(_db.transactions)..where((t) => t.id.equals(transactionId)))
        .getSingleOrNull();
    if (trx == null) return null;
    final items = await (_db.select(_db.transactionItems)
          ..where((i) => i.transactionId.equals(transactionId))
          ..orderBy([(i) => OrderingTerm.asc(i.createdAt)]))
        .get();
    final payments = await (_db.select(_db.payments)
          ..where((p) => p.transactionId.equals(transactionId) & p.deletedAt.isNull())
          ..orderBy([(p) => OrderingTerm.asc(p.payDate)]))
        .get();
    final customer = trx.customerId == null
        ? null
        : await (_db.select(_db.customers)..where((c) => c.id.equals(trx.customerId!)))
            .getSingleOrNull();
    final supplier = trx.supplierId == null
        ? null
        : await (_db.select(_db.suppliers)..where((s) => s.id.equals(trx.supplierId!)))
            .getSingleOrNull();
    return InvoiceData(
      trx: trx,
      items: items,
      payments: payments,
      profile: await getProfile(),
      customer: customer,
      supplier: supplier,
    );
  }
}
