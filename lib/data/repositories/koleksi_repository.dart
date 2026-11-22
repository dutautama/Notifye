import 'package:drift/drift.dart';

import '../database/app_database.dart';

const watchlistTypes = ['buku', 'artikel', 'video', 'film', 'serial', 'podcast', 'lainnya'];
const watchlistStatuses = ['ingin', 'sedang', 'selesai', 'ditunda', 'drop'];

/// Statistik ringan koleksi.
class KoleksiStats {
  const KoleksiStats(this.byStatus, this.finishedThisMonth, this.averageRating, this.ratedCount);
  final Map<String, int> byStatus;
  final int finishedThisMonth;
  final double? averageRating;
  final int ratedCount;
  int get total => byStatus.values.fold(0, (a, b) => a + b);
}

/// Tanggal mulai/selesai otomatis saat status berubah (fungsi murni, diuji).
/// - "sedang" → isi tanggal mulai bila kosong.
/// - "selesai" → isi tanggal selesai (dan mulai) bila kosong.
/// - kembali ke "ingin" → kosongkan keduanya.
(DateTime?, DateTime?) applyStatusDates(String status, DateTime? started, DateTime? finished, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (status) {
    'sedang' => (started ?? today, null),
    'selesai' => (started ?? today, finished ?? today),
    'ingin' => (null, null),
    _ => (started, finished),
  };
}

/// Batasi progress ke 0..total (total null = tanpa batas atas).
int clampProgress(int value, int? total) {
  if (value < 0) return 0;
  if (total != null && total > 0 && value > total) return total;
  return value;
}

/// Daftar bacaan & tontonan + relasi ke ide konten.
class KoleksiRepository {
  KoleksiRepository(this._db);
  final AppDatabase _db;

  Stream<List<WatchlistItem>> watchItems({String? type, String? status, String search = ''}) {
    final w = _db.watchlistItems;
    final statusOrder = CaseWhenExpression(cases: [
      for (var i = 0; i < watchlistStatuses.length; i++)
        CaseWhen(w.status.equals(['sedang', 'ingin', 'ditunda', 'selesai', 'drop'][i]), then: Constant(i)),
    ]);
    final q = _db.select(w)
      ..where((x) => x.deletedAt.isNull())
      ..orderBy([(x) => OrderingTerm.asc(statusOrder), (x) => OrderingTerm.desc(x.updatedAt)]);
    if (type != null) q.where((x) => x.type.equals(type));
    if (status != null) q.where((x) => x.status.equals(status));
    final s = search.trim().toLowerCase();
    if (s.isNotEmpty) {
      q.where((x) => x.title.lower().contains(s) | x.creator.lower().contains(s) | x.platform.lower().contains(s));
    }
    return q.watch();
  }

  Stream<WatchlistItem?> watchItem(String id) =>
      (_db.select(_db.watchlistItems)..where((x) => x.id.equals(id))).watchSingleOrNull();

  Future<WatchlistItem?> getItem(String id) =>
      (_db.select(_db.watchlistItems)..where((x) => x.id.equals(id))).getSingleOrNull();

  Future<String> save(WatchlistItemsCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.watchlistItems)..where((x) => x.id.equals(data.id.value)))
          .write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.watchlistItems).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> setStatus(String id, String status) async {
    if (!watchlistStatuses.contains(status)) throw ArgumentError('Status tidak valid: $status');
    final item = await getItem(id);
    if (item == null) return;
    final (started, finished) = applyStatusDates(status, item.startedAt, item.finishedAt, DateTime.now());
    final completeProgress = status == 'selesai' && item.progressTotal != null && item.progressTotal! > 0;
    await (_db.update(_db.watchlistItems)..where((x) => x.id.equals(id))).write(WatchlistItemsCompanion(
      status: Value(status),
      startedAt: Value(started),
      finishedAt: Value(finished),
      progress: completeProgress ? Value(item.progressTotal) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> setRating(String id, int? rating) => (_db.update(_db.watchlistItems)..where((x) => x.id.equals(id)))
      .write(WatchlistItemsCompanion(rating: Value(rating), updatedAt: Value(DateTime.now())));

  /// Tambah/kurangi progress (episode/halaman). Mencapai total → otomatis "selesai".
  Future<void> addProgress(String id, int delta) async {
    final item = await getItem(id);
    if (item == null) return;
    final next = clampProgress((item.progress ?? 0) + delta, item.progressTotal);
    await (_db.update(_db.watchlistItems)..where((x) => x.id.equals(id))).write(WatchlistItemsCompanion(
      progress: Value(next),
      updatedAt: Value(DateTime.now()),
    ));
    if (item.status == 'ingin' && next > 0) await setStatus(id, 'sedang');
    if (item.progressTotal != null && item.progressTotal! > 0 && next >= item.progressTotal! && item.status != 'selesai') {
      await setStatus(id, 'selesai');
    }
  }

  Future<void> softDelete(String id) => (_db.update(_db.watchlistItems)..where((x) => x.id.equals(id)))
      .write(WatchlistItemsCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  /// Item berstatus "sedang" (untuk Beranda).
  Future<List<WatchlistItem>> inProgress({int limit = 3}) => (_db.select(_db.watchlistItems)
        ..where((x) => x.deletedAt.isNull() & x.status.equals('sedang'))
        ..orderBy([(x) => OrderingTerm.desc(x.updatedAt)])
        ..limit(limit))
      .get();

  Stream<KoleksiStats> watchStats({DateTime? now}) {
    return (_db.select(_db.watchlistItems)..where((x) => x.deletedAt.isNull())).watch().map((items) {
      final n = now ?? DateTime.now();
      final byStatus = {for (final s in watchlistStatuses) s: 0};
      var finishedThisMonth = 0;
      var ratingSum = 0, rated = 0;
      for (final i in items) {
        byStatus[i.status] = (byStatus[i.status] ?? 0) + 1;
        final f = i.finishedAt;
        if (i.status == 'selesai' && f != null && f.year == n.year && f.month == n.month) finishedThisMonth++;
        if (i.rating != null) {
          ratingSum += i.rating!;
          rated++;
        }
      }
      return KoleksiStats(byStatus, finishedThisMonth, rated == 0 ? null : ratingSum / rated, rated);
    });
  }

  // ------------------------------------------------- relasi item ↔ ide konten
  Future<void> linkIdea(String itemId, String ideaId) => _db
      .into(_db.watchlistItemIdeas)
      .insertOnConflictUpdate(WatchlistItemIdeasCompanion.insert(itemId: itemId, ideaId: ideaId));

  Future<void> unlinkIdea(String itemId, String ideaId) => (_db.delete(_db.watchlistItemIdeas)
        ..where((l) => l.itemId.equals(itemId) & l.ideaId.equals(ideaId)))
      .go();

  Stream<List<ContentIdea>> watchIdeasFor(String itemId) {
    final i = _db.contentIdeas;
    final l = _db.watchlistItemIdeas;
    return (_db.select(i).join([innerJoin(l, l.ideaId.equalsExp(i.id))])
          ..where(l.itemId.equals(itemId) & i.deletedAt.isNull()))
        .map((r) => r.readTable(i))
        .watch();
  }

  Stream<List<WatchlistItem>> watchItemsForIdea(String ideaId) {
    final w = _db.watchlistItems;
    final l = _db.watchlistItemIdeas;
    return (_db.select(w).join([innerJoin(l, l.itemId.equalsExp(w.id))])
          ..where(l.ideaId.equals(ideaId) & w.deletedAt.isNull()))
        .map((r) => r.readTable(w))
        .watch();
  }
}
