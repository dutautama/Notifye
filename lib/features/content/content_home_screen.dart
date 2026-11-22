import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/konten_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/month_calendar.dart';
import 'content_labels.dart';

class ContentHomeScreen extends StatelessWidget {
  const ContentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konten'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Papan'),
              Tab(text: 'Kalender'),
              Tab(text: 'Publikasi'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/konten/ide/baru'),
          icon: const Icon(Icons.add),
          label: const Text('Ide baru'),
        ),
        body: const TabBarView(children: [_Board(), _CalendarTab(), _PublicationsTab()]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Papan
class _Board extends ConsumerWidget {
  const _Board();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<List<ContentIdea>>(
      stream: repo.watchIdeas(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final ideas = snap.data!;
        final width = MediaQuery.sizeOf(context).width;
        final colWidth = width < 500 ? width * 0.82 : 300.0;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 88),
          children: [
            for (final status in KontenRepository.statuses)
              SizedBox(
                width: colWidth,
                child: _Column(
                  status: status,
                  ideas: ideas.where((i) => i.status == status).toList()
                    ..sort(
                      (a, b) => a.priority != b.priority
                          ? a.priority.compareTo(b.priority)
                          : b.updatedAt.compareTo(a.updatedAt),
                    ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Column extends ConsumerWidget {
  const _Column({required this.status, required this.ideas});
  final String status;
  final List<ContentIdea> ideas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = ideaStatusColor(status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: color, width: 4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ideaStatusLabels[status]} (${ideas.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                IconButton(
                  tooltip: 'Tambah di ${ideaStatusLabels[status]}',
                  icon: const Icon(Icons.add),
                  onPressed: () => context.push('/konten/ide/baru?status=$status'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ideas.isEmpty
                ? const Center(child: Text('Kosong'))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [for (final i in ideas) _IdeaCard(idea: i)],
                  ),
          ),
        ],
      ),
    );
  }
}

class _IdeaCard extends ConsumerWidget {
  const _IdeaCard({required this.idea});
  final ContentIdea idea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = KontenRepository.decodeList(idea.platforms);
    final statuses = KontenRepository.statuses;
    final idx = statuses.indexOf(idea.status);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surface,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/konten/ide/${idea.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (idea.priority == 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.priority_high, size: 16, color: scheme.error),
                          ),
                        Expanded(
                          child: Text(
                            idea.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (platforms.isNotEmpty || idea.dueDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (platforms.isNotEmpty) platforms.map(platformLabel).join(', '),
                          if (idea.dueDate != null) 'Target ${Fmt.date(idea.dueDate)}',
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Pindahkan',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (s) => ref.read(kontenRepositoryProvider).setStatus(idea.id, s),
                itemBuilder: (_) => [
                  for (final s in statuses)
                    if (s != idea.status)
                      PopupMenuItem(
                        value: s,
                        child: Text('${statuses.indexOf(s) > idx ? 'Maju' : 'Kembali'} ke ${ideaStatusLabels[s]}'),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- Kalender
class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  DateTime _focused = dateOnly(DateTime.now());
  DateTime _selected = dateOnly(DateTime.now());
  bool _weekMode = false;
  late Stream<List<ScheduleWithIdea>> _stream = _make();

  Stream<List<ScheduleWithIdea>> _make() {
    // Ambil seluruh grid yang terlihat (maks. 6 minggu) + cadangan.
    final start = gridStartForMonth(_focused).subtract(const Duration(days: 7));
    final end = start.add(const Duration(days: 56));
    return ref.read(kontenRepositoryProvider).watchSchedulesBetween(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScheduleWithIdea>>(
      stream: _stream,
      builder: (context, snap) {
        final byDay = <DateTime, List<ScheduleWithIdea>>{};
        for (final s in snap.data ?? const <ScheduleWithIdea>[]) {
          byDay.putIfAbsent(dateOnly(s.schedule.scheduledAt), () => []).add(s);
        }
        final dayItems = byDay[dateOnly(_selected)] ?? const <ScheduleWithIdea>[];
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            MonthCalendar(
              focused: _focused,
              selected: _selected,
              weekMode: _weekMode,
              eventCount: (d) => byDay[dateOnly(d)]?.length ?? 0,
              onSelect: (d) => setState(() {
                _selected = d;
                if (d.month != _focused.month) {
                  _focused = d;
                  _stream = _make();
                }
              }),
              onFocusChange: (d) => setState(() {
                _focused = d;
                _selected = d;
                _stream = _make();
              }),
              onModeChange: (w) => setState(() => _weekMode = w),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(Fmt.date(_selected), style: Theme.of(context).textTheme.titleSmall),
            ),
            if (dayItems.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tidak ada jadwal. Tambahkan jadwal tayang dari halaman ide konten.'),
              ),
            for (final s in dayItems)
              ListTile(
                leading: Icon(
                  s.schedule.status == 'tayang'
                      ? Icons.check_circle
                      : s.schedule.status == 'batal'
                      ? Icons.cancel_outlined
                      : Icons.schedule,
                  color: s.schedule.status == 'tayang' ? Colors.green.shade700 : null,
                ),
                title: Text(s.ideaTitle),
                subtitle: Text(
                  '${platformLabel(s.schedule.platform)} • '
                  '${Fmt.dateTime(s.schedule.scheduledAt).split(', ').last} • '
                  '${scheduleStatusLabels[s.schedule.status]}',
                ),
                onTap: () => context.push('/konten/ide/${s.schedule.ideaId}'),
              ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------- Publikasi
class _PublicationsTab extends ConsumerWidget {
  const _PublicationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<PublicationWithIdea>>(
      stream: ref.watch(kontenRepositoryProvider).watchAllPublications(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Belum ada publikasi.\nCatat link postingan & angka reach dari halaman ide konten.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final reach = list.fold<int>(0, (s, p) => s + p.publication.reach);
        final eng = list.fold<int>(
          0,
          (s, p) => s + p.publication.likes + p.publication.comments + p.publication.shares + p.publication.saves,
        );
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${list.length} publikasi • reach ${Fmt.compact(reach)} • '
                'engagement ${Fmt.compact(eng)}${reach > 0 ? ' (ER ${(eng * 100 / reach).toStringAsFixed(1)}%)' : ''}',
              ),
            ),
            for (final p in list)
              ListTile(
                leading: CircleAvatar(child: Text(platformLabel(p.publication.platform).characters.first)),
                title: Text(p.ideaTitle),
                subtitle: Text(
                  '${platformLabel(p.publication.platform)} • ${Fmt.date(p.publication.publishedAt)}\n'
                  'Views ${Fmt.compact(p.publication.views)} • Reach ${Fmt.compact(p.publication.reach)} • '
                  'Like ${Fmt.compact(p.publication.likes)}',
                ),
                isThreeLine: true,
                onTap: () => context.push('/konten/ide/${p.publication.ideaId}'),
              ),
          ],
        );
      },
    );
  }
}
