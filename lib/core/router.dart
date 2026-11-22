import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/change_pin_screen.dart';
import '../features/auth/lock_screen.dart';
import '../features/auth/setup_pin_screen.dart';
import '../features/business/business_home_screen.dart';
import '../features/content/content_home_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';

/// Rute utama berdasarkan status PIN:
///   needsSetup → /buat-pin, locked → /kunci, unlocked → 5 tab utama.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthStatus>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/beranda',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (refresh.value) {
        case AuthStatus.loading:
          return loc == '/memuat' ? null : '/memuat';
        case AuthStatus.needsSetup:
          return loc == '/buat-pin' ? null : '/buat-pin';
        case AuthStatus.locked:
          return loc == '/kunci' ? null : '/kunci';
        case AuthStatus.unlocked:
          const gates = {'/memuat', '/buat-pin', '/kunci'};
          return gates.contains(loc) ? '/beranda' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/memuat',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/buat-pin', builder: (_, _) => const SetupPinScreen()),
      GoRoute(path: '/kunci', builder: (_, _) => const LockScreen()),
      GoRoute(path: '/ubah-pin', builder: (_, _) => const ChangePinScreen()),
      GoRoute(path: '/backup', builder: (_, _) => const BackupScreen()),
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
