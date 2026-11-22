import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/attachment_service.dart';
import '../../services/share_service.dart';
import '../../widgets/attachment_image.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/section_card.dart';
import 'markdown_text.dart';
import 'markdown_view.dart';
import 'note_links_section.dart';

/// Editor catatan dengan auto-save (jeda 1 detik setelah berhenti mengetik).
/// Catatan baru baru dibuat di database setelah ada isi (tidak ada catatan kosong).
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId, this.linkType, this.linkId});
  final String? noteId;
  final String? linkType; // tautkan otomatis saat catatan baru dibuat
  final String? linkId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

enum _SaveState { idle, dirty, saving, saved }

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  static const _debounce = Duration(seconds: 1);

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _category = TextEditingController();
  final _tagInput = TextEditingController();
  final _bodyFocus = FocusNode();
  String? _id;
  Note? _note;
  List<String> _tags = [];
  bool _loading = true;
  bool _reading = false;
  Timer? _timer;
  _SaveState _save = _SaveState.idle;
  Future<void>? _inFlight;

  late final CatatanRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(catatanRepositoryProvider);
    _id = widget.noteId;
    _load();
  }

  Future<void> _load() async {
    if (_id != null) {
      final n = await _repo.getNote(_id!);
      if (n != null) {
        _note = n;
        _title.text = n.title;
        _body.text = n.body;
        _category.text = n.category ?? '';
        _tags = await _repo.watchTags(n.id).first;
        _reading = n.body.trim().isNotEmpty;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_save == _SaveState.dirty) {
      // Simpan perubahan terakhir tanpa menyentuh widget yang sedang dibuang.
      final title = _title.text, body = _body.text, tags = List.of(_tags);
      final category = _category.text.trim().isEmpty ? null : _category.text.trim();
      final id = _id, repo = _repo, linkType = widget.linkType, linkId = widget.linkId;
      unawaited(() async {
        if (id != null) {
          await repo.updateNote(id, title: title, body: body, category: Value(category));
        } else if (title.trim().isNotEmpty || body.trim().isNotEmpty) {
          final newId = await repo.createNote(
              title: title, body: body, category: category, linkType: linkType, linkId: linkId);
          if (tags.isNotEmpty) await repo.setTags(newId, tags);
        }
      }());
    }
    for (final c in [_title, _body, _category, _tagInput]) {
      c.dispose();
    }
    _bodyFocus.dispose();
    super.dispose();
  }

  void _changed() {
    _timer?.cancel();
    setState(() => _save = _SaveState.dirty);
    _timer = Timer(_debounce, _persist);
  }

  /// Simpan sekarang (dipanggil timer, tombol kembali, atau sebelum aksi lain).
  Future<void> _persist() async {
    _timer?.cancel();
    if (_inFlight != null) await _inFlight;
    if (_save != _SaveState.dirty) return;
    final title = _title.text;
    final body = _body.text;
    final category = _category.text.trim().isEmpty ? null : _category.text.trim();
    if (_id == null && title.trim().isEmpty && body.trim().isEmpty && _tags.isEmpty) {
      if (mounted) setState(() => _save = _SaveState.idle);
      return;
    }
    if (mounted) setState(() => _save = _SaveState.saving);
    final op = () async {
      if (_id == null) {
        _id = await _repo.createNote(
            title: title, body: body, category: category, linkType: widget.linkType, linkId: widget.linkId);
        if (_tags.isNotEmpty) await _repo.setTags(_id!, _tags);
      } else {
        await _repo.updateNote(_id!, title: title, body: body, category: Value(category));
      }
    }();
    _inFlight = op;
    try {
      await op;
      if (mounted && _save == _SaveState.saving) setState(() => _save = _SaveState.saved);
    } finally {
      _inFlight = null;
    }
  }

  /// Pastikan catatan sudah ada di database (untuk lampiran/tautan).
  Future<String?> _ensureSaved() async {
    if (_id == null) {
      if (_title.text.trim().isEmpty) _title.text = 'Catatan ${Fmt.date(DateTime.now())}';
      _save = _SaveState.dirty;
    }
    await _persist();
    return _id;
  }

  Future<void> _addTag(String raw) async {
    final t = normalizeTag(raw);
    _tagInput.clear();
    if (t == null || _tags.contains(t)) return;
    setState(() => _tags = [..._tags, t]..sort());
    final id = await _ensureSaved();
    if (id != null) await _repo.setTags(id, _tags);
  }

  Future<void> _removeTag(String t) async {
    setState(() => _tags = _tags.where((x) => x != t).toList());
    if (_id != null) await _repo.setTags(_id!, _tags);
  }

  void _apply(TextEditingValue Function(TextEditingValue) fn) {
    _body.value = fn(_body.value);
    _bodyFocus.requestFocus();
    _changed();
  }

  void _toggleCheckbox(int line) {
    _body.text = MarkdownText.toggleCheckbox(_body.text, line);
    _changed();
  }

  Future<void> _share() async {
    await _persist();
    final text = MarkdownText.toShareText(_title.text, _body.text);
    if (text.isEmpty) {
      if (mounted) showSnack(context, 'Catatan masih kosong.');
      return;
    }
    await SharePlus.instance.share(ShareParams(text: text, subject: _title.text.trim().isEmpty ? null : _title.text.trim()));
  }

  Future<void> _addAttachment() async {
    try {
      final id = await _ensureSaved();
      if (id == null) return;
      final r = await AttachmentService.pick('catatan');
      if (r == null) return;
      final f = await AttachmentService.fileFor(r.$1);
      final ext = r.$2.split('.').last.toLowerCase();
      await _repo.addAttachment(id,
          filePath: r.$1,
          fileName: r.$2,
          mime: const {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'}.contains(ext)
              ? 'image/$ext'
              : (ext == 'pdf' ? 'application/pdf' : null),
          sizeBytes: await f.length());
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _menu(String v) async {
    await _persist();
    final id = _id;
    if (id == null) return;
    switch (v) {
      case 'pin':
        await _repo.setPinned(id, !(_note?.isPinned ?? false));
      case 'arsip':
        await _repo.setArchived(id, !(_note?.isArchived ?? false));
        if (mounted) context.pop();
        return;
      case 'hapus':
        if (!mounted) return;
        final ok = await confirmDialog(context,
            title: 'Hapus catatan?', message: 'Catatan dan lampirannya disembunyikan.', ok: 'Hapus', danger: true);
        if (!ok) return;
        await _repo.softDelete(id);
        if (mounted) context.pop();
        return;
    }
    _note = await _repo.getNote(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final status = switch (_save) {
      _SaveState.dirty || _SaveState.saving => 'Menyimpan…',
      _SaveState.saved => 'Tersimpan',
      _SaveState.idle => '',
    };
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_persist());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(status, style: Theme.of(context).textTheme.bodyMedium),
          actions: [
            IconButton(
              tooltip: _reading ? 'Ubah' : 'Mode baca',
              icon: Icon(_reading ? Icons.edit_outlined : Icons.visibility_outlined),
              onPressed: () async {
                await _persist();
                setState(() => _reading = !_reading);
              },
            ),
            IconButton(tooltip: 'Bagikan', icon: const Icon(Icons.share_outlined), onPressed: _share),
            if (_id != null)
              PopupMenuButton<String>(
                tooltip: 'Pilihan',
                onSelected: _menu,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pin', child: Text(_note?.isPinned ?? false ? 'Lepas sematan' : 'Sematkan di atas')),
                  PopupMenuItem(value: 'arsip', child: Text(_note?.isArchived ?? false ? 'Keluarkan dari arsip' : 'Arsipkan')),
                  const PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                ],
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              controller: _title,
              onChanged: (_) => _changed(),
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.headlineSmall,
              decoration: const InputDecoration(
                hintText: 'Judul',
                border: InputBorder.none,
                filled: false,
              ),
            ),
            if (_reading)
              _body.text.trim().isEmpty
                  ? const Padding(padding: EdgeInsets.all(16), child: Text('(kosong)'))
                  : MarkdownView(text: _body.text, onToggleCheckbox: _toggleCheckbox)
            else ...[
              _Toolbar(onAction: _apply),
              TextField(
                controller: _body,
                focusNode: _bodyFocus,
                onChanged: (_) => _changed(),
                maxLines: null,
                minLines: 10,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Tulis catatan… (gunakan tombol di atas untuk tebal, judul, daftar, checklist)',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ],
            const Divider(),
            TextField(
              controller: _category,
              onChanged: (_) => _changed(),
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'mis. Ide, Referensi, To-do',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final t in _tags) InputChip(label: Text('#$t'), onDeleted: () => _removeTag(t)),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _tagInput,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addTag,
                  decoration: const InputDecoration(hintText: 'Tambah tag ↵', isDense: true, prefixText: '#'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_id != null) ...[
              _Attachments(noteId: _id!, onAdd: _addAttachment),
              const SizedBox(height: 12),
              NoteLinksSection(noteId: _id!),
            ] else
              OutlinedButton.icon(
                onPressed: _addAttachment,
                icon: const Icon(Icons.attach_file),
                label: const Text('Lampirkan gambar/PDF'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onAction});
  final void Function(TextEditingValue Function(TextEditingValue)) onAction;

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String tip, TextEditingValue Function(TextEditingValue) fn) =>
        IconButton(tooltip: tip, icon: Icon(icon), onPressed: () => onAction(fn));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        btn(Icons.format_bold, 'Tebal', (v) => MarkdownText.wrap(v, '**')),
        btn(Icons.format_italic, 'Miring', (v) => MarkdownText.wrap(v, '_')),
        btn(Icons.title, 'Judul', (v) => MarkdownText.togglePrefix(v, '## ')),
        btn(Icons.format_list_bulleted, 'Daftar', (v) => MarkdownText.togglePrefix(v, '- ')),
        btn(Icons.format_list_numbered, 'Daftar bernomor', (v) => MarkdownText.togglePrefix(v, '1. ')),
        btn(Icons.check_box_outlined, 'Checklist', (v) => MarkdownText.togglePrefix(v, '- [ ] ')),
      ]),
    );
  }
}

class _Attachments extends ConsumerWidget {
  const _Attachments({required this.noteId, required this.onAdd});
  final String noteId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(catatanRepositoryProvider);
    return StreamBuilder<List<NoteAttachment>>(
      stream: repo.watchAttachments(noteId),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        return SectionCard(
          title: 'Lampiran',
          icon: Icons.attach_file,
          trailing: IconButton(tooltip: 'Tambah lampiran', icon: const Icon(Icons.add), onPressed: onAdd),
          child: list.isEmpty
              ? const EmptyHint('Belum ada lampiran (gambar, PDF, dokumen).')
              : Column(children: [
                  for (final a in list)
                    ListTile(
                      dense: true,
                      leading: (a.mime ?? '').startsWith('image/')
                          ? AttachmentImage(a.filePath, size: 40)
                          : Icon(a.mime == 'application/pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined),
                      title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: a.sizeBytes == null ? null : Text('${(a.sizeBytes! / 1024).toStringAsFixed(0)} KB'),
                      onTap: () async {
                        final f = await AttachmentService.fileFor(a.filePath);
                        if (await f.exists()) {
                          await ShareService.shareFile(f, mime: a.mime ?? 'application/octet-stream', subject: a.fileName);
                        } else if (context.mounted) {
                          showSnack(context, 'File lampiran tidak ditemukan');
                        }
                      },
                      trailing: IconButton(
                        tooltip: 'Hapus lampiran',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          if (await confirmDialog(context,
                              title: 'Hapus lampiran?', message: a.fileName, ok: 'Hapus', danger: true)) {
                            await repo.deleteAttachment(a.id);
                          }
                        },
                      ),
                    ),
                ]),
        );
      },
    );
  }
}
