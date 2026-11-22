// ignore_for_file: recursive_getters — pola resmi drift untuk check() pada kolom.
// Skema database lokal (SQLite via drift).
// Nama tabel & kolom sama dengan versi cloud lama agar export Supabase → JSON
// bisa langsung di-restore. Semua id = UUID teks (aman untuk merge antar-device).
// Waktu disimpan sebagai detik Unix (default drift).
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

mixin Timestamps on Table {
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

mixin SoftDelete on Table {
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

mixin UuidPk on Table {
  TextColumn get id => text().clientDefault(newId)();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------- meta
/// Key-value: schema_version, last_auto_backup, dll.
@DataClassName('MetaEntry')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

// ---------------------------------------------------------------- usaha
/// Satu baris saja (id = 1).
@DataClassName('BusinessProfileRow')
class BusinessProfile extends Table with Timestamps {
  IntColumn get id => integer().withDefault(const Constant(1)).check(id.equals(1))();
  TextColumn get name => text().withDefault(const Constant('Usaha Saya'))();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  TextColumn get invoicePrefix => text().withDefault(const Constant('INV'))();
  TextColumn get purchasePrefix => text().withDefault(const Constant('PO'))();
  TextColumn get invoiceFooter =>
      text().nullable().withDefault(const Constant('Terima kasih atas kepercayaan Anda.'))();
  TextColumn get bankInfo => text().nullable()();
  RealColumn get taxPercent => real().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Penomoran dokumen per jenis & bulan: INV-202611-0001.
@DataClassName('DocCounter')
class DocCounters extends Table {
  TextColumn get docType => text()(); // 'sale' | 'purchase'
  TextColumn get period => text()(); // 'YYYYMM'
  IntColumn get lastNo => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {docType, period};
}

@DataClassName('Category')
class Categories extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get color => text().nullable()();
}

@DataClassName('Product')
class Products extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get categoryId => text().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get kind =>
      text().withDefault(const Constant('jasa')).check(kind.isIn(const ['barang', 'jasa', 'digital']))();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  RealColumn get sellPrice => real().withDefault(const Constant(0)).check(sellPrice.isBiggerOrEqualValue(0))();
  RealColumn get buyPrice => real().withDefault(const Constant(0)).check(buyPrice.isBiggerOrEqualValue(0))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  RealColumn get stock => real().withDefault(const Constant(0))();
  RealColumn get minStock => real().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  TextColumn get imagePath => text().nullable()(); // relatif ke folder attachments/
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('Customer')
class Customers extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
}

@DataClassName('Supplier')
class Suppliers extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Transaksi penjualan (sale) & pembelian (purchase) = juga dokumen invoice/PO.
/// subtotal/total/paid_amount/status diisi TRIGGER (lihat migrations/schema_v1.dart).
@DataClassName('Trx')
class Transactions extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get type => text().check(type.isIn(const ['sale', 'purchase']))();
  TextColumn get number => text().unique()();
  DateTimeColumn get trxDate => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get customerId => text().nullable().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get supplierId => text().nullable().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0)).check(discount.isBiggerOrEqualValue(0))();
  RealColumn get tax => real().withDefault(const Constant(0)).check(tax.isBiggerOrEqualValue(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0))();
  TextColumn get status =>
      text().withDefault(const Constant('belum')).check(status.isIn(const ['lunas', 'sebagian', 'belum']))();
  TextColumn get notes => text().nullable()();

  @override
  List<String> get customConstraints => const [
    "CHECK (NOT (type = 'sale' AND supplier_id IS NOT NULL))",
    "CHECK (NOT (type = 'purchase' AND customer_id IS NOT NULL))",
  ];
}

@DataClassName('TrxItem')
class TransactionItems extends Table with UuidPk, Timestamps {
  TextColumn get transactionId => text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text()(); // snapshot nama saat transaksi
  RealColumn get qty => real().check(qty.isBiggerThanValue(0))();
  RealColumn get price => real().check(price.isBiggerOrEqualValue(0))();
  RealColumn get subtotal => real().generatedAs(qty * price, stored: true)();
}

@DataClassName('Payment')
class Payments extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get transactionId => text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get payDate => dateTime()();
  RealColumn get amount => real().check(amount.isBiggerThanValue(0))();
  TextColumn get method => text()
      .withDefault(const Constant('tunai'))
      .check(method.isIn(const ['tunai', 'transfer', 'qris', 'ewallet', 'lainnya']))();
  TextColumn get notes => text().nullable()();
}

/// Riwayat keluar/masuk stok (diisi trigger & penyesuaian manual).
@DataClassName('StockMovement')
class StockMovements extends Table with UuidPk {
  TextColumn get productId => text().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get transactionId => text().nullable().references(Transactions, #id, onDelete: KeyAction.setNull)();
  RealColumn get qtyChange => real()();
  TextColumn get reason => text().check(
    reason.isIn(const ['penjualan', 'pembelian', 'penyesuaian', 'batal_penjualan', 'batal_pembelian']),
  )();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------- konten
@DataClassName('ContentIdea')
class ContentIdeas extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get description => text().nullable()();
  TextColumn get platforms => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get status =>
      text().withDefault(const Constant('ide')).check(status.isIn(const ['ide', 'produksi', 'review', 'publish']))();
  IntColumn get priority => integer().withDefault(const Constant(2)).check(priority.isBetweenValues(1, 3))();
  TextColumn get pillar => text().nullable()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON array
  DateTimeColumn get dueDate => dateTime().nullable()();
  RealColumn get position => real().withDefault(const Constant(0))();
}

@DataClassName('ContentAsset')
class ContentAssets extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get ideaId => text().references(ContentIdeas, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()
      .withDefault(const Constant('link'))
      .check(kind.isIn(const ['link', 'gdrive', 'video', 'gambar', 'audio', 'dokumen', 'naskah']))();
  TextColumn get title => text()();
  TextColumn get url => text().nullable()();
  TextColumn get filePath => text().nullable()(); // relatif ke folder attachments/
  TextColumn get notes => text().nullable()();

  @override
  List<String> get customConstraints => const ["CHECK (url IS NOT NULL OR file_path IS NOT NULL OR kind = 'naskah')"];
}

@DataClassName('ContentSchedule')
class ContentSchedules extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get ideaId => text().references(ContentIdeas, #id, onDelete: KeyAction.cascade)();
  TextColumn get platform => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('terjadwal')).check(status.isIn(const ['terjadwal', 'tayang', 'batal']))();
  TextColumn get notes => text().nullable()();
}

@DataClassName('ContentPublication')
class ContentPublications extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get ideaId => text().references(ContentIdeas, #id, onDelete: KeyAction.cascade)();
  TextColumn get scheduleId => text().nullable().references(ContentSchedules, #id, onDelete: KeyAction.setNull)();
  TextColumn get platform => text()();
  TextColumn get postUrl => text().nullable()();
  DateTimeColumn get publishedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get views => integer().withDefault(const Constant(0)).check(views.isBiggerOrEqualValue(0))();
  IntColumn get reach => integer().withDefault(const Constant(0)).check(reach.isBiggerOrEqualValue(0))();
  IntColumn get likes => integer().withDefault(const Constant(0)).check(likes.isBiggerOrEqualValue(0))();
  IntColumn get comments => integer().withDefault(const Constant(0)).check(comments.isBiggerOrEqualValue(0))();
  IntColumn get shares => integer().withDefault(const Constant(0)).check(shares.isBiggerOrEqualValue(0))();
  IntColumn get saves => integer().withDefault(const Constant(0)).check(saves.isBiggerOrEqualValue(0))();
  IntColumn get followersGained => integer().withDefault(const Constant(0))();
  IntColumn get leads => integer().withDefault(const Constant(0)).check(leads.isBiggerOrEqualValue(0))();
  DateTimeColumn get metricsUpdatedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
}

/// Relasi banyak-ke-banyak ide konten ↔ produk/jasa.
@DataClassName('ContentProductLink')
class ContentProductLinks extends Table {
  TextColumn get ideaId => text().references(ContentIdeas, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().references(Products, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column<Object>> get primaryKey => {ideaId, productId};
}

// ================================================================ skema v2
// ---------------------------------------------------------------- catatan
@DataClassName('Note')
class Notes extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))(); // markdown ringan
  TextColumn get category => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

/// Tag catatan (huruf kecil). Satu baris per pasangan catatan–tag.
@DataClassName('NoteTag')
class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text().withLength(min: 1, max: 50)();
  @override
  Set<Column<Object>> get primaryKey => {noteId, tag};
}

@DataClassName('NoteAttachment')
class NoteAttachments extends Table with UuidPk, SoftDelete {
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()(); // relatif ke folder attachments/
  TextColumn get fileName => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tautan catatan ke entitas lain (polimorfik; integritas dijaga aplikasi).
@DataClassName('NoteLink')
class NoteLinks extends Table {
  TextColumn get noteId => text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get entityType => text().check(entityType.isIn(const [
        'product',
        'customer',
        'supplier',
        'transaction',
        'content_idea',
        'watchlist_item',
      ]))();
  TextColumn get entityId => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column<Object>> get primaryKey => {noteId, entityType, entityId};
}

// ------------------------------------------------- bacaan & tontonan
@DataClassName('WatchlistItem')
class WatchlistItems extends Table with UuidPk, Timestamps, SoftDelete {
  TextColumn get type => text()
      .withDefault(const Constant('lainnya'))
      .check(type.isIn(const ['buku', 'artikel', 'video', 'film', 'serial', 'podcast', 'lainnya']))();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get creator => text().nullable()(); // penulis / sumber / channel
  TextColumn get url => text().nullable()();
  TextColumn get platform => text().nullable()();
  TextColumn get status => text()
      .withDefault(const Constant('ingin'))
      .check(status.isIn(const ['ingin', 'sedang', 'selesai', 'ditunda', 'drop']))();
  IntColumn get rating => integer().nullable().check(rating.isBetweenValues(1, 5))();
  TextColumn get review => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get progress => integer().nullable().check(progress.isBiggerOrEqualValue(0))();
  IntColumn get progressTotal => integer().nullable().check(progressTotal.isBiggerOrEqualValue(0))();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get coverPath => text().nullable()(); // relatif ke attachments/
}

@DataClassName('WatchlistItemIdea')
class WatchlistItemIdeas extends Table {
  TextColumn get itemId => text().references(WatchlistItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get ideaId => text().references(ContentIdeas, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column<Object>> get primaryKey => {itemId, ideaId};
}
