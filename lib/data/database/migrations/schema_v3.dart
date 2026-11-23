// Migrasi skema v3: modal per unit di item transaksi (dasar perhitungan laba).
// Hanya MENAMBAH 1 kolom; data lama tidak dihapus.

/// Isi modal item penjualan yang masih 0 dari harga modal produk SAAT INI
/// (perkiraan untuk transaksi sebelum v3 / backup versi lama).
/// [idFilter] opsional: batasi ke item tertentu (mis. item hasil restore).
String backfillUnitCostSql({String idFilter = ''}) =>
    'UPDATE transaction_items SET unit_cost = COALESCE('
    '(SELECT p.buy_price FROM products p WHERE p.id = transaction_items.product_id), 0) '
    'WHERE product_id IS NOT NULL AND unit_cost = 0 '
    "AND transaction_id IN (SELECT id FROM transactions WHERE type = 'sale')$idFilter";
