import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/catatan_repository.dart';
import '../data/repositories/hutang_repository.dart';
import '../data/repositories/invoice_repository.dart';
import '../data/repositories/koleksi_repository.dart';
import '../data/repositories/meta_repository.dart';
import '../data/repositories/konten_repository.dart';
import '../data/repositories/pelanggan_repository.dart';
import '../data/repositories/produk_repository.dart';
import '../data/repositories/transaksi_repository.dart';
import '../features/auth/pin_service.dart';
import '../services/backup/backup_service.dart';
import '../services/documents/invoice_signature.dart';
import '../services/printer_service.dart';
import '../services/report_service.dart';

/// Satu koneksi database untuk seluruh aplikasi.
/// Di test, override dengan AppDatabase(NativeDatabase.memory()).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final produkRepositoryProvider = Provider((ref) => ProdukRepository(ref.watch(databaseProvider)));
final pelangganRepositoryProvider = Provider((ref) => PelangganRepository(ref.watch(databaseProvider)));
final invoiceRepositoryProvider = Provider((ref) => InvoiceRepository(ref.watch(databaseProvider)));
final transaksiRepositoryProvider = Provider(
  (ref) => TransaksiRepository(ref.watch(databaseProvider), ref.watch(invoiceRepositoryProvider)),
);
final hutangRepositoryProvider = Provider((ref) => HutangRepository(ref.watch(databaseProvider)));
final kontenRepositoryProvider = Provider((ref) => KontenRepository(ref.watch(databaseProvider)));

final pinServiceProvider = Provider<PinService>((ref) => PinService());

final metaRepositoryProvider = Provider((ref) => MetaRepository(ref.watch(databaseProvider)));

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider), ref.watch(metaRepositoryProvider)),
);

final printerServiceProvider = Provider((ref) => PrinterService(ref.watch(metaRepositoryProvider)));

final reportServiceProvider = Provider(
  (ref) => ReportService(
    transaksi: ref.watch(transaksiRepositoryProvider),
    produk: ref.watch(produkRepositoryProvider),
    hutang: ref.watch(hutangRepositoryProvider),
    konten: ref.watch(kontenRepositoryProvider),
    invoice: ref.watch(invoiceRepositoryProvider),
  ),
);

final catatanRepositoryProvider = Provider((ref) => CatatanRepository(ref.watch(databaseProvider)));

final koleksiRepositoryProvider = Provider((ref) => KoleksiRepository(ref.watch(databaseProvider)));

final invoiceSignerProvider = Provider((ref) => InvoiceSigner(ref.watch(metaRepositoryProvider)));
