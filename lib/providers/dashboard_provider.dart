import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_summary.dart';
import '../services/dashboard_service.dart';
import 'auth_provider.dart';

final dashboardServiceProvider =
    Provider<DashboardService>((ref) => DashboardService.instance());

/// Dimuat ulang otomatis saat user berganti; manual via ref.invalidate / pull-to-refresh.
final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(dashboardServiceProvider).load();
});
