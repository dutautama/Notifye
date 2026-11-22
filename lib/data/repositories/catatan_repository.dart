import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Jenis entitas yang bisa ditautkan dengan catatan (nilai kolom note_links.entity_type).
abstract final class LinkType {
  static const product = 'product';
  static const customer = 'customer';
  static const supplier = 'supplier';
  static const transaction = 'transaction';
  static const contentIdea = 'content_idea';
  static const watchlistItem = 'watchlist_item';
  static const all = [product, customer, supplier, transaction, contentIdea, watchlistItem];
}

class NoteListRow {
  const NoteListRow(this.note, this.tags);
  final Note note;
  final List<String> tags;
}

/// Entitas tertaut yang sudah diberi judul untuk ditampilkan.
class LinkedEntity {
  const LinkedEntity(this.type, this.id, this.title, {this.missing = false});
  final String type;
  final String id;
  final String title;
  final bool missing; // entitas sudah dihapus
}

/// Ubah input bebas pengguna menjadi query FTS5 aman: tiap kata → "kata"* (AND).
/// Mengembalikan null bila tidak ada kata yang bisa dicari.
String? buildFtsQuery(String input) {
  final words = RegExp(r'[\p{L}\p{N}]+', unicode: true).allMatches(input).map((m) => m.group(0)!).toList();
  if (words.isEmpty) return null;
  return words.take(8).map((w) => '"${w.replaceAll('"', '')}"*').join(' ');
}

/// Normalisasi tag: huruf kecil, tanpa '#', spasi → '-', maks 50 karakter.
String? normalizeTag(String raw) {
  var t = raw.trim().toLowerCase().replaceAll('#', '').replaceAll(RegExp(r'\s+'), '-');
  if (t.isEmpty) return null;
  if (t.length > 50) t = t.substring(0, 50);
  return t;
}

/// Catatan: CRUD, tag, pin/arsip, pencarian FTS5, lampiran, tautan ke entitas lain.
class CatatanRepository {
  CatatanRepository(this._db);
  final AppDatabase _db;

  /// Daftar catatan: disematkan dulu, lalu terbaru. [search] memakai FTS5.
  Stream<List<NoteListRow>> watchNotes({String search = '', String? category, String? tag, bool archived = false}) {
    final where = <String>['n.deleted_at IS NULL', 'n.is_archived = ?'];
    final vars = <Variable<Object>>[Variable.withBool(archived)];
    final fts = buildFtsQuery(search);
    var from = 'notes n';
    if (fts != null) {
      from = 'notes n JOIN notes_fts f ON f.note_id = n.id';
      where.add('notes_fts MATCH ?');
      vars.add(Variable.withString(fts));
    }
    if (category != null) {
      where.add('n.category = ?');
      vars.add(Variable.withString(category));
    }
    if (tag != null) {
      where.add('EXISTS (SELECT 1 FROM note_tags t WHERE t.note_id = n.id AND t.tag = ?)');
      vars.add(Variable.withString(tag));
    }
    final query = _db.customSelect(
      'SELECT n.* FROM $from WHERE ${where.join(' AND ')} '
      'ORDER BY n.is_pinned DESC, n.updated_at DESC LIMIT 500',
      variables: vars,
      readsFrom: {_db.notes, _db.noteTags},
    );
    return query.watch().asyncMap((rows) async {
      final notes = [for (final r in rows) _db.notes.map(r.data)];
      final tags = await _tagsFor(notes.map((n) => n.id).toList());
      return [for (final n in notes) NoteListRow(n, tags[n.id] ?? const [])];
    });
  }

  Future<Map<String, List<String>>> _tagsFor(List<String> noteIds) async {
    if (noteIds.isEmpty) return const {};
    final rows = await (_db.select(_db.noteTags)
          ..where((t) => t.noteId.isIn(noteIds))
          ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
        .get();
    final out = <String, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r.noteId, () => []).add(r.tag);
    }
    return out;
  }

  Stream<Note?> watchNote(String id) => (_db.select(_db.notes)..where((n) => n.id.equals(id))).watchSingleOrNull();
  Future<Note?> getNote(String id) => (_db.select(_db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<String> createNote({String title = '', String body = '', String? category, String? linkType, String? linkId}) {
    return _db.transaction(() async {
      final id = newId();
      await _db.into(_db.notes).insert(NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            body: Value(body),
            category: Value(category),
          ));
      if (linkType != null && linkId != null) await link(id, linkType, linkId);
      return id;
    });
  }

  Future<void> updateNote(String id, {String? title, String? body, Value<String?> category = const Value.absent()}) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(NotesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(body),
        category: category,
        updatedAt: Value(DateTime.now()),
      ));

  Future<void> setPinned(String id, bool pinned) => (_db.update(_db.notes)..where((n) => n.id.equals(id)))
      .write(NotesCompanion(isPinned: Value(pinned), updatedAt: Value(DateTime.now())));

  Future<void> setArchived(String id, bool archived) => (_db.update(_db.notes)..where((n) => n.id.equals(id)))
      .write(NotesCompanion(isArchived: Value(archived), isPinned: archived ? const Value(false) : const Value.absent(),
          updatedAt: Value(DateTime.now())));

  Future<void> softDelete(String id) => (_db.update(_db.notes)..where((n) => n.id.equals(id)))
      .write(NotesCompanion(deletedAt: Value(DateTime.now()), updatedAt: Value(DateTime.now())));

  Future<void> restore(String id) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(const NotesCompanion(deletedAt: Value(null)));

  // ----------------------------------------------------------------- tag
  Stream<List<String>> watchTags(String noteId) => (_db.select(_db.noteTags)
        ..where((t) => t.noteId.equals(noteId))
        ..orderBy([(t) => OrderingTerm.asc(t.tag)]))
      .map((t) => t.tag)
      .watch();

  /// Ganti seluruh tag catatan (dinormalisasi, tanpa duplikat).
  Future<void> setTags(String noteId, Iterable<String> raw) => _db.transaction(() async {
        final tags = raw.map(normalizeTag).whereType<String>().toSet();
        await (_db.delete(_db.noteTags)..where((t) => t.noteId.equals(noteId))).go();
        for (final t in tags) {
          await _db.into(_db.noteTags).insert(NoteTagsCompanion.insert(noteId: noteId, tag: t));
        }
        await (_db.update(_db.notes)..where((n) => n.id.equals(noteId)))
            .write(NotesCompanion(updatedAt: Value(DateTime.now())));
      });

  /// Semua tag yang dipakai catatan aktif, beserta jumlahnya.
  Stream<List<(String, int)>> watchAllTags() => _db
      .customSelect(
        'SELECT t.tag AS tag, COUNT(*) AS n FROM note_tags t JOIN notes n ON n.id = t.note_id '
        'WHERE n.deleted_at IS NULL GROUP BY t.tag ORDER BY n DESC, t.tag',
        readsFrom: {_db.noteTags, _db.notes},
      )
      .watch()
      .map((rows) => [for (final r in rows) (r.read<String>('tag'), r.read<int>('n'))]);

  Stream<List<String>> watchCategories() => _db
      .customSelect(
        "SELECT DISTINCT category FROM notes WHERE deleted_at IS NULL AND category IS NOT NULL AND category <> '' "
        'ORDER BY lower(category)',
        readsFrom: {_db.notes},
      )
      .watch()
      .map((rows) => [for (final r in rows) r.read<String>('category')]);

  /// Catatan terbaru (untuk Beranda).
  Future<List<Note>> recent({int limit = 3}) => (_db.select(_db.notes)
        ..where((n) => n.deletedAt.isNull() & n.isArchived.equals(false))
        ..orderBy([(n) => OrderingTerm.desc(n.isPinned), (n) => OrderingTerm.desc(n.updatedAt)])
        ..limit(limit))
      .get();

  // ------------------------------------------------------------ lampiran
  Stream<List<NoteAttachment>> watchAttachments(String noteId) => (_db.select(_db.noteAttachments)
        ..where((a) => a.noteId.equals(noteId) & a.deletedAt.isNull())
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
      .watch();

  Future<void> addAttachment(String noteId,
          {required String filePath, required String fileName, String? mime, int? sizeBytes}) =>
      _db.into(_db.noteAttachments).insert(NoteAttachmentsCompanion.insert(
            noteId: noteId,
            filePath: filePath,
            fileName: fileName,
            mime: Value(mime),
            sizeBytes: Value(sizeBytes),
          ));

  Future<void> deleteAttachment(String id) => (_db.update(_db.noteAttachments)..where((a) => a.id.equals(id)))
      .write(NoteAttachmentsCompanion(deletedAt: Value(DateTime.now())));

  // -------------------------------------------------------------- tautan
  Future<void> link(String noteId, String type, String entityId) {
    if (!LinkType.all.contains(type)) throw ArgumentError('Jenis tautan tidak dikenal: $type');
    return _db.into(_db.noteLinks).insertOnConflictUpdate(
        NoteLinksCompanion.insert(noteId: noteId, entityType: type, entityId: entityId));
  }

  Future<void> unlink(String noteId, String type, String entityId) => (_db.delete(_db.noteLinks)
        ..where((l) => l.noteId.equals(noteId) & l.entityType.equals(type) & l.entityId.equals(entityId)))
      .go();

  Stream<List<NoteLink>> watchLinks(String noteId) => (_db.select(_db.noteLinks)
        ..where((l) => l.noteId.equals(noteId))
        ..orderBy([(l) => OrderingTerm.asc(l.createdAt)]))
      .watch();

  /// Catatan aktif yang ditautkan ke satu entitas (bagian "Catatan terkait").
  Stream<List<Note>> watchNotesFor(String type, String entityId) {
    final n = _db.notes;
    final l = _db.noteLinks;
    return (_db.select(n).join([innerJoin(l, l.noteId.equalsExp(n.id))])
          ..where(l.entityType.equals(type) & l.entityId.equals(entityId) & n.deletedAt.isNull())
          ..orderBy([OrderingTerm.desc(n.updatedAt)]))
        .map((r) => r.readTable(n))
        .watch();
  }

  /// Beri judul pada tautan (sekelompok query per jenis, bukan per baris).
  Future<List<LinkedEntity>> resolveLinks(List<NoteLink> links) async {
    final byType = <String, List<String>>{};
    for (final l in links) {
      byType.putIfAbsent(l.entityType, () => []).add(l.entityId);
    }
    final titles = <String, (String, bool)>{}; // "type:id" → (judul, terhapus)
    Future<void> load<T extends Table, D>(String type, TableInfo<T, D> table, String titleCol, {bool softDelete = true}) async {
      final ids = byType[type];
      if (ids == null) return;
      final cols = softDelete ? 'id, $titleCol AS title, deleted_at' : 'id, $titleCol AS title, NULL AS deleted_at';
      final rows = await _db.customSelect(
        'SELECT $cols FROM ${table.actualTableName} WHERE id IN (${List.filled(ids.length, '?').join(',')})',
        variables: [for (final id in ids) Variable.withString(id)],
      ).get();
      for (final r in rows) {
        titles['$type:${r.read<String>('id')}'] = (r.read<String>('title'), r.data['deleted_at'] != null);
      }
    }

    await load(LinkType.product, _db.products, 'name');
    await load(LinkType.customer, _db.customers, 'name');
    await load(LinkType.supplier, _db.suppliers, 'name');
    await load(LinkType.transaction, _db.transactions, 'number');
    await load(LinkType.contentIdea, _db.contentIdeas, 'title');
    await load(LinkType.watchlistItem, _db.watchlistItems, 'title');
    return [
      for (final l in links)
        if (titles['${l.entityType}:${l.entityId}'] case final t?)
          LinkedEntity(l.entityType, l.entityId, t.$1, missing: t.$2)
        else
          LinkedEntity(l.entityType, l.entityId, '(data sudah dihapus)', missing: true),
    ];
  }
}
