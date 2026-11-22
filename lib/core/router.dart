import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/business/business_home_screen.dart';
import '../screens/content/content_home_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/main_shell.dart';

/// Rute utama. 5 tab bottom navigation memakai StatefulShellRoute
/// sehingga posisi scroll & state tiap tab tetap terjaga.
/// (Rute /login dan redirect autentikasi ditambahkan di Modul 1.)
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/beranda',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/beranda', builder: (_, _) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/usaha', builder: (_, _) => const BusinessHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/konten', builder: (_, _) => const ContentHomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/laporan', builder: (_, _) => const ReportsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/lainnya', builder: (_, _) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});
