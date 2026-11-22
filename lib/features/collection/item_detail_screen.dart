import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/attachment_image.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/related_notes_section.dart';
import '../../widgets/section_card.dart';
import '../notes/link_targets.dart';
import 'collection_labels.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(koleksiRepositoryProvider);
    return StreamBuilder<WatchlistItem?>(
      stream: repo.watchItem(itemId),
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final i = snap.data;
        if (i == null || i.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Item tidak ditemukan.')),
          );
        }
        final (typeLabel, icon) = watchlistTypeLabels[i.type] ?? ('Lainnya', Icons.bookmark_outline);
        final hasTotal = i.progressTotal != null && i.progressTotal! > 0;
        final unit = progressUnit(i.type);
        return Scaffold(
          appBar: AppBar(
            title: Text(typeLabel),
            actions: [
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/koleksi/${i.id}/ubah'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AttachmentImage(i.coverPath, size: 88, fallback: icon),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(i.title, style: Theme.of(context).textTheme.titleLarge),
                        if (i.creator != null) Text(i.creator!),
                        if (i.platform != null) Text(i.platform!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (i.url != null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: () async {
                    final ok = await launchUrl(Uri.parse(i.url!), mode: LaunchMode.externalApplication);
                    if (!ok && context.mounted) showSnack(context, 'Tidak bisa membuka link');
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text('Buka di ${i.platform ?? 'browser'}'),
                ),
              const SizedBox(height: 16),
              const Text('Status'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final e in watchlistStatusLabels.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: i.status == e.key,
                      onSelected: (_) => repo.setStatus(i.id, e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Rating'),
                  const SizedBox(width: 8),
                  StarRating(value: i.rating, onChanged: (r) => repo.setRating(i.id, r)),
                ],
              ),
              if (hasTotal || i.progress != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Progress: ${i.progress ?? 0}${hasTotal ? ' / ${i.progressTotal}' : ''} $unit'),
                          if (hasTotal) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: ((i.progress ?? 0) / i.progressTotal!).clamp(0, 1).toDouble(),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kurangi',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => repo.addProgress(i.id, -1),
                    ),
                    IconButton(
                      tooltip: 'Tambah',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => repo.addProgress(i.id, 1),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                [
                  if (i.startedAt != null) 'Mulai ${Fmt.date(i.startedAt)}',
                  if (i.finishedAt != null) 'Selesai ${Fmt.date(i.finishedAt)}',
                ].join(' • '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (i.review != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(i.review!)),
                ),
              ],
              const SizedBox(height: 16),
              _LinkedIdeas(itemId: i.id),
              const SizedBox(height: 12),
              RelatedNotesSection(entityType: LinkType.watchlistItem, entityId: i.id),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

/// Relasi item ↔ ide konten (mis. "video review buku X").
class _LinkedIdeas extends ConsumerWidget {
  const _LinkedIdeas({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(koleksiRepositoryProvider);
    return StreamBuilder<List<ContentIdea>>(
      stream: repo.watchIdeasFor(itemId),
      builder: (context, snap) {
        final list = snap.data ?? const <ContentIdea>[];
        return SectionCard(
          title: 'Ide konten terkait',
          icon: Icons.lightbulb_outline,
          trailing: IconButton(
            tooltip: 'Tautkan ide konten',
            icon: const Icon(Icons.add_link),
            onPressed: () async {
              final t = await pickLinkTarget(context, types: const [LinkType.contentIdea]);
              if (t != null) await repo.linkIdea(itemId, t.$2);
            },
          ),
          child: list.isEmpty
              ? const EmptyHint('Mis. ide "video review buku ini". Ketuk ikon tautan untuk memilih.')
              : Column(
                  children: [
                    for (final idea in list)
                      ListTile(
                        dense: true,
                        title: Text(idea.title),
                        subtitle: Text('Status: ${idea.status}'),
                        onTap: () => context.push('/konten/ide/${idea.id}'),
                        trailing: IconButton(
                          tooltip: 'Lepas tautan',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => repo.unlinkIdea(itemId, idea.id),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
