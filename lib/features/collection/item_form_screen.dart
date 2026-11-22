import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/koleksi_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/attachment_service.dart';
import '../../widgets/attachment_image.dart';
import '../../widgets/form_fields.dart';
import 'collection_labels.dart';
import 'shared_text.dart';

/// Tambah / ubah item koleksi. [draft] terisi saat dibuka dari share sheet.
class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.itemId, this.draft});
  final String? itemId;
  final SharedItemDraft? draft;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _creator = TextEditingController();
  final _url = TextEditingController();
  final _platform = TextEditingController();
  final _review = TextEditingController();
  final _progress = TextEditingController();
  final _total = TextEditingController();
  String _type = 'buku';
  String _status = 'ingin';
  int? _rating;
  DateTime? _started;
  DateTime? _finished;
  String? _cover;
  bool _loading = true;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      _title.text = d.title;
      _url.text = d.url ?? '';
      _platform.text = d.platform ?? '';
      _type = d.type;
    }
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final i = await ref.read(koleksiRepositoryProvider).getItem(widget.itemId!);
      if (i != null) {
        _title.text = i.title;
        _creator.text = i.creator ?? '';
        _url.text = i.url ?? '';
        _platform.text = i.platform ?? '';
        _review.text = i.review ?? '';
        _progress.text = i.progress?.toString() ?? '';
        _total.text = i.progressTotal?.toString() ?? '';
        _type = i.type;
        _status = i.status;
        _rating = i.rating;
        _started = i.startedAt;
        _finished = i.finishedAt;
        _cover = i.coverPath;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_title, _creator, _url, _platform, _review, _progress, _total]) {
      c.dispose();
    }
    super.dispose();
  }

  Value<String?> _v(TextEditingController c) => Value(c.text.trim().isEmpty ? null : c.text.trim());
  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final total = _int(_total);
    final progress = _int(_progress) == null ? null : clampProgress(_int(_progress)!, total);
    final (started, finished) = applyStatusDates(_status, _started, _finished, DateTime.now());
    final id = await ref
        .read(koleksiRepositoryProvider)
        .save(
          WatchlistItemsCompanion(
            id: _isEdit ? Value(widget.itemId!) : const Value.absent(),
            type: Value(_type),
            title: Value(_title.text.trim()),
            creator: _v(_creator),
            url: _v(_url),
            platform: _v(_platform),
            status: Value(_status),
            rating: Value(_rating),
            review: _v(_review),
            progress: Value(progress),
            progressTotal: Value(total),
            startedAt: Value(started),
            finishedAt: Value(finished),
            coverPath: Value(_cover),
          ),
        );
    if (!mounted) return;
    if (_isEdit) {
      context.pop();
    } else {
      context.pushReplacement('/koleksi/$id');
    }
  }

  Future<DateTime?> _date(DateTime? initial) => showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now(),
    firstDate: DateTime(1990),
    lastDate: DateTime(2100),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final unit = progressUnit(_type);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah item' : 'Tambah ke Koleksi')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final r = await AttachmentService.pick('koleksi', type: FileType.image);
                    if (r != null) setState(() => _cover = r.$1);
                  },
                  child: AttachmentImage(_cover, size: 72, fallback: Icons.add_photo_alternate_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _title,
                    maxLines: 2,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Judul *'),
                    validator: (v) => Validators.required(v, 'Judul wajib diisi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in watchlistTypeLabels.entries)
                  ChoiceChip(
                    avatar: Icon(e.value.$2, size: 18),
                    label: Text(e.value.$1),
                    selected: _type == e.key,
                    onSelected: (_) => setState(() => _type = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _creator,
              decoration: const InputDecoration(labelText: 'Penulis / sumber / channel'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Link', hintText: 'https://...'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                final u = Uri.tryParse(s);
                return u == null || !u.hasScheme ? 'Link harus diawali https://' : null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _platform,
              decoration: const InputDecoration(labelText: 'Platform', hintText: 'mis. YouTube, Netflix, Gramedia'),
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
                    selected: _status == e.key,
                    onSelected: (_) => setState(() => _status = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _progress,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Progress ($unit)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _total,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: 'Total ($unit)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Rating'),
            StarRating(value: _rating, onChanged: (r) => setState(() => _rating = r)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _review,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Catatan / review singkat'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_outlined),
              title: Text('Mulai: ${_started == null ? '-' : Fmt.date(_started)}'),
              onTap: () async {
                final d = await _date(_started);
                if (d != null) setState(() => _started = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text('Selesai: ${_finished == null ? '-' : Fmt.date(_finished)}'),
              onTap: () async {
                final d = await _date(_finished);
                if (d != null) setState(() => _finished = d);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  if (await confirmDialog(
                    context,
                    title: 'Hapus item?',
                    message: _title.text,
                    ok: 'Hapus',
                    danger: true,
                  )) {
                    await ref.read(koleksiRepositoryProvider).softDelete(widget.itemId!);
                    if (context.mounted) context.go('/koleksi');
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus item'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
