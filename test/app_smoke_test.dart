import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:usahakonten/app.dart';
import 'package:usahakonten/core/router.dart';
import 'package:usahakonten/data/database/app_database.dart';
import 'package:usahakonten/data/repositories/invoice_repository.dart';
import 'package:usahakonten/data/repositories/transaksi_repository.dart';
import 'package:usahakonten/features/auth/auth_controller.dart';
import 'package:usahakonten/features/collection/share_intent_listener.dart';
import 'package:usahakonten/providers/app_providers.dart';

class _UnlockedAuth extends AuthController {
  @override
  AuthStatus build() => AuthStatus.unlocked;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('semua layar utama tampil tanpa error di ukuran HP', timeout: const Timeout(Duration(minutes: 3)), (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    late String productId, trxId, ideaId, customerId, noteId, itemId;
    await tester.runAsync(() async {
      productId = newId();
      await db.into(db.products).insert(ProductsCompanion.insert(
          id: Value(productId), name: 'Kaos Sablon Premium Lengan Panjang Warna Hitam', kind: const Value('barang'),
          trackStock: const Value(true), stock: const Value(3), minStock: const Value(5), sellPrice: const Value(125000)));
      final c = await db.into(db.customers).insertReturning(
          CustomersCompanion.insert(name: 'Budi Santoso', phone: const Value('081234567890')));
      customerId = c.id;
      final t = await TransaksiRepository(db, InvoiceRepository(db)).createTransaction(TrxInput(
          type: 'sale', customerId: c.id, dueDate: DateTime.now().add(const Duration(days: 2)),
          initialPayment: 50000, items: [TrxItemInput(productId: productId, name: 'Kaos', qty: 2, price: 125000)]));
      trxId = t.id;
      final idea = await db.into(db.contentIdeas).insertReturning(ContentIdeasCompanion.insert(
          title: 'Tips memilih kaos sablon yang awet untuk komunitas', platforms: const Value('["instagram","tiktok"]'),
          description: const Value('Hook: 3 kesalahan saat pesan kaos.')));
      ideaId = idea.id;
      await db.into(db.contentProductLinks).insert(ContentProductLinksCompanion.insert(ideaId: idea.id, productId: productId));
      await db.into(db.contentAssets).insert(ContentAssetsCompanion.insert(
          ideaId: idea.id, title: 'Folder Drive', url: const Value('https://drive.google.com/x')));
      final s = await db.into(db.contentSchedules).insertReturning(ContentSchedulesCompanion.insert(
          ideaId: idea.id, platform: 'instagram', scheduledAt: DateTime.now().add(const Duration(hours: 5))));
      final note = await db.into(db.notes).insertReturning(NotesCompanion.insert(
          title: const Value('Catatan ukuran kaos pelanggan'), body: const Value('## Ukuran\n- [ ] L\n- [x] **XL**'),
          isPinned: const Value(true)));
      noteId = note.id;
      final item = await db.into(db.watchlistItems).insertReturning(WatchlistItemsCompanion.insert(
          title: 'Atomic Habits — kebiasaan kecil hasil besar', type: const Value('buku'), status: const Value('sedang'),
          creator: const Value('James Clear'), progress: const Value(120), progressTotal: const Value(320),
          rating: const Value(5), url: const Value('https://example.com/buku')));
      itemId = item.id;
      await db.into(db.watchlistItemIdeas).insert(WatchlistItemIdeasCompanion.insert(itemId: item.id, ideaId: idea.id));
      await db.into(db.noteTags).insert(NoteTagsCompanion.insert(noteId: note.id, tag: 'pelanggan'));
      await db.into(db.noteLinks).insert(NoteLinksCompanion.insert(noteId: note.id, entityType: 'product', entityId: productId));
      await db.into(db.contentPublications).insert(ContentPublicationsCompanion.insert(
          ideaId: idea.id, scheduleId: Value(s.id), platform: 'tiktok', reach: const Value(12000), likes: const Value(900)));
    });

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      authControllerProvider.overrideWith(_UnlockedAuth.new),
      shareIntentEnabledProvider.overrideWithValue(false),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const UsahaKontenApp()));

    Future<void> visit(String path, String expectText) async {
      container.read(routerProvider).go(path);
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: 'error di $path');
      expect(find.textContaining(expectText).evaluate().isNotEmpty, isTrue, reason: '"$expectText" tidak tampil di $path');
    }

    final orig = FlutterError.onError;
    FlutterError.onError = (d) {
      // ignore: avoid_print
      print('DBG ${d.toString().split('\n').where((l) => l.contains('lib/') || l.contains('overflowed') || l.contains('creator')).take(12).join('\n')}');
      orig?.call(d);
    };
    await visit('/beranda', 'Omzet hari ini');
    await visit('/usaha', 'Piutang');
    await visit('/usaha/produk', 'Kaos Sablon');
    await visit('/usaha/produk/baru', 'Produk/jasa baru');
    await visit('/usaha/produk/$productId', 'Ubah produk/jasa');
    await visit('/usaha/kategori', 'Kategori');
    await visit('/usaha/pelanggan', 'Budi Santoso');
    await visit('/usaha/pelanggan/$customerId', 'WhatsApp');
    await visit('/usaha/supplier/baru', 'Supplier baru');
    await visit('/usaha/transaksi', 'INV-');
    await visit('/usaha/transaksi/baru?jenis=sale', 'Penjualan baru');
    await visit('/usaha/transaksi/baru?jenis=purchase', 'Pembelian baru');
    await visit('/usaha/transaksi/$trxId', 'Catat bayar');
    await visit('/usaha/hutang-piutang', 'Budi Santoso');
    await visit('/konten', 'Ide (0)');
    await visit('/konten/ide/baru', 'Ide konten baru');
    await visit('/konten/ide/$ideaId', 'Produk/jasa yang dipromosikan');
    await visit('/konten/ide/$ideaId/ubah', 'Ubah ide konten');
    await visit('/laporan', 'Omzet');
    await visit('/catatan', 'Catatan ukuran kaos');
    await visit('/catatan/baru', 'Kategori');
    await visit('/catatan/$noteId', 'XL');
    await visit('/pengaturan', 'Profil Usaha');
    await visit('/koleksi', 'Atomic Habits');
    await visit('/koleksi/$itemId', 'Rating');
    await visit('/koleksi/baru', 'Tambah ke Koleksi');
    await visit('/koleksi/$itemId/ubah', 'Ubah item');
    await visit('/profil-usaha', 'Nama usaha');
    await visit('/printer', 'Lebar kertas');
    await visit('/tanda-tangan', 'Tampilkan QR tanda tangan');
    await visit('/verifikasi-invoice', 'Pindai QR invoice');
    await visit('/ubah-pin', 'PIN lama');

    // Tab kalender & publikasi di halaman konten.
    await visit('/konten', 'Ide (0)');
    await tester.tap(find.text('Kalender'));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Tips memilih'), findsWidgets);
    await tester.tap(find.text('Publikasi').first);
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.textContaining('reach'), findsWidgets);

    // Putaran 2: ukuran font HP diperbesar 130%.
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await visit('/beranda', 'Omzet hari ini');
    await visit('/usaha', 'Piutang');
    await visit('/usaha/produk/baru', 'Produk/jasa baru');
    await visit('/usaha/transaksi/baru?jenis=sale', 'Penjualan baru');
    await visit('/usaha/transaksi/$trxId', 'Catat bayar');
    await visit('/usaha/hutang-piutang', 'Budi Santoso');
    await visit('/konten/ide/$ideaId', 'Produk/jasa yang dipromosikan');
    await visit('/laporan', 'Omzet');
    await visit('/catatan', 'Catatan ukuran kaos');
    await visit('/catatan/$noteId', 'XL');
    await visit('/pengaturan', 'Profil Usaha');
    await visit('/koleksi', 'Atomic Habits');
    await visit('/koleksi/$itemId', 'Rating');
    // Lepas widget & provider dulu agar stream drift berhenti, baru tutup database.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => db.close().timeout(const Duration(seconds: 5), onTimeout: () {}));
  });
}
