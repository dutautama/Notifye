import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../providers/app_providers.dart';
import 'markdown_text.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  String? _tag;
  bool _archived = false;
  late Stream<List<NoteListRow>> _stream = _make();

  CatatanRepository get _repo => ref.read(catatanRepositoryProvider);

  Stream<List<NoteListRow>> _make() =>
      _repo.watchNotes(search: _query, category: _category, tag: _tag, archived: _archived);

  void _update(VoidCallback fn) => setState(() {
        fn();
        _stream = _make();
      });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtering = _category != null || _tag != null || _archived;
    return Scaffold(
      appBar: AppBar(title: Text(_archived ? 'Arsip catatan' : 'Catatan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/catatan/baru'),
        icon: const Icon(Icons.edit_note),
        label: const Text('Catatan baru'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (v) => _update(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari di semua catatan',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        _update(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        _FilterBar(
          category: _category,
          tag: _tag,
          archived: _archived,
          onCategory: (c) => _update(() => _category = c),
          onTag: (t) => _update(() => _tag = t),
          onArchived: (a) => _update(() => _archived = a),
        ),
        Expanded(
          child: StreamBuilder<List<NoteListRow>>(
            stream: _stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _query.isNotEmpty
                          ? 'Tidak ada catatan yang cocok dengan "$_query".'
                          : filtering
                              ? 'Tidak ada catatan untuk filter ini.'
                              : 'Belum ada catatan.\nKetuk "Catatan baru" untuk mulai menulis.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                itemCount: list.length,
                itemBuilder: (context, i) => _NoteCard(row: list[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.category,
    required this.tag,
    required this.archived,
    required this.onCategory,
    required this.onTag,
    required this.onArchived,
  });

  final String? category;
  final String? tag;
  final bool archived;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onTag;
  final ValueChanged<bool> onArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(catatanRepositoryProvider);
    return SizedBox(
      height: 52,
      child: StreamBuilder<List<String>>(
        stream: repo.watchCategories(),
        builder: (context, cats) => StreamBuilder<List<(String, int)>>(
          stream: repo.watchAllTags(),
          builder: (context, tags) => ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              FilterChip(
                avatar: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Arsip'),
                selected: archived,
                onSelected: onArchived,
              ),
              const SizedBox(width: 8),
              for (final c in cats.data ?? const <String>[]) ...[
                ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  onSelected: (s) => onCategory(s ? c : null),
                ),
                const SizedBox(width: 8),
              ],
              for (final (t, n) in tags.data ?? const <(String, int)>[]) ...[
                ChoiceChip(
                  label: Text('#$t ($n)'),
                  selected: tag == t,
                  onSelected: (s) => onTag(s ? t : null),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.row});
  final NoteListRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = row.note;
    final scheme = Theme.of(context).colorScheme;
    final title = n.title.trim().isEmpty ? '(tanpa judul)' : n.title.trim();
    final preview = MarkdownText.preview(n.body);
    final (done, total) = MarkdownText.checklistProgress(n.body);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/catatan/${n.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (n.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin, size: 16, color: scheme.primary),
                    ),
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ]),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(preview, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(Fmt.dateTime(n.updatedAt), style: Theme.of(context).textTheme.bodySmall),
                  if (n.category != null) Text(n.category!, style: TextStyle(fontSize: 12, color: scheme.primary)),
                  if (total > 0) Text('☑ $done/$total', style: Theme.of(context).textTheme.bodySmall),
                  for (final t in row.tags.take(4)) Text('#$t', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Pilihan',
              onSelected: (v) {
                final repo = ref.read(catatanRepositoryProvider);
                switch (v) {
                  case 'pin':
                    repo.setPinned(n.id, !n.isPinned);
                  case 'arsip':
                    repo.setArchived(n.id, !n.isArchived);
                }
              },
              itemBuilder: (_) => [
                if (!n.isArchived)
                  PopupMenuItem(value: 'pin', child: Text(n.isPinned ? 'Lepas sematan' : 'Sematkan di atas')),
                PopupMenuItem(value: 'arsip', child: Text(n.isArchived ? 'Keluarkan dari arsip' : 'Arsipkan')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
