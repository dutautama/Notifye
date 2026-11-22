import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/business/business_home_screen.dart';
import '../screens/content/content_home_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/settings/change_password_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shell/main_shell.dart';

/// Rute utama.
/// - Belum login → selalu diarahkan ke /login.
/// - Sudah login → /login diarahkan ke /beranda.
/// - 5 tab bottom navigation memakai StatefulShellRoute (state tiap tab terjaga).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _StreamListenable(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/beranda',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/beranda';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/ganti-password',
        builder: (_, _) => const ChangePasswordScreen(),
      ),
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

/// Mengubah Stream menjadi Listenable agar GoRouter menjalankan ulang redirect.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
