import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/section_card.dart';
import 'link_targets.dart';

/// Di editor catatan: daftar entitas yang ditautkan + tombol tautkan.
/// Jenis entitas yang bisa dipilih dari editor catatan.
const kNoteLinkTypes = [
  LinkType.product,
  LinkType.customer,
  LinkType.supplier,
  LinkType.transaction,
  LinkType.contentIdea,
];

class NoteLinksSection extends ConsumerWidget {
  const NoteLinksSection({super.key, required this.noteId});
  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(catatanRepositoryProvider);
    return StreamBuilder<List<NoteLink>>(
      stream: repo.watchLinks(noteId),
      builder: (context, snap) {
        final links = snap.data ?? const <NoteLink>[];
        return SectionCard(
          title: 'Ditautkan ke',
          icon: Icons.link,
          trailing: IconButton(
            tooltip: 'Tautkan',
            icon: const Icon(Icons.add_link),
            onPressed: () async {
              final t = await pickLinkTarget(context, types: kNoteLinkTypes);
              if (t != null) await repo.link(noteId, t.$1, t.$2);
            },
          ),
          child: links.isEmpty
              ? const EmptyHint('Tempelkan catatan ini ke produk, pelanggan, transaksi, ide konten, atau koleksi.')
              : FutureBuilder<List<LinkedEntity>>(
                  future: repo.resolveLinks(links),
                  builder: (context, res) => Column(children: [
                    for (final e in res.data ?? const <LinkedEntity>[])
                      ListTile(
                        dense: true,
                        leading: Icon(linkTargets[e.type]?.icon ?? Icons.link),
                        title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(linkTargets[e.type]?.label ?? e.type),
                        onTap: e.missing ? null : () => context.push(linkTargets[e.type]!.route(e.id)),
                        trailing: IconButton(
                          tooltip: 'Lepas tautan',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => repo.unlink(noteId, e.type, e.id),
                        ),
                      ),
                  ]),
                ),
        );
      },
    );
  }
}
