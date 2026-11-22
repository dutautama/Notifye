// Migrasi skema v1: index & trigger yang tidak bisa dinyatakan lewat tabel drift.
// Port dari 0001_init.sql (Postgres) → SQLite. Logika bisnis kritis (stok,
// total, status lunas) tetap di database agar konsisten apa pun UI-nya.
//
// Catatan SQLite:
// - Trigger tidak bisa mengubah NEW → total/status dihitung dengan UPDATE
//   setelah perubahan (lihat _recalc).
// - recursive_triggers OFF (default) → UPDATE di dalam trigger tidak memicu
//   trigger yang sama lagi.

const _now = "CAST(strftime('%s','now') AS INTEGER)";

/// UUID v4 acak di dalam SQL (untuk baris stock_movements dari trigger).
const _uuidSql =
    "lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || "
    "substr(lower(hex(randomblob(2))), 2) || '-' || "
    "substr('89ab', 1 + (abs(random()) % 4), 1) || substr(lower(hex(randomblob(2))), 2) || '-' || "
    "lower(hex(randomblob(6)))";

/// Hitung ulang subtotal, total, paid_amount, status untuk transaksi [idExpr].
String _recalc(String idExpr) {
  const sub = 'COALESCE((SELECT SUM(subtotal) FROM transaction_items WHERE transaction_id = transactions.id), 0)';
  const paid =
      'COALESCE((SELECT SUM(amount) FROM payments WHERE transaction_id = transactions.id AND deleted_at IS NULL), 0)';
  const total = 'MAX($sub - discount + tax, 0)';
  return '''
    UPDATE transactions SET
      subtotal = $sub,
      total = $total,
      paid_amount = $paid,
      status = CASE WHEN $paid >= $total THEN 'lunas'
                    WHEN $paid > 0 THEN 'sebagian'
                    ELSE 'belum' END,
      updated_at = $_now
    WHERE id = $idExpr;''';
}

/// Ubah stok semua item transaksi [trx] (alias baris transactions: NEW/OLD).
/// [restore] = true → membatalkan efek transaksi (stok kembali).
String _applyAllItems(String trx, {required bool restore}) {
  // sale mengurangi stok; restore membalik tanda.
  final sign = restore
      ? "CASE $trx.type WHEN 'sale' THEN 1 ELSE -1 END"
      : "CASE $trx.type WHEN 'sale' THEN -1 ELSE 1 END";
  final reason = restore
      ? "CASE $trx.type WHEN 'sale' THEN 'batal_penjualan' ELSE 'batal_pembelian' END"
      : "CASE $trx.type WHEN 'sale' THEN 'penjualan' ELSE 'pembelian' END";
  return '''
    UPDATE products SET
      stock = stock + ($sign) * (SELECT SUM(qty) FROM transaction_items
                                  WHERE transaction_id = $trx.id AND product_id = products.id),
      updated_at = $_now
    WHERE track_stock = 1
      AND id IN (SELECT product_id FROM transaction_items WHERE transaction_id = $trx.id);
    INSERT INTO stock_movements (id, product_id, transaction_id, qty_change, reason, created_at)
      SELECT $_uuidSql, ti.product_id, $trx.id, ($sign) * ti.qty, $reason, $_now
      FROM transaction_items ti JOIN products p ON p.id = ti.product_id AND p.track_stock = 1
      WHERE ti.transaction_id = $trx.id;''';
}

/// Ubah stok untuk satu baris item [item] (NEW/OLD). [reverse] membalik efek.
/// Hanya berlaku bila transaksi induk masih ada & tidak dihapus (soft delete
/// atau cascade sudah mengurus stoknya sendiri).
String _applyItem(String item, {required bool reverse}) {
  final active = _parentActive(item);
  const typeOf = 'SELECT type FROM transactions WHERE id = ';
  final sign = reverse
      ? "CASE ($typeOf$item.transaction_id) WHEN 'sale' THEN 1 ELSE -1 END"
      : "CASE ($typeOf$item.transaction_id) WHEN 'sale' THEN -1 ELSE 1 END";
  final reason = reverse
      ? "CASE ($typeOf$item.transaction_id) WHEN 'sale' THEN 'batal_penjualan' ELSE 'batal_pembelian' END"
      : "CASE ($typeOf$item.transaction_id) WHEN 'sale' THEN 'penjualan' ELSE 'pembelian' END";
  return '''
    UPDATE products SET stock = stock + ($sign) * $item.qty, updated_at = $_now
      WHERE id = $item.product_id AND track_stock = 1 AND $active;
    INSERT INTO stock_movements (id, product_id, transaction_id, qty_change, reason, created_at)
      SELECT $_uuidSql, $item.product_id, $item.transaction_id, ($sign) * $item.qty, $reason, $_now
      FROM products WHERE id = $item.product_id AND track_stock = 1 AND $active;''';
}

/// Item berpengaruh ke stok hanya jika transaksinya ada & tidak dihapus.
String _parentActive(String item) =>
    'EXISTS (SELECT 1 FROM transactions WHERE id = $item.transaction_id AND deleted_at IS NULL)';

const List<String> schemaV1Indexes = [
  "CREATE UNIQUE INDEX IF NOT EXISTS categories_name_uq ON categories (lower(name)) WHERE deleted_at IS NULL",
  "CREATE UNIQUE INDEX IF NOT EXISTS products_sku_uq ON products (sku) WHERE sku IS NOT NULL AND sku <> '' AND deleted_at IS NULL",
  'CREATE INDEX IF NOT EXISTS products_barcode_idx ON products (barcode)',
  'CREATE INDEX IF NOT EXISTS products_name_idx ON products (lower(name))',
  'CREATE INDEX IF NOT EXISTS products_category_idx ON products (category_id)',
  'CREATE INDEX IF NOT EXISTS customers_name_idx ON customers (lower(name))',
  'CREATE INDEX IF NOT EXISTS suppliers_name_idx ON suppliers (lower(name))',
  'CREATE INDEX IF NOT EXISTS transactions_date_idx ON transactions (trx_date DESC)',
  'CREATE INDEX IF NOT EXISTS transactions_status_idx ON transactions (type, status)',
  'CREATE INDEX IF NOT EXISTS transactions_customer_idx ON transactions (customer_id)',
  'CREATE INDEX IF NOT EXISTS transactions_supplier_idx ON transactions (supplier_id)',
  'CREATE INDEX IF NOT EXISTS transaction_items_trx_idx ON transaction_items (transaction_id)',
  'CREATE INDEX IF NOT EXISTS transaction_items_product_idx ON transaction_items (product_id)',
  'CREATE INDEX IF NOT EXISTS payments_trx_idx ON payments (transaction_id)',
  'CREATE INDEX IF NOT EXISTS stock_movements_product_idx ON stock_movements (product_id, created_at DESC)',
  'CREATE INDEX IF NOT EXISTS content_ideas_status_idx ON content_ideas (status, position)',
  'CREATE INDEX IF NOT EXISTS content_assets_idea_idx ON content_assets (idea_id)',
  'CREATE INDEX IF NOT EXISTS content_schedules_time_idx ON content_schedules (scheduled_at)',
  'CREATE INDEX IF NOT EXISTS content_schedules_idea_idx ON content_schedules (idea_id)',
  'CREATE INDEX IF NOT EXISTS content_publications_idea_idx ON content_publications (idea_id)',
  'CREATE INDEX IF NOT EXISTS content_publications_time_idx ON content_publications (published_at DESC)',
  'CREATE INDEX IF NOT EXISTS content_product_links_product_idx ON content_product_links (product_id)',
];

final List<String> schemaV1Triggers = [
  // --- item transaksi → stok + total ---------------------------------
  '''CREATE TRIGGER trg_items_ai AFTER INSERT ON transaction_items
     BEGIN
       ${_applyItem('NEW', reverse: false)}
       ${_recalc('NEW.transaction_id')}
     END''',
  '''CREATE TRIGGER trg_items_ad AFTER DELETE ON transaction_items
     BEGIN
       ${_applyItem('OLD', reverse: true)}
       ${_recalc('OLD.transaction_id')}
     END''',
  '''CREATE TRIGGER trg_items_au AFTER UPDATE OF qty, price, product_id ON transaction_items
     BEGIN
       ${_applyItem('OLD', reverse: true)}
       ${_applyItem('NEW', reverse: false)}
       ${_recalc('NEW.transaction_id')}
     END''',

  // --- transaksi dihapus (soft / hard) / dipulihkan → stok -----------
  '''CREATE TRIGGER trg_trx_soft_delete AFTER UPDATE OF deleted_at ON transactions
     WHEN OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL
     BEGIN ${_applyAllItems('NEW', restore: true)} END''',
  '''CREATE TRIGGER trg_trx_undelete AFTER UPDATE OF deleted_at ON transactions
     WHEN OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL
     BEGIN ${_applyAllItems('NEW', restore: false)} END''',
  '''CREATE TRIGGER trg_trx_bd BEFORE DELETE ON transactions
     WHEN OLD.deleted_at IS NULL
     BEGIN ${_applyAllItems('OLD', restore: true)} END''',

  // --- diskon/pajak berubah → total & status ---------------------------
  '''CREATE TRIGGER trg_trx_amounts AFTER UPDATE OF discount, tax ON transactions
     BEGIN ${_recalc('NEW.id')} END''',

  // --- pembayaran → paid_amount & status -------------------------------
  '''CREATE TRIGGER trg_payments_ai AFTER INSERT ON payments
     BEGIN ${_recalc('NEW.transaction_id')} END''',
  '''CREATE TRIGGER trg_payments_ad AFTER DELETE ON payments
     BEGIN ${_recalc('OLD.transaction_id')} END''',
  '''CREATE TRIGGER trg_payments_au AFTER UPDATE OF amount, deleted_at, transaction_id ON payments
     BEGIN ${_recalc('OLD.transaction_id')} ${_recalc('NEW.transaction_id')} END''',

  // --- publikasi konten → jadwal "tayang", ide "publish" ---------------
  '''CREATE TRIGGER trg_publication_ai AFTER INSERT ON content_publications
     BEGIN
       UPDATE content_schedules SET status = 'tayang', updated_at = $_now
         WHERE id = NEW.schedule_id AND status = 'terjadwal';
       UPDATE content_ideas SET status = 'publish', updated_at = $_now
         WHERE id = NEW.idea_id AND status <> 'publish';
     END''',
];
