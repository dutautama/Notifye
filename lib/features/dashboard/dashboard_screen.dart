import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/repositories/hutang_repository.dart';
import '../../models/dashboard_summary.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/whatsapp_service.dart';
import '../../widgets/error_view.dart';
import '../collection/collection_screen.dart';
import '../notes/markdown_text.dart';
import '../../widgets/mini_bar_chart.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/two_column_grid.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    Future<void> refresh() => ref.refresh(dashboardProvider.future);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Laporan',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () => context.push('/laporan'),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/pengaturan'),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: async.when(
          // Saat refresh, tetap tampilkan data lama (skipLoadingOnRefresh default).
          data: (s) => _DashboardBody(summary: s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('$_greeting 👋', style: text.titleMedium),
        Text(Fmt.date(DateTime.now()), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        // --- KPI ---------------------------------------------------------
        TwoColumnGrid(
          children: [
            StatCard(
              label: 'Laba hari ini',
              value: Fmt.rupiah(s.profitToday),
              caption: 'Omzet ${Fmt.rupiah(s.salesToday)} • ${s.trxCountToday} trx',
              icon: Icons.today,
              color: s.profitToday < 0 ? Theme.of(context).colorScheme.error : null,
            ),
            StatCard(
              label: 'Laba bulan ini',
              value: Fmt.rupiah(s.profitThisMonth),
              caption: 'Omzet ${Fmt.rupiah(s.salesThisMonth)} • ${s.trxCountThisMonth} trx',
              icon: Icons.calendar_month,
              color: s.profitThisMonth < 0 ? Theme.of(context).colorScheme.error : null,
            ),
            StatCard(
              label: 'Piutang',
              value: Fmt.rupiah(s.receivableTotal),
              caption: '${s.receivableCount} belum lunas',
              icon: Icons.call_received,
              color: Colors.orange.shade700,
            ),
            StatCard(
              label: 'Hutang',
              value: Fmt.rupiah(s.payableTotal),
              caption: '${s.payableCount} belum lunas',
              icon: Icons.call_made,
              color: scheme.error,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // --- Grafik 7 hari ------------------------------------------------
        SectionCard(
          title: 'Laba 7 hari terakhir',
          icon: Icons.show_chart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: MiniBarChart(data: s.last7Days),
          ),
        ),
        const SizedBox(height: 12),

        // --- Jatuh tempo --------------------------------------------------
        SectionCard(
          title: 'Jatuh tempo (≤ 7 hari)',
          icon: Icons.alarm,
          child: s.dueDebts.isEmpty
              ? const EmptyHint('Tidak ada hutang/piutang yang jatuh tempo.')
              : Column(
                  children: [for (final d in s.dueDebts.take(5)) _DebtTile(debt: d, today: s.today)],
                ),
        ),
        const SizedBox(height: 12),

        // --- Stok menipis -------------------------------------------------
        SectionCard(
          title: 'Stok menipis',
          icon: Icons.inventory_2_outlined,
          child: s.lowStock.isEmpty
              ? const EmptyHint('Semua stok aman.')
              : Column(
                  children: [
                    for (final p in s.lowStock.take(5))
                      ListTile(
                        dense: true,
                        title: Text(p.name),
                        subtitle: Text('Minimal ${Fmt.number(p.minStock)} ${p.unit}'),
                        trailing: Text(
                          '${Fmt.number(p.stock)} ${p.unit}',
                          style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // --- Konten -------------------------------------------------------
        SectionCard(
          title: 'Sedang dibaca / ditonton',
          icon: Icons.collections_bookmark_outlined,
          trailing: TextButton(onPressed: () => context.go('/koleksi'), child: const Text('Lihat')),
          child: s.inProgress.isEmpty
              ? const EmptyHint('Belum ada. Ubah status item koleksi menjadi "Sedang".')
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(children: [for (final w in s.inProgress) WatchlistItemCard(item: w, compact: true)]),
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Catatan terbaru',
          icon: Icons.sticky_note_2_outlined,
          trailing: IconButton(
            tooltip: 'Catatan baru',
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/catatan/baru'),
          ),
          child: s.recentNotes.isEmpty
              ? const EmptyHint('Belum ada catatan.')
              : Column(children: [
                  for (final n in s.recentNotes)
                    ListTile(
                      dense: true,
                      leading: Icon(n.isPinned ? Icons.push_pin : Icons.notes, size: 20),
                      title: Text(n.title.trim().isEmpty ? '(tanpa judul)' : n.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(MarkdownText.preview(n.body, maxChars: 80),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => context.push('/catatan/${n.id}'),
                    ),
                ]),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Jadwal konten 7 hari ke depan',
          icon: Icons.event_note,
          trailing: TextButton(onPressed: () => context.go('/konten'), child: const Text('Lihat')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in s.contentStatusCounts.entries)
                      Chip(visualDensity: VisualDensity.compact, label: Text('${_statusLabel(e.key)}: ${e.value}')),
                  ],
                ),
              ),
              if (s.upcomingSchedules.isEmpty)
                const EmptyHint('Belum ada jadwal tayang minggu ini.')
              else
                for (final sc in s.upcomingSchedules.take(5))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(sc.ideaTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${_platformLabel(sc.schedule.platform)} • ${Fmt.dateTime(sc.schedule.scheduledAt)}',
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(String s) => switch (s) {
    'ide' => 'Ide',
    'produksi' => 'Produksi',
    'review' => 'Review',
    'publish' => 'Publish',
    _ => s,
  };

  static String _platformLabel(String p) => switch (p) {
    'instagram' => 'Instagram',
    'tiktok' => 'TikTok',
    'youtube' => 'YouTube',
    'facebook' => 'Facebook',
    'x' => 'X',
    'threads' => 'Threads',
    _ => p,
  };
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({required this.debt, required this.today});
  final DebtRow debt;
  final DateTime today;

  Future<void> _remind(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final due = debt.dueDate == null ? '' : ' yang jatuh tempo ${Fmt.date(debt.dueDate)}';
    final msg =
        'Halo ${debt.partyName}, kami ingin mengingatkan tagihan '
        '${debt.number} sebesar ${Fmt.rupiah(debt.remaining)}$due. '
        'Terima kasih 🙏';
    final ok = await WhatsAppService.send(phone: debt.partyPhone, message: msg);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = debt.isOverdue(today);
    return ListTile(
      dense: true,
      leading: Icon(
        debt.isReceivable ? Icons.call_received : Icons.call_made,
        color: debt.isReceivable ? Colors.orange.shade700 : scheme.error,
      ),
      title: Text('${debt.partyName} • ${debt.number}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${debt.isReceivable ? 'Piutang' : 'Hutang'} • '
        '${overdue ? 'TERLAMBAT sejak' : 'jatuh tempo'} ${Fmt.date(debt.dueDate)}',
        style: overdue ? TextStyle(color: scheme.error) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Fmt.rupiah(debt.remaining), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (debt.isReceivable)
            IconButton(
              tooltip: 'Ingatkan via WhatsApp',
              icon: const Icon(Icons.chat_outlined),
              onPressed: () => _remind(context),
            ),
        ],
      ),
    );
  }
}
