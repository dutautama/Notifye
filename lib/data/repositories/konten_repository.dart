import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Jadwal tayang + judul ide (untuk kalender & dashboard).
class ScheduleWithIdea {
  const ScheduleWithIdea(this.schedule, this.ideaTitle);
  final ContentSchedule schedule;
  final String ideaTitle;
}

/// Performa satu ide konten (gabungan semua publikasi).
class ContentPerformanceRow {
  const ContentPerformanceRow({
    required this.ideaId,
    required this.title,
    required this.status,
    required this.publications,
    required this.views,
    required this.reach,
    required this.engagement,
    required this.leads,
    required this.followersGained,
  });
  final String ideaId;
  final String title;
  final String status;
  final int publications;
  final int views;
  final int reach;
  final int engagement;
  final int leads;
  final int followersGained;

  /// Engagement rate (%) = (likes+comments+shares+saves) / reach.
  double get engagementRate => reach == 0 ? 0 : engagement * 100 / reach;
}

/// Publikasi + judul ide (untuk daftar publikasi).
class PublicationWithIdea {
  const PublicationWithIdea(this.publication, this.ideaTitle);
  final ContentPublication publication;
  final String ideaTitle;
}

/// Ide konten, aset, jadwal, publikasi, dan relasi ke produk.
class KontenRepository {
  KontenRepository(this._db);
  final AppDatabase _db;

  static const statuses = ['ide', 'produksi', 'review', 'publish'];

  static List<String> decodeList(String json) => (jsonDecode(json) as List).map((e) => e.toString()).toList();
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
      await (_db.update(
        _db.contentIdeas,
      )..where((i) => i.id.equals(data.id.value))).write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.contentIdeas).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Stream<ContentIdea?> watchIdea(String id) =>
      (_db.select(_db.contentIdeas)..where((i) => i.id.equals(id))).watchSingleOrNull();

  Future<ContentIdea?> getIdea(String id) =>
      (_db.select(_db.contentIdeas)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<void> setStatus(String ideaId, String status) {
    if (!statuses.contains(status)) throw ArgumentError('Status tidak valid: $status');
    return (_db.update(_db.contentIdeas)..where((i) => i.id.equals(ideaId))).write(
      ContentIdeasCompanion(status: Value(status), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteIdea(String id) => (_db.update(_db.contentIdeas)..where((i) => i.id.equals(id))).write(
    ContentIdeasCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
  );

  /// Jumlah ide per status (selalu berisi 4 kunci status).
  Future<Map<String, int>> statusCounts() async {
    final i = _db.contentIdeas;
    final count = i.id.count();
    final rows =
        await (_db.selectOnly(i)
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
  Future<List<ScheduleWithIdea>> schedulesBetween(DateTime from, DateTime to, {bool onlyPending = true}) async {
    final s = _db.contentSchedules;
    final i = _db.contentIdeas;
    final q = _db.select(s).join([innerJoin(i, i.id.equalsExp(s.ideaId))])
      ..where(
        s.deletedAt.isNull() &
            i.deletedAt.isNull() &
            s.scheduledAt.isBiggerOrEqualValue(from) &
            s.scheduledAt.isSmallerThanValue(to),
      )
      ..orderBy([OrderingTerm.asc(s.scheduledAt)]);
    if (onlyPending) q.where(s.status.equals('terjadwal'));
    final rows = await q.get();
    return [for (final r in rows) ScheduleWithIdea(r.readTable(s), r.readTable(i).title)];
  }

  /// Performa per ide untuk publikasi dalam periode [from]..[to] (null = semua waktu).
  Future<List<ContentPerformanceRow>> performance({DateTime? from, DateTime? to}) async {
    final conds = <String>['p.deleted_at IS NULL', 'i.deleted_at IS NULL'];
    final vars = <Variable<Object>>[];
    if (from != null) {
      conds.add('p.published_at >= ?');
      vars.add(Variable.withDateTime(from));
    }
    if (to != null) {
      conds.add('p.published_at < ?');
      vars.add(Variable.withDateTime(to));
    }
    final rows = await _db
        .customSelect(
          'SELECT i.id AS id, i.title AS title, i.status AS status, COUNT(p.id) AS pubs, '
          'COALESCE(SUM(p.views),0) AS views, COALESCE(SUM(p.reach),0) AS reach, '
          'COALESCE(SUM(p.likes + p.comments + p.shares + p.saves),0) AS eng, '
          'COALESCE(SUM(p.leads),0) AS leads, COALESCE(SUM(p.followers_gained),0) AS foll '
          'FROM content_publications p JOIN content_ideas i ON i.id = p.idea_id '
          'WHERE ${conds.join(' AND ')} GROUP BY i.id ORDER BY reach DESC, views DESC',
          variables: vars,
          readsFrom: {_db.contentPublications, _db.contentIdeas},
        )
        .get();
    return [
      for (final r in rows)
        ContentPerformanceRow(
          ideaId: r.read<String>('id'),
          title: r.read<String>('title'),
          status: r.read<String>('status'),
          publications: r.read<int>('pubs'),
          views: r.read<int>('views'),
          reach: r.read<int>('reach'),
          engagement: r.read<int>('eng'),
          leads: r.read<int>('leads'),
          followersGained: r.read<int>('foll'),
        ),
    ];
  }

  // ------------------------------------------------------------- aset
  Stream<List<ContentAsset>> watchAssets(String ideaId) =>
      (_db.select(_db.contentAssets)
            ..where((a) => a.ideaId.equals(ideaId) & a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<String> saveAsset(ContentAssetsCompanion data) async {
    if (data.id.present) {
      await (_db.update(
        _db.contentAssets,
      )..where((a) => a.id.equals(data.id.value))).write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.contentAssets).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> deleteAsset(String id) => (_db.update(_db.contentAssets)..where((a) => a.id.equals(id))).write(
    ContentAssetsCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
  );

  // ------------------------------------------------------------ jadwal
  Stream<List<ContentSchedule>> watchSchedules(String ideaId) =>
      (_db.select(_db.contentSchedules)
            ..where((s) => s.ideaId.equals(ideaId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.scheduledAt)]))
          .watch();

  /// Semua jadwal (aktif) dalam rentang, untuk kalender. Reaktif.
  Stream<List<ScheduleWithIdea>> watchSchedulesBetween(DateTime from, DateTime to) {
    final s = _db.contentSchedules;
    final i = _db.contentIdeas;
    return (_db.select(s).join([innerJoin(i, i.id.equalsExp(s.ideaId))])
          ..where(
            s.deletedAt.isNull() &
                i.deletedAt.isNull() &
                s.scheduledAt.isBiggerOrEqualValue(from) &
                s.scheduledAt.isSmallerThanValue(to),
          )
          ..orderBy([OrderingTerm.asc(s.scheduledAt)]))
        .map((r) => ScheduleWithIdea(r.readTable(s), r.readTable(i).title))
        .watch();
  }

  Future<String> saveSchedule(ContentSchedulesCompanion data) async {
    if (data.id.present) {
      await (_db.update(
        _db.contentSchedules,
      )..where((s) => s.id.equals(data.id.value))).write(data.copyWith(updatedAt: Value(DateTime.now())));
      return data.id.value;
    }
    final id = newId();
    await _db.into(_db.contentSchedules).insert(data.copyWith(id: Value(id)));
    return id;
  }

  Future<void> deleteSchedule(String id) => (_db.update(_db.contentSchedules)..where((s) => s.id.equals(id))).write(
    ContentSchedulesCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())),
  );

  // --------------------------------------------------------- publikasi
  Stream<List<ContentPublication>> watchPublications(String ideaId) =>
      (_db.select(_db.contentPublications)
            ..where((p) => p.ideaId.equals(ideaId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.desc(p.publishedAt)]))
          .watch();

  Stream<List<PublicationWithIdea>> watchAllPublications({int limit = 200}) {
    final p = _db.contentPublications;
    final i = _db.contentIdeas;
    return (_db.select(p).join([innerJoin(i, i.id.equalsExp(p.ideaId))])
          ..where(p.deletedAt.isNull() & i.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(p.publishedAt)])
          ..limit(limit))
        .map((r) => PublicationWithIdea(r.readTable(p), r.readTable(i).title))
        .watch();
  }

  /// Simpan publikasi. Saat baru dibuat, trigger menandai jadwal "tayang" & ide "publish".
  Future<String> savePublication(ContentPublicationsCompanion data) async {
    if (data.id.present) {
      await (_db.update(_db.contentPublications)..where((p) => p.id.equals(data.id.value))).write(
        data.copyWith(updatedAt: Value(DateTime.now()), metricsUpdatedAt: Value(DateTime.now())),
      );
      return data.id.value;
    }
    final id = newId();
    await _db
        .into(_db.contentPublications)
        .insert(data.copyWith(id: Value(id), metricsUpdatedAt: Value(DateTime.now())));
    return id;
  }

  Future<void> deletePublication(String id) => (_db.update(_db.contentPublications)..where((p) => p.id.equals(id)))
      .write(ContentPublicationsCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  // ------------------------------------------------- relasi ide ↔ produk
  Future<void> linkProduct(String ideaId, String productId) => _db
      .into(_db.contentProductLinks)
      .insertOnConflictUpdate(ContentProductLinksCompanion.insert(ideaId: ideaId, productId: productId));

  Future<void> unlinkProduct(String ideaId, String productId) =>
      (_db.delete(_db.contentProductLinks)..where((l) => l.ideaId.equals(ideaId) & l.productId.equals(productId))).go();

  Stream<List<Product>> watchLinkedProducts(String ideaId) {
    final l = _db.contentProductLinks;
    final p = _db.products;
    return (_db.select(p).join([
      innerJoin(l, l.productId.equalsExp(p.id)),
    ])..where(l.ideaId.equals(ideaId) & p.deletedAt.isNull())).map((r) => r.readTable(p)).watch();
  }

  Stream<List<ContentIdea>> watchIdeasForProduct(String productId) {
    final l = _db.contentProductLinks;
    final i = _db.contentIdeas;
    return (_db.select(i).join([
      innerJoin(l, l.ideaId.equalsExp(i.id)),
    ])..where(l.productId.equals(productId) & i.deletedAt.isNull())).map((r) => r.readTable(i)).watch();
  }
}
