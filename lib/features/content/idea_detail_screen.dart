import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/konten_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/attachment_service.dart';
import '../../services/share_service.dart';
import '../../widgets/attachment_image.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/related_notes_section.dart';
import '../notes/link_targets.dart';
import '../../widgets/section_card.dart';
import 'content_labels.dart';

class IdeaDetailScreen extends ConsumerWidget {
  const IdeaDetailScreen({super.key, required this.ideaId});
  final String ideaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<ContentIdea?>(
      stream: repo.watchIdea(ideaId),
      builder: (context, snap) {
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final idea = snap.data;
        if (idea == null || idea.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Ide konten tidak ditemukan.')),
          );
        }
        final platforms = KontenRepository.decodeList(idea.platforms);
        final tags = KontenRepository.decodeList(idea.tags);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ide konten'),
            actions: [
              IconButton(
                tooltip: 'Ubah',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/konten/ide/${idea.id}/ubah'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(idea.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PopupMenuButton<String>(
                    tooltip: 'Ubah status',
                    onSelected: (s) => repo.setStatus(idea.id, s),
                    itemBuilder: (_) => [
                      for (final e in ideaStatusLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [IdeaStatusChip(idea.status), const Icon(Icons.arrow_drop_down)],
                    ),
                  ),
                  Text('Prioritas ${priorityLabels[idea.priority]}'),
                  if (idea.pillar != null) Chip(label: Text(idea.pillar!), visualDensity: VisualDensity.compact),
                  if (idea.dueDate != null) Text('Target ${Fmt.date(idea.dueDate)}'),
                ],
              ),
              if (platforms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Platform: ${platforms.map(platformLabel).join(', ')}'),
              ],
              if (tags.isNotEmpty) Text('Tag: ${tags.map((t) => '#$t').join(' ')}'),
              if (idea.description != null) ...[const SizedBox(height: 12), SelectableText(idea.description!)],
              const SizedBox(height: 16),
              _LinkedProducts(ideaId: idea.id),
              const SizedBox(height: 12),
              _Assets(ideaId: idea.id),
              const SizedBox(height: 12),
              _Schedules(idea: idea),
              const SizedBox(height: 12),
              _Publications(idea: idea),
              const SizedBox(height: 12),
              _LinkedWatchlist(ideaId: idea.id),
              const SizedBox(height: 12),
              RelatedNotesSection(entityType: LinkType.contentIdea, entityId: idea.id),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------- produk terkait
class _LinkedProducts extends ConsumerWidget {
  const _LinkedProducts({required this.ideaId});
  final String ideaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<List<Product>>(
      stream: repo.watchLinkedProducts(ideaId),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return SectionCard(
          title: 'Produk/jasa yang dipromosikan',
          icon: Icons.sell_outlined,
          trailing: IconButton(
            tooltip: 'Tautkan produk',
            icon: const Icon(Icons.add_link),
            onPressed: () async {
              final p = await context.push<Product>('/usaha/produk/pilih');
              if (p != null) await repo.linkProduct(ideaId, p.id);
            },
          ),
          child: list.isEmpty
              ? const EmptyHint('Belum ada. Ketuk ikon tautan untuk memilih produk/jasa.')
              : Column(
                  children: [
                    for (final p in list)
                      ListTile(
                        dense: true,
                        leading: AttachmentImage(p.imagePath, size: 36),
                        title: Text(p.name),
                        subtitle: Text(Fmt.rupiah(p.sellPrice)),
                        onTap: () => context.push('/usaha/produk/${p.id}'),
                        trailing: IconButton(
                          tooltip: 'Lepas tautan',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => repo.unlinkProduct(ideaId, p.id),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ----------------------------------------------------------- aset
class _Assets extends ConsumerWidget {
  const _Assets({required this.ideaId});
  final String ideaId;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(kontenRepositoryProvider);
    var kind = 'link';
    final title = TextEditingController();
    final url = TextEditingController();
    final notes = TextEditingController();
    String? filePath;
    String? fileName;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final fileKind = const {'gambar', 'video', 'audio', 'dokumen'}.contains(kind);
          return AlertDialog(
            title: const Text('Tambah aset'),
            content: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Jenis'),
                      items: [
                        for (final e in assetKindLabels.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Row(
                              children: [Icon(e.value.$2, size: 18), const SizedBox(width: 8), Text(e.value.$1)],
                            ),
                          ),
                      ],
                      onChanged: (v) => setD(() => kind = v ?? 'link'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Judul *'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    if (kind != 'naskah')
                      TextFormField(
                        controller: url,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: fileKind ? 'Link (opsional jika lampirkan file)' : 'Link *',
                          hintText: 'https://drive.google.com/...',
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) {
                            return fileKind && filePath != null
                                ? null
                                : (fileKind ? 'Isi link atau lampirkan file' : 'Wajib diisi');
                          }
                          final u = Uri.tryParse(s);
                          return u == null || !u.hasScheme ? 'Link harus diawali https://' : null;
                        },
                      ),
                    if (fileKind) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final r = await AttachmentService.pick('konten');
                            if (r != null) setD(() => (filePath, fileName) = r);
                          } catch (e) {
                            if (ctx.mounted) showSnack(ctx, e.toString().replaceFirst('Bad state: ', ''));
                          }
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(fileName ?? 'Lampirkan file dari HP'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      maxLines: kind == 'naskah' ? 8 : 2,
                      decoration: InputDecoration(labelText: kind == 'naskah' ? 'Isi naskah / catatan' : 'Catatan'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      await repo.saveAsset(
        ContentAssetsCompanion.insert(
          ideaId: ideaId,
          title: title.text.trim(),
          kind: Value(kind),
          url: Value(url.text.trim().isEmpty ? null : url.text.trim()),
          filePath: Value(filePath),
          notes: Value(notes.text.trim().isEmpty ? null : notes.text.trim()),
        ),
      );
    } else {
      await AttachmentService.delete(filePath);
    }
    title.dispose();
    url.dispose();
    notes.dispose();
  }

  Future<void> _open(BuildContext context, ContentAsset a) async {
    if (a.url != null) {
      final ok = await launchUrl(Uri.parse(a.url!), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showSnack(context, 'Tidak bisa membuka link');
    } else if (a.filePath != null) {
      final f = await AttachmentService.fileFor(a.filePath!);
      if (await f.exists()) {
        await ShareService.shareFile(f, mime: 'application/octet-stream', subject: a.title);
      } else if (context.mounted) {
        showSnack(context, 'File lampiran tidak ditemukan');
      }
    } else if (a.notes != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(a.title),
          content: SingleChildScrollView(child: SelectableText(a.notes!)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<List<ContentAsset>>(
      stream: repo.watchAssets(ideaId),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return SectionCard(
          title: 'Produksi & aset',
          icon: Icons.perm_media_outlined,
          trailing: IconButton(
            tooltip: 'Tambah aset',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context, ref),
          ),
          child: list.isEmpty
              ? const EmptyHint('Simpan link Google Drive, video mentah, naskah, atau file dari HP.')
              : Column(
                  children: [
                    for (final a in list)
                      ListTile(
                        dense: true,
                        leading: a.kind == 'gambar' && a.filePath != null
                            ? AttachmentImage(a.filePath, size: 40)
                            : Icon(assetKindLabels[a.kind]?.$2 ?? Icons.link),
                        title: Text(a.title),
                        subtitle: Text(
                          a.url ?? (a.filePath != null ? 'File di HP' : (a.notes ?? '')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _open(context, a),
                        trailing: IconButton(
                          tooltip: 'Hapus aset',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            if (await confirmDialog(
                              context,
                              title: 'Hapus aset?',
                              message: a.title,
                              ok: 'Hapus',
                              danger: true,
                            )) {
                              await repo.deleteAsset(a.id);
                            }
                          },
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// --------------------------------------------------------- jadwal
class _Schedules extends ConsumerWidget {
  const _Schedules({required this.idea});
  final ContentIdea idea;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final platforms = KontenRepository.decodeList(idea.platforms);
    var platform = platforms.isNotEmpty ? platforms.first : 'instagram';
    var when = DateTime.now().add(const Duration(days: 1));
    when = DateTime(when.year, when.month, when.day, 19);
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Jadwal tayang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: platform,
                decoration: const InputDecoration(labelText: 'Platform'),
                items: [for (final e in contentPlatforms.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => platform = v ?? platform,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(Fmt.dateTime(when)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: when,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d == null || !ctx.mounted) return;
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                  setD(() => when = DateTime(d.year, d.month, d.day, t?.hour ?? when.hour, t?.minute ?? when.minute));
                },
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Catatan (caption, jam terbaik, dll.)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await ref
          .read(kontenRepositoryProvider)
          .saveSchedule(
            ContentSchedulesCompanion.insert(
              ideaId: idea.id,
              platform: platform,
              scheduledAt: when,
              notes: Value(notes.text.trim().isEmpty ? null : notes.text.trim()),
            ),
          );
    }
    notes.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<List<ContentSchedule>>(
      stream: repo.watchSchedules(idea.id),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return SectionCard(
          title: 'Jadwal tayang',
          icon: Icons.event_note,
          trailing: IconButton(
            tooltip: 'Tambah jadwal',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context, ref),
          ),
          child: list.isEmpty
              ? const EmptyHint('Belum dijadwalkan.')
              : Column(
                  children: [
                    for (final s in list)
                      ListTile(
                        dense: true,
                        title: Text('${platformLabel(s.platform)} • ${Fmt.dateTime(s.scheduledAt)}'),
                        subtitle: Text([scheduleStatusLabels[s.status], if (s.notes != null) s.notes].join(' • ')),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Pilihan',
                          onSelected: (v) async {
                            if (v == 'hapus') {
                              await repo.deleteSchedule(s.id);
                            } else {
                              await repo.saveSchedule(ContentSchedulesCompanion(id: Value(s.id), status: Value(v)));
                            }
                          },
                          itemBuilder: (_) => [
                            for (final e in scheduleStatusLabels.entries)
                              if (e.key != s.status)
                                PopupMenuItem(value: e.key, child: Text('Tandai ${e.value.toLowerCase()}')),
                            const PopupMenuItem(value: 'hapus', child: Text('Hapus jadwal')),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// ------------------------------------------------------ publikasi
class _Publications extends ConsumerWidget {
  const _Publications({required this.idea});
  final ContentIdea idea;

  Future<void> _edit(BuildContext context, WidgetRef ref, [ContentPublication? existing]) async {
    final repo = ref.read(kontenRepositoryProvider);
    final schedules = (await repo.watchSchedules(idea.id).first).where((s) => s.status != 'batal').toList();
    if (!context.mounted) return;
    final platforms = KontenRepository.decodeList(idea.platforms);
    var platform = existing?.platform ?? (platforms.isNotEmpty ? platforms.first : 'instagram');
    String? scheduleId = existing?.scheduleId;
    var published = existing?.publishedAt ?? DateTime.now();
    final url = TextEditingController(text: existing?.postUrl ?? '');
    final fields = {
      'views': TextEditingController(text: _n(existing?.views)),
      'reach': TextEditingController(text: _n(existing?.reach)),
      'likes': TextEditingController(text: _n(existing?.likes)),
      'comments': TextEditingController(text: _n(existing?.comments)),
      'shares': TextEditingController(text: _n(existing?.shares)),
      'saves': TextEditingController(text: _n(existing?.saves)),
      'followers': TextEditingController(text: _n(existing?.followersGained)),
      'leads': TextEditingController(text: _n(existing?.leads)),
    };
    const labels = {
      'views': 'Views',
      'reach': 'Reach',
      'likes': 'Like',
      'comments': 'Komentar',
      'shares': 'Share',
      'saves': 'Simpan',
      'followers': 'Follower baru',
      'leads': 'Leads (calon pembeli)',
    };
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Catat publikasi' : 'Perbarui angka'),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: platform,
                    decoration: const InputDecoration(labelText: 'Platform'),
                    items: [
                      for (final e in contentPlatforms.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => platform = v ?? platform,
                  ),
                  if (schedules.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: schedules.any((s) => s.id == scheduleId) ? scheduleId : null,
                      decoration: const InputDecoration(labelText: 'Dari jadwal (opsional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Tidak terkait jadwal —')),
                        for (final s in schedules)
                          DropdownMenuItem(
                            value: s.id,
                            child: Text('${platformLabel(s.platform)} ${Fmt.dateTime(s.scheduledAt)}'),
                          ),
                      ],
                      onChanged: (v) => scheduleId = v,
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'Link postingan', hintText: 'https://...'),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return null;
                      final u = Uri.tryParse(s);
                      return u == null || !u.hasScheme ? 'Link harus diawali https://' : null;
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available),
                    title: Text('Tayang: ${Fmt.date(published)}'),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: published,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setD(() => published = d);
                    },
                  ),
                  for (var i = 0; i < labels.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          for (final k in labels.keys.skip(i).take(2)) ...[
                            Expanded(
                              child: TextFormField(
                                controller: fields[k],
                                keyboardType: TextInputType.number,
                                inputFormatters: [ThousandsInputFormatter()],
                                decoration: InputDecoration(labelText: labels[k]),
                              ),
                            ),
                            if (k != labels.keys.skip(i).take(2).last) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    int read(String k) => MoneyField.read(fields[k]!).round();
    if (ok == true) {
      await repo.savePublication(
        ContentPublicationsCompanion(
          id: existing == null ? const Value.absent() : Value(existing.id),
          ideaId: Value(idea.id),
          scheduleId: Value(scheduleId),
          platform: Value(platform),
          postUrl: Value(url.text.trim().isEmpty ? null : url.text.trim()),
          publishedAt: Value(published),
          views: Value(read('views')),
          reach: Value(read('reach')),
          likes: Value(read('likes')),
          comments: Value(read('comments')),
          shares: Value(read('shares')),
          saves: Value(read('saves')),
          followersGained: Value(read('followers')),
          leads: Value(read('leads')),
        ),
      );
    }
    url.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
  }

  static String _n(int? v) => v == null || v == 0 ? '' : ThousandsInputFormatter.format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(kontenRepositoryProvider);
    return StreamBuilder<List<ContentPublication>>(
      stream: repo.watchPublications(idea.id),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        final reach = list.fold<int>(0, (s, p) => s + p.reach);
        final eng = list.fold<int>(0, (s, p) => s + p.likes + p.comments + p.shares + p.saves);
        return SectionCard(
          title: 'Publish & reach',
          icon: Icons.insights_outlined,
          trailing: IconButton(
            tooltip: 'Catat publikasi',
            icon: const Icon(Icons.add),
            onPressed: () => _edit(context, ref),
          ),
          child: list.isEmpty
              ? const EmptyHint('Setelah tayang, catat link postingan dan angka reach/engagement di sini.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Total reach ${Fmt.number(reach)} • engagement ${Fmt.number(eng)}'
                        '${reach > 0 ? ' • ER ${(eng * 100 / reach).toStringAsFixed(1)}%' : ''}',
                      ),
                    ),
                    for (final p in list)
                      ListTile(
                        dense: true,
                        title: Text('${platformLabel(p.platform)} • ${Fmt.date(p.publishedAt)}'),
                        subtitle: Text(
                          'Views ${Fmt.number(p.views)} • Reach ${Fmt.number(p.reach)} • '
                          'Like ${Fmt.number(p.likes)} • Komen ${Fmt.number(p.comments)} • '
                          'Share ${Fmt.number(p.shares)} • Simpan ${Fmt.number(p.saves)}'
                          '${p.leads > 0 ? ' • ${p.leads} leads' : ''}',
                        ),
                        onTap: () => _edit(context, ref, p),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Pilihan',
                          onSelected: (v) async {
                            if (v == 'buka' && p.postUrl != null) {
                              await launchUrl(Uri.parse(p.postUrl!), mode: LaunchMode.externalApplication);
                            } else if (v == 'hapus') {
                              await repo.deletePublication(p.id);
                            }
                          },
                          itemBuilder: (_) => [
                            if (p.postUrl != null) const PopupMenuItem(value: 'buka', child: Text('Buka postingan')),
                            const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                          ],
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Sisi balik relasi koleksi ↔ ide konten: buku/video yang menjadi bahan ide ini.
class _LinkedWatchlist extends ConsumerWidget {
  const _LinkedWatchlist({required this.ideaId});
  final String ideaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(koleksiRepositoryProvider);
    return StreamBuilder<List<WatchlistItem>>(
      stream: repo.watchItemsForIdea(ideaId),
      builder: (context, snap) {
        final list = snap.data ?? const <WatchlistItem>[];
        return SectionCard(
          title: 'Koleksi terkait',
          icon: Icons.collections_bookmark_outlined,
          trailing: IconButton(
            tooltip: 'Tautkan item koleksi',
            icon: const Icon(Icons.add_link),
            onPressed: () async {
              final t = await pickLinkTarget(context, types: const [LinkType.watchlistItem]);
              if (t != null) await repo.linkIdea(t.$2, ideaId);
            },
          ),
          child: list.isEmpty
              ? const EmptyHint('Buku/video/artikel yang menjadi bahan ide ini.')
              : Column(
                  children: [
                    for (final w in list)
                      ListTile(
                        dense: true,
                        title: Text(w.title),
                        subtitle: Text([w.type, if (w.creator != null) w.creator!].join(' • ')),
                        onTap: () => context.push('/koleksi/${w.id}'),
                        trailing: IconButton(
                          tooltip: 'Lepas tautan',
                          icon: const Icon(Icons.link_off),
                          onPressed: () => repo.unlinkIdea(w.id, ideaId),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}
