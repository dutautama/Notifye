import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/koleksi_repository.dart';
import 'package:usahakonten/features/collection/shared_text.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('teks share dari aplikasi lain', () {
    test('Chrome: judul + link', () {
      final d = parseSharedText('Cara Menulis Hook yang Bikin Penasaran - Medium\nhttps://medium.com/@a/hook-123')!;
      expect(d.title, 'Cara Menulis Hook yang Bikin Penasaran - Medium');
      expect(d.url, 'https://medium.com/@a/hook-123');
      expect(d.type, 'artikel');
    });
    test('YouTube: hanya link → video/YouTube', () {
      final d = parseSharedText('https://youtu.be/dQw4w9WgXcQ?si=abc')!;
      expect(d.type, 'video');
      expect(d.platform, 'YouTube');
      expect(d.url, 'https://youtu.be/dQw4w9WgXcQ?si=abc');
      expect(d.title, startsWith('YouTube'));
    });
    test('Netflix, Spotify podcast, tanda baca di akhir link', () {
      expect(parseSharedText('Tonton ini https://www.netflix.com/title/81234567.')!.type, 'film');
      expect(parseSharedText('Tonton ini https://www.netflix.com/title/81234567.')!.url, 'https://www.netflix.com/title/81234567');
      final p = parseSharedText('Episode bagus: https://open.spotify.com/episode/xyz')!;
      expect((p.type, p.platform), ('podcast', 'Spotify'));
      expect(p.title, 'Episode bagus');
    });
    test('teks tanpa link & teks kosong', () {
      final d = parseSharedText('Buku Filosofi Teras')!;
      expect((d.title, d.url, d.type), ('Buku Filosofi Teras', null, 'lainnya'));
      expect(parseSharedText('   '), isNull);
    });
  });

  group('aturan status & progress', () {
    final now = DateTime(2026, 11, 22, 15);
    test('tanggal otomatis', () {
      expect(applyStatusDates('sedang', null, null, now), (DateTime(2026, 11, 22), null));
      expect(applyStatusDates('selesai', DateTime(2026, 11, 1), null, now), (DateTime(2026, 11, 1), DateTime(2026, 11, 22)));
      expect(applyStatusDates('ingin', DateTime(2026, 11, 1), DateTime(2026, 11, 2), now), (null, null));
      expect(applyStatusDates('ditunda', DateTime(2026, 11, 1), null, now), (DateTime(2026, 11, 1), null));
    });
    test('batas progress', () {
      expect(clampProgress(-3, 10), 0);
      expect(clampProgress(15, 10), 10);
      expect(clampProgress(15, null), 15);
    });
  });

  group('repository', () {
    late AppDatabase db;
    late KoleksiRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = KoleksiRepository(db);
    });
    tearDown(() => db.close());

    test('progress: ingin → sedang → selesai otomatis', () async {
      final id = await repo.save(WatchlistItemsCompanion.insert(
          title: 'Serial X', type: const Value('serial'), progressTotal: const Value(3)));
      await repo.addProgress(id, 1);
      var i = (await repo.getItem(id))!;
      expect((i.status, i.progress), ('sedang', 1));
      expect(i.startedAt, isNotNull);
      await repo.addProgress(id, 5);
      i = (await repo.getItem(id))!;
      expect((i.status, i.progress), ('selesai', 3));
      expect(i.finishedAt, isNotNull);
    });

    test('urutan daftar (sedang dulu), filter, statistik', () async {
      await repo.save(WatchlistItemsCompanion.insert(title: 'A', type: const Value('buku')));
      final b = await repo.save(WatchlistItemsCompanion.insert(title: 'B', type: const Value('film')));
      final c = await repo.save(WatchlistItemsCompanion.insert(title: 'C', type: const Value('buku')));
      await repo.setStatus(b, 'sedang');
      await repo.setStatus(c, 'selesai');
      await repo.setRating(c, 4);
      final d = await repo.save(WatchlistItemsCompanion.insert(title: 'D', rating: const Value(2)));
      expect((await repo.watchItems().first).first.title, 'B');
      expect((await repo.watchItems(type: 'buku').first).map((e) => e.title).toSet(), {'A', 'C'});
      expect((await repo.watchItems(status: 'selesai').first).single.title, 'C');
      expect((await repo.watchItems(search: 'd').first).single.id, d);
      final s = await repo.watchStats().first;
      expect(s.byStatus, {'ingin': 2, 'sedang': 1, 'selesai': 1, 'ditunda': 0, 'drop': 0});
      expect(s.finishedThisMonth, 1);
      expect(s.averageRating, 3);
      expect((await repo.inProgress()).single.title, 'B');
      await repo.softDelete(b);
      expect(await repo.inProgress(), isEmpty);
    });

    test('rating di luar 1–5 ditolak database', () async {
      expect(() => repo.save(WatchlistItemsCompanion.insert(title: 'X', rating: const Value(6))),
          throwsA(isA<Exception>()));
    });

    test('relasi item ↔ ide konten dua arah', () async {
      final item = await repo.save(WatchlistItemsCompanion.insert(title: 'Atomic Habits'));
      final idea = await db.into(db.contentIdeas).insertReturning(ContentIdeasCompanion.insert(title: 'Review buku'));
      await repo.linkIdea(item, idea.id);
      await repo.linkIdea(item, idea.id);
      expect((await repo.watchIdeasFor(item).first).single.title, 'Review buku');
      expect((await repo.watchItemsForIdea(idea.id).first).single.title, 'Atomic Habits');
      await repo.unlinkIdea(item, idea.id);
      expect(await repo.watchIdeasFor(item).first, isEmpty);
    });
  });
}
