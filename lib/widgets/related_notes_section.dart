import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../data/database/app_database.dart';
import '../data/repositories/catatan_repository.dart';
import '../features/notes/markdown_text.dart';
import '../providers/app_providers.dart';
import 'section_card.dart';

/// Bagian "Catatan terkait" untuk halaman detail entitas mana pun.
/// Tombol + : buat catatan baru yang langsung tertaut, atau tautkan catatan yang sudah ada.
class RelatedNotesSection extends ConsumerWidget {
  const RelatedNotesSection({super.key, required this.entityType, required this.entityId});
  final String entityType;
  final String entityId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.note_add_outlined),
            title: const Text('Buat catatan baru'),
            onTap: () => Navigator.pop(ctx, 'baru'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Tautkan catatan yang sudah ada'),
            onTap: () => Navigator.pop(ctx, 'tautkan'),
          ),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'baru') {
      await context.push('/catatan/baru?type=$entityType&id=$entityId');
    } else if (choice == 'tautkan') {
      final noteId = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const _NotePickerPage()),
      );
      if (noteId != null) await ref.read(catatanRepositoryProvider).link(noteId, entityType, entityId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(catatanRepositoryProvider);
    return StreamBuilder<List<Note>>(
      stream: repo.watchNotesFor(entityType, entityId),
      builder: (context, snap) {
        final list = snap.data ?? const <Note>[];
        return SectionCard(
          title: 'Catatan terkait',
          icon: Icons.sticky_note_2_outlined,
          trailing: IconButton(tooltip: 'Tambah catatan', icon: const Icon(Icons.add), onPressed: () => _add(context, ref)),
          child: list.isEmpty
              ? const EmptyHint('Belum ada catatan.')
              : Column(children: [
                  for (final n in list)
                    ListTile(
                      dense: true,
                      title: Text(n.title.trim().isEmpty ? '(tanpa judul)' : n.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [Fmt.date(n.updatedAt), MarkdownText.preview(n.body, maxChars: 60)]
                            .where((s) => s.isNotEmpty)
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => context.push('/catatan/${n.id}'),
                      trailing: IconButton(
                        tooltip: 'Lepas tautan',
                        icon: const Icon(Icons.link_off),
                        onPressed: () => repo.unlink(n.id, entityType, entityId),
                      ),
                    ),
                ]),
        );
      },
    );
  }
}

class _NotePickerPage extends ConsumerStatefulWidget {
  const _NotePickerPage();

  @override
  ConsumerState<_NotePickerPage> createState() => _NotePickerPageState();
}

class _NotePickerPageState extends ConsumerState<_NotePickerPage> {
  late Stream<List<NoteListRow>> _stream = ref.read(catatanRepositoryProvider).watchNotes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih catatan')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _stream = ref.read(catatanRepositoryProvider).watchNotes(search: v)),
            decoration: const InputDecoration(hintText: 'Cari catatan', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NoteListRow>>(
            stream: _stream,
            builder: (context, snap) {
              final list = snap.data;
              if (list == null) return const Center(child: CircularProgressIndicator());
              if (list.isEmpty) return const Center(child: Text('Tidak ada catatan.'));
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(list[i].note.title.trim().isEmpty ? '(tanpa judul)' : list[i].note.title),
                  subtitle: Text(MarkdownText.preview(list[i].note.body, maxChars: 80),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, list[i].note.id),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
