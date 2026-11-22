import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/catatan_repository.dart';
import 'package:usahakonten/features/notes/markdown_text.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('markdown', () {
    test('wrap tebal dengan & tanpa seleksi', () {
      final v = MarkdownText.wrap(
          const TextEditingValue(text: 'halo dunia', selection: TextSelection(baseOffset: 5, extentOffset: 10)), '**');
      expect(v.text, 'halo **dunia**');
      final e = MarkdownText.wrap(const TextEditingValue(text: 'ab', selection: TextSelection.collapsed(offset: 1)), '_');
      expect(e.text, 'a__b');
      expect(e.selection.baseOffset, 2);
    });

    test('toggle awalan baris (checklist/bullet) bolak-balik', () {
      const v = TextEditingValue(text: 'satu\ndua\ntiga', selection: TextSelection(baseOffset: 0, extentOffset: 8));
      final on = MarkdownText.togglePrefix(v, '- [ ] ');
      expect(on.text, '- [ ] satu\n- [ ] dua\ntiga');
      final off = MarkdownText.togglePrefix(on.copyWith(selection: const TextSelection(baseOffset: 0, extentOffset: 18)), '- [ ] ');
      expect(off.text, 'satu\ndua\ntiga');
      final bullet = MarkdownText.togglePrefix(
          const TextEditingValue(text: '- [x] beli', selection: TextSelection.collapsed(offset: 3)), '- ');
      expect(bullet.text, '- beli', reason: 'awalan daftar lain diganti, bukan ditumpuk');
    });

    test('centang checkbox & progres', () {
      const body = '# Belanja\n- [ ] gula\n  - [x] kopi\nbiasa';
      final t = MarkdownText.toggleCheckbox(body, 1);
      expect(t.split('\n')[1], '- [x] gula');
      expect(MarkdownText.toggleCheckbox(t, 2).split('\n')[2], '  - [ ] kopi');
      expect(MarkdownText.toggleCheckbox(body, 3), body, reason: 'baris biasa tidak berubah');
      expect(MarkdownText.checklistProgress(t), (2, 2));
    });

    test('teks share & pratinjau', () {
      final s = MarkdownText.toShareText('Belanja', '## Pasar\n- [x] **gula** aren\n- [ ] _kopi_\n- susu');
      expect(s, 'Belanja\n\nPasar\n☑ gula aren\n☐ kopi\n• susu');
      expect(MarkdownText.preview('a' * 200).length, 141);
    });
  });

  group('query FTS aman', () {
    test('kata → "kata"* AND, karakter khusus dibuang', () {
      expect(buildFtsQuery('kopi susu'), '"kopi"* "susu"*');
      expect(buildFtsQuery('  '), isNull);
      expect(buildFtsQuery('" OR 1=1 --'), '"OR"* "1"* "1"*');
      expect(buildFtsQuery('NEAR(a b) * ^'), '"NEAR"* "a"* "b"*');
    });

    test('normalisasi tag', () {
      expect(normalizeTag('  #Ide Konten '), 'ide-konten');
      expect(normalizeTag('#'), isNull);
    });
  });

  group('repository', () {
    late AppDatabase db;
    late CatatanRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = CatatanRepository(db);
    });
    tearDown(() => db.close());

    Future<List<String>> titles({String search = '', String? tag, String? category, bool archived = false}) async =>
        (await repo.watchNotes(search: search, tag: tag, category: category, archived: archived).first)
            .map((r) => r.note.title)
            .toList();

    test('urutan sematan, arsip, hapus, pencarian (termasuk tanpa aksen & awalan kata)', () async {
      final a = await repo.createNote(title: 'Resep Kópi', body: 'gula aren', category: 'Referensi');
      final b = await repo.createNote(title: 'Ide video', body: 'review buku atomic habits');
      final c = await repo.createNote(title: 'Lama', body: 'arsip');
      await repo.setPinned(a, true);
      await repo.setArchived(c, true);
      expect(await titles(), ['Resep Kópi', 'Ide video']);
      expect(await titles(archived: true), ['Lama']);
      expect(await titles(search: 'kopi'), ['Resep Kópi'], reason: 'remove_diacritics');
      expect(await titles(search: 'atom hab'), ['Ide video'], reason: 'awalan kata, AND');
      expect(await titles(search: '" OR 1=1'), isEmpty, reason: 'input aneh tidak error');
      expect(await titles(category: 'Referensi'), ['Resep Kópi']);
      await repo.softDelete(b);
      expect(await titles(search: 'review'), isEmpty, reason: 'catatan terhapus tidak muncul');
      await repo.updateNote(a, body: 'teh melati');
      expect(await titles(search: 'gula'), isEmpty);
      expect(await titles(search: 'melati'), ['Resep Kópi']);
    });

    test('tag: normalisasi, tanpa duplikat, filter & hitungan', () async {
      final a = await repo.createNote(title: 'A');
      final b = await repo.createNote(title: 'B');
      await repo.setTags(a, ['#Ide', 'ide', 'Konten Pendek']);
      await repo.setTags(b, ['ide']);
      expect(await repo.watchTags(a).first, ['ide', 'konten-pendek']);
      expect(await titles(tag: 'konten-pendek'), ['A']);
      expect(await repo.watchAllTags().first, [('ide', 2), ('konten-pendek', 1)]);
      final rows = await repo.watchNotes().first;
      expect(rows.firstWhere((r) => r.note.id == a).tags, ['ide', 'konten-pendek']);
    });

    test('tautan: buat catatan tertaut, judul entitas, entitas terhapus', () async {
      final p = await db.into(db.products).insertReturning(ProductsCompanion.insert(name: 'Kaos'));
      final c = await db.into(db.customers).insertReturning(CustomersCompanion.insert(name: 'Budi'));
      final n = await repo.createNote(title: 'Catatan ukuran', linkType: LinkType.product, linkId: p.id);
      await repo.link(n, LinkType.customer, c.id);
      await repo.link(n, LinkType.customer, c.id); // idempoten
      expect((await repo.watchNotesFor(LinkType.product, p.id).first).single.id, n);
      final resolved = await repo.resolveLinks(await repo.watchLinks(n).first);
      expect(resolved.map((e) => e.title).toSet(), {'Kaos', 'Budi'});
      await (db.update(db.customers)..where((x) => x.id.equals(c.id))).write(CustomersCompanion(deletedAt: Value(DateTime.now())));
      final after = await repo.resolveLinks(await repo.watchLinks(n).first);
      expect(after.firstWhere((e) => e.type == LinkType.customer).missing, isTrue);
      expect(() => repo.link(n, 'hacker', 'x'), throwsArgumentError);
      await repo.unlink(n, LinkType.product, p.id);
      expect(await repo.watchNotesFor(LinkType.product, p.id).first, isEmpty);
    });
  });
}
