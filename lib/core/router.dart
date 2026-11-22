import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/change_pin_screen.dart';
import '../features/auth/lock_screen.dart';
import '../features/auth/setup_pin_screen.dart';
import '../features/business/business_home_screen.dart';
import '../features/business/parties/party_form_screen.dart';
import '../features/business/parties/party_list_screen.dart';
import '../features/business/products/categories_screen.dart';
import '../features/business/products/product_form_screen.dart';
import '../features/business/products/product_list_screen.dart';
import '../features/business/transactions/debt_list_screen.dart';
import '../features/business/transactions/trx_detail_screen.dart';
import '../features/business/transactions/trx_form_screen.dart';
import '../features/business/transactions/trx_list_screen.dart';
import '../features/content/content_home_screen.dart';
import '../features/content/idea_detail_screen.dart';
import '../features/content/idea_form_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/notes/note_editor_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/settings/business_profile_screen.dart';
import '../features/settings/printer_screen.dart';
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
      GoRoute(path: '/profil-usaha', builder: (_, _) => const BusinessProfileScreen()),
      GoRoute(path: '/printer', builder: (_, _) => const PrinterScreen()),
      GoRoute(path: '/laporan', builder: (_, _) => const ReportsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/beranda', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/usaha',
                builder: (_, _) => const BusinessHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'produk',
                    builder: (_, _) => const ProductListScreen(),
                    routes: [
                      GoRoute(path: 'pilih', builder: (_, _) => const ProductListScreen(pickMode: true)),
                      GoRoute(
                        path: 'baru',
                        builder: (_, st) => ProductFormScreen(initialBarcode: st.extra as String?),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, st) => ProductFormScreen(productId: st.pathParameters['id']),
                      ),
                    ],
                  ),
                  GoRoute(path: 'kategori', builder: (_, _) => const CategoriesScreen()),
                  for (final kind in PartyKind.values)
                    GoRoute(
                      path: kind.path,
                      builder: (_, _) => PartyListScreen(kind: kind),
                      routes: [
                        GoRoute(
                          path: 'pilih',
                          builder: (_, _) => PartyListScreen(kind: kind, pickMode: true),
                        ),
                        GoRoute(
                          path: 'baru',
                          builder: (_, _) => PartyFormScreen(kind: kind),
                        ),
                        GoRoute(
                          path: ':id',
                          builder: (_, st) => PartyFormScreen(kind: kind, partyId: st.pathParameters['id']),
                        ),
                      ],
                    ),
                  GoRoute(
                    path: 'transaksi',
                    builder: (_, _) => const TrxListScreen(),
                    routes: [
                      GoRoute(
                        path: 'baru',
                        builder: (_, st) =>
                            TrxFormScreen(type: st.uri.queryParameters['jenis'] == 'purchase' ? 'purchase' : 'sale'),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, st) => TrxDetailScreen(transactionId: st.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(path: 'hutang-piutang', builder: (_, _) => const DebtListScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/konten',
                builder: (_, _) => const ContentHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'ide/baru',
                    builder: (_, st) => IdeaFormScreen(initialStatus: st.uri.queryParameters['status']),
                  ),
                  GoRoute(
                    path: 'ide/:id',
                    builder: (_, st) => IdeaDetailScreen(ideaId: st.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'ubah',
                        builder: (_, st) => IdeaFormScreen(ideaId: st.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catatan',
                builder: (_, _) => const NotesScreen(),
                routes: [
                  GoRoute(
                    path: 'baru',
                    builder: (_, st) => NoteEditorScreen(
                      linkType: st.uri.queryParameters['type'],
                      linkId: st.uri.queryParameters['id'],
                    ),
                  ),
                  GoRoute(path: ':id', builder: (_, st) => NoteEditorScreen(noteId: st.pathParameters['id'])),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/lainnya', builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
    ],
  );
});
