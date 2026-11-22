import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';
import 'app_providers.dart';

final dashboardServiceProvider = Provider<DashboardService>(
  (ref) => DashboardService(
    transaksi: ref.watch(transaksiRepositoryProvider),
    hutang: ref.watch(hutangRepositoryProvider),
    produk: ref.watch(produkRepositoryProvider),
    konten: ref.watch(kontenRepositoryProvider),
  ),
);

/// Beranda otomatis dimuat ulang setiap kali ada perubahan di database.
final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final sub = db.tableUpdates().listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(dashboardServiceProvider).load();
});
