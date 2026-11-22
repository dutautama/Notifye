import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Produk/jasa, kategori, dan stok.
class ProdukRepository {
  ProdukRepository(this._db);
  final AppDatabase _db;

  Stream<List<Product>> watchAll({String search = '', bool includeInactive = false}) {
    final q = _db.select(_db.products)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.name.lower())]);
    if (!includeInactive) q.where((p) => p.isActive.equals(true));
    final s = search.trim().toLowerCase();
    if (s.isNotEmpty) {
      q.where((p) => p.name.lower().contains(s) | p.sku.lower().contains(s) | p.barcode.equals(search.trim()));
    }
    return q.watch();
  }

  Future<Product?> getById(String id) => (_db.select(_db.products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Product?> findByBarcode(String barcode) =>
      (_db.select(_db.products)
            ..where((p) => p.barcode.equals(barcode) & p.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  /// Tambah (id kosong) atau ubah produk. Stok awal hanya dipakai saat tambah;
  /// perubahan stok berikutnya wajib lewat transaksi atau [adjustStock].
  Future<String> save(ProductsCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.products)..where((p) => p.id.equals(data.id.value))).write(
        data.copyWith(stock: const Value.absent(), updatedAt: Value(DateTime.now())),
      );
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.products).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> softDelete(String id) => _setDeleted(id, DateTime.now());
  Future<void> restore(String id) => _setDeleted(id, null);

  Future<void> _setDeleted(String id, DateTime? at) => (_db.update(
    _db.products,
  )..where((p) => p.id.equals(id))).write(ProductsCompanion(deletedAt: Value(at), updatedAt: Value(DateTime.now())));

  /// Stok opname / penyesuaian manual (+ masuk, - keluar), tercatat di riwayat.
  Future<void> adjustStock(String productId, double change, {String? notes}) {
    return _db.transaction(() async {
      final updated = await _db.customUpdate(
        'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
        variables: [Variable.withReal(change), Variable.withDateTime(DateTime.now()), Variable.withString(productId)],
        updates: {_db.products},
      );
      if (updated == 0) throw StateError('Produk tidak ditemukan');
      await _db
          .into(_db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              productId: productId,
              qtyChange: change,
              reason: 'penyesuaian',
              notes: Value(notes),
            ),
          );
    });
  }

  Stream<List<Product>> watchLowStock({int limit = 20}) {
    final q = _db.select(_db.products)
      ..where(
        (p) =>
            p.deletedAt.isNull() &
            p.isActive.equals(true) &
            p.trackStock.equals(true) &
            p.stock.isSmallerOrEqual(p.minStock),
      )
      ..orderBy([(p) => OrderingTerm.asc(p.stock)])
      ..limit(limit);
    return q.watch();
  }

  Stream<List<StockMovement>> watchMovements(String productId) =>
      (_db.select(_db.stockMovements)
            ..where((m) => m.productId.equals(productId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .watch();

  // ------------------------------------------------------------ kategori
  Stream<List<Category>> watchCategories() =>
      (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name.lower())]))
          .watch();

  Future<String> saveCategory({String? id, required String name, String? color}) async {
    if (id != null) {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(name: Value(name.trim()), color: Value(color), updatedAt: Value(DateTime.now())),
      );
      return id;
    }
    final newCatId = newId();
    await _db
        .into(_db.categories)
        .insert(CategoriesCompanion.insert(id: Value(newCatId), name: name.trim(), color: Value(color)));
    return newCatId;
  }

  /// Soft delete kategori; produk di dalamnya menjadi "tanpa kategori"
  /// (FK ON DELETE SET NULL tidak terpicu oleh soft delete).
  Future<void> deleteCategory(String id) => _db.transaction(() async {
    final now = DateTime.now();
    await (_db.update(_db.products)..where((p) => p.categoryId.equals(id))).write(
      ProductsCompanion(categoryId: const Value(null), updatedAt: Value(now)),
    );
    await (_db.update(
      _db.categories,
    )..where((c) => c.id.equals(id))).write(CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  });
}
