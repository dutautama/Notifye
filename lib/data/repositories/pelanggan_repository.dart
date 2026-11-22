import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Kontak usaha: pelanggan & supplier.
class PelangganRepository {
  PelangganRepository(this._db);
  final AppDatabase _db;

  // ----------------------------------------------------------- pelanggan
  Stream<List<Customer>> watchCustomers({String search = ''}) {
    final q = _db.select(_db.customers)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.name.lower())]);
    final s = search.trim().toLowerCase();
    if (s.isNotEmpty) q.where((c) => c.name.lower().contains(s) | c.phone.contains(s));
    return q.watch();
  }

  Future<Customer?> getCustomer(String id) =>
      (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<String> saveCustomer(CustomersCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.customers)..where((c) => c.id.equals(data.id.value)))
          .write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.customers).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> deleteCustomer(String id) =>
      (_db.update(_db.customers)..where((c) => c.id.equals(id))).write(
          CustomersCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  // ------------------------------------------------------------ supplier
  Stream<List<Supplier>> watchSuppliers({String search = ''}) {
    final q = _db.select(_db.suppliers)
      ..where((s) => s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.asc(s.name.lower())]);
    final s = search.trim().toLowerCase();
    if (s.isNotEmpty) q.where((x) => x.name.lower().contains(s) | x.phone.contains(s));
    return q.watch();
  }

  Future<Supplier?> getSupplier(String id) =>
      (_db.select(_db.suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<String> saveSupplier(SuppliersCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.suppliers)..where((s) => s.id.equals(data.id.value)))
          .write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.suppliers).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> deleteSupplier(String id) =>
      (_db.update(_db.suppliers)..where((s) => s.id.equals(id))).write(
          SuppliersCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));
}
