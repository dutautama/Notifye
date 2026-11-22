import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Jadwal tayang + judul ide (untuk kalender & dashboard).
class ScheduleWithIdea {
  const ScheduleWithIdea(this.schedule, this.ideaTitle);
  final ContentSchedule schedule;
  final String ideaTitle;
}

/// Ide konten, aset, jadwal, publikasi, dan relasi ke produk.
class KontenRepository {
  KontenRepository(this._db);
  final AppDatabase _db;

  static const statuses = ['ide', 'produksi', 'review', 'publish'];

  static List<String> decodeList(String json) =>
      (jsonDecode(json) as List).map((e) => e.toString()).toList();
  static String encodeList(List<String> values) => jsonEncode(values);

  Stream<List<ContentIdea>> watchIdeas({String? status}) {
    final q = _db.select(_db.contentIdeas)
      ..where((i) => i.deletedAt.isNull())
      ..orderBy([(i) => OrderingTerm.asc(i.position), (i) => OrderingTerm.desc(i.createdAt)]);
    if (status != null) q.where((i) => i.status.equals(status));
    return q.watch();
  }

  Future<String> saveIdea(ContentIdeasCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.contentIdeas)..where((i) => i.id.equals(data.id.value)))
          .write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.contentIdeas).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> setStatus(String ideaId, String status) {
    if (!statuses.contains(status)) throw ArgumentError('Status tidak valid: $status');
    return (_db.update(_db.contentIdeas)..where((i) => i.id.equals(ideaId)))
        .write(ContentIdeasCompanion(status: Value(status), updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteIdea(String id) =>
      (_db.update(_db.contentIdeas)..where((i) => i.id.equals(id))).write(
          ContentIdeasCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  /// Jumlah ide per status (selalu berisi 4 kunci status).
  Future<Map<String, int>> statusCounts() async {
    final i = _db.contentIdeas;
    final count = i.id.count();
    final rows = await (_db.selectOnly(i)
          ..addColumns([i.status, count])
          ..where(i.deletedAt.isNull())
          ..groupBy([i.status]))
        .get();
    final result = {for (final s in statuses) s: 0};
    for (final r in rows) {
      result[r.read(i.status)!] = r.read(count) ?? 0;
    }
    return result;
  }

  /// Jadwal "terjadwal" dalam rentang [from, to).
  Future<List<ScheduleWithIdea>> schedulesBetween(DateTime from, DateTime to,
      {bool onlyPending = true}) async {
    final s = _db.contentSchedules;
    final i = _db.contentIdeas;
    final q = _db.select(s).join([innerJoin(i, i.id.equalsExp(s.ideaId))])
      ..where(s.deletedAt.isNull() &
          i.deletedAt.isNull() &
          s.scheduledAt.isBiggerOrEqualValue(from) &
          s.scheduledAt.isSmallerThanValue(to))
      ..orderBy([OrderingTerm.asc(s.scheduledAt)]);
    if (onlyPending) q.where(s.status.equals('terjadwal'));
    final rows = await q.get();
    return [for (final r in rows) ScheduleWithIdea(r.readTable(s), r.readTable(i).title)];
  }

  // ------------------------------------------------- relasi ide ↔ produk
  Future<void> linkProduct(String ideaId, String productId) => _db
      .into(_db.contentProductLinks)
      .insertOnConflictUpdate(ContentProductLinksCompanion.insert(ideaId: ideaId, productId: productId));

  Future<void> unlinkProduct(String ideaId, String productId) => (_db.delete(_db.contentProductLinks)
        ..where((l) => l.ideaId.equals(ideaId) & l.productId.equals(productId)))
      .go();

  Stream<List<Product>> watchLinkedProducts(String ideaId) {
    final l = _db.contentProductLinks;
    final p = _db.products;
    return (_db.select(p).join([innerJoin(l, l.productId.equalsExp(p.id))])
          ..where(l.ideaId.equals(ideaId) & p.deletedAt.isNull()))
        .map((r) => r.readTable(p))
        .watch();
  }

  Stream<List<ContentIdea>> watchIdeasForProduct(String productId) {
    final l = _db.contentProductLinks;
    final i = _db.contentIdeas;
    return (_db.select(i).join([innerJoin(l, l.ideaId.equalsExp(i.id))])
          ..where(l.productId.equals(productId) & i.deletedAt.isNull()))
        .map((r) => r.readTable(i))
        .watch();
  }
}
