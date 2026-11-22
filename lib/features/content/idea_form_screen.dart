import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/konten_repository.dart';
import '../../providers/app_providers.dart';
import '../../widgets/form_fields.dart';
import 'content_labels.dart';

/// Buat / ubah ide konten.
class IdeaFormScreen extends ConsumerStatefulWidget {
  const IdeaFormScreen({super.key, this.ideaId, this.initialStatus});
  final String? ideaId;
  final String? initialStatus;

  @override
  ConsumerState<IdeaFormScreen> createState() => _IdeaFormScreenState();
}

class _IdeaFormScreenState extends ConsumerState<IdeaFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _pillar = TextEditingController();
  final _tags = TextEditingController();
  final _platforms = <String>{};
  late String _status = widget.initialStatus ?? 'ide';
  int _priority = 2;
  DateTime? _due;
  bool _loading = true;

  bool get _isEdit => widget.ideaId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final i = await ref.read(kontenRepositoryProvider).getIdea(widget.ideaId!);
      if (i != null) {
        _title.text = i.title;
        _desc.text = i.description ?? '';
        _pillar.text = i.pillar ?? '';
        _tags.text = KontenRepository.decodeList(i.tags).join(', ');
        _platforms.addAll(KontenRepository.decodeList(i.platforms));
        _status = i.status;
        _priority = i.priority;
        _due = i.dueDate;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _pillar, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final tags = _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    final id = await ref
        .read(kontenRepositoryProvider)
        .saveIdea(
          ContentIdeasCompanion(
            id: _isEdit ? Value(widget.ideaId!) : const Value.absent(),
            title: Value(_title.text.trim()),
            description: Value(_desc.text.trim().isEmpty ? null : _desc.text.trim()),
            platforms: Value(KontenRepository.encodeList(_platforms.toList())),
            status: Value(_status),
            priority: Value(_priority),
            pillar: Value(_pillar.text.trim().isEmpty ? null : _pillar.text.trim()),
            tags: Value(KontenRepository.encodeList(tags)),
            dueDate: Value(_due),
          ),
        );
    if (!mounted) return;
    if (_isEdit) {
      context.pop();
    } else {
      context.pushReplacement('/konten/ide/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah ide konten' : 'Ide konten baru')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Judul *'),
              validator: (v) => Validators.required(v, 'Judul wajib diisi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _desc,
              maxLines: 5,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Deskripsi / hook / poin utama'),
            ),
            const SizedBox(height: 16),
            const Text('Platform target'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in contentPlatforms.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: _platforms.contains(e.key),
                    onSelected: (v) => setState(() => v ? _platforms.add(e.key) : _platforms.remove(e.key)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Status'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in ideaStatusLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _status == e.key,
                    onSelected: (_) => setState(() => _status = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Prioritas'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [for (final e in priorityLabels.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pillar,
              decoration: const InputDecoration(
                labelText: 'Pilar konten',
                hintText: 'mis. Edukasi, Promo, Behind the scene',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(labelText: 'Tag (pisahkan dengan koma)'),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(_due == null ? 'Target selesai: belum diatur' : 'Target selesai: ${Fmt.date(_due)}'),
              trailing: _due == null
                  ? null
                  : IconButton(
                      tooltip: 'Hapus tanggal',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _due = null),
                    ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _due ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _due = d);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  if (await confirmDialog(
                    context,
                    title: 'Hapus ide konten?',
                    message: 'Ide beserta aset, jadwal, dan publikasinya disembunyikan.',
                    ok: 'Hapus',
                    danger: true,
                  )) {
                    await ref.read(kontenRepositoryProvider).deleteIdea(widget.ideaId!);
                    if (context.mounted) context.go('/konten');
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus ide'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
