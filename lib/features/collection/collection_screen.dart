import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/koleksi_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/attachment_image.dart';
import 'collection_labels.dart';

const _tabs = [null, 'buku', 'artikel', 'video', 'film', 'serial', 'podcast', 'lainnya'];

/// Koleksi bacaan & tontonan: tab per jenis + filter status + statistik.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String? _status;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Koleksi'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in _tabs) Tab(text: t == null ? 'Semua' : watchlistTypeLabels[t]!.$1)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/koleksi/baru'),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),
        ),
        body: Column(children: [
          _StatsBar(selected: _status, onSelect: (s) => setState(() => _status = s)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                  hintText: 'Cari judul, penulis, platform', prefixIcon: Icon(Icons.search), isDense: true),
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final t in _tabs) _ItemList(type: t, status: _status, search: _search),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatsBar extends ConsumerWidget {
  const _StatsBar({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<KoleksiStats>(
      stream: ref.watch(koleksiRepositoryProvider).watchStats(),
      builder: (context, snap) {
        final s = snap.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final st in [null, ...watchlistStatuses])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(st == null
                          ? 'Semua${s == null ? '' : ' (${s.total})'}'
                          : '${watchlistStatusLabels[st]}${s == null ? '' : ' (${s.byStatus[st] ?? 0})'}'),
                      selected: selected == st,
                      onSelected: (_) => onSelect(st),
                    ),
                  ),
              ],
            ),
          ),
          if (s != null && s.total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Selesai bulan ini: ${s.finishedThisMonth}'
                '${s.averageRating == null ? '' : ' • Rata-rata rating ${s.averageRating!.toStringAsFixed(1)} ★ (${s.ratedCount})'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ]);
      },
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.type, required this.status, required this.search});
  final String? type;
  final String? status;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<WatchlistItem>>(
      stream: ref.watch(koleksiRepositoryProvider).watchItems(type: type, status: status, search: search),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Belum ada item.\nKetuk "Tambah", atau bagikan link dari Chrome/YouTube ke UsahaKonten.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
          itemCount: list.length,
          itemBuilder: (context, i) => WatchlistItemCard(item: list[i]),
        );
      },
    );
  }
}

/// Kartu item koleksi (dipakai di daftar & Beranda).
class WatchlistItemCard extends ConsumerWidget {
  const WatchlistItemCard({super.key, required this.item, this.compact = false});
  final WatchlistItem item;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = item;
    final (label, icon) = watchlistTypeLabels[i.type] ?? ('Lainnya', Icons.bookmark_outline);
    final hasProgress = i.progressTotal != null && i.progressTotal! > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/koleksi/${i.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AttachmentImage(i.coverPath, size: compact ? 44 : 56, fallback: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text([label, if (i.creator != null) i.creator!, if (i.platform != null) i.platform!].join(' • '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  WatchlistStatusChip(i.status),
                  if (i.rating != null) StarRating(value: i.rating, size: 14),
                  if (hasProgress) Text('${i.progress ?? 0}/${i.progressTotal} ${progressUnit(i.type)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
                if (hasProgress) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: ((i.progress ?? 0) / i.progressTotal!).clamp(0, 1).toDouble(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ]),
            ),
            if (hasProgress && i.status != 'selesai')
              IconButton(
                tooltip: 'Tambah 1 ${progressUnit(i.type)}',
                icon: const Icon(Icons.exposure_plus_1),
                onPressed: () => ref.read(koleksiRepositoryProvider).addProgress(i.id, 1),
              ),
          ]),
        ),
      ),
    );
  }
}
