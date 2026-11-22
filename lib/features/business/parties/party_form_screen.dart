import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/validators.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/form_fields.dart';
import 'party_list_screen.dart';

class PartyFormScreen extends ConsumerStatefulWidget {
  const PartyFormScreen({super.key, required this.kind, this.partyId});
  final PartyKind kind;
  final String? partyId;

  @override
  ConsumerState<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends ConsumerState<PartyFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.partyId != null;
  bool get _isCustomer => widget.kind == PartyKind.customer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final repo = ref.read(pelangganRepositoryProvider);
      if (_isCustomer) {
        final c = await repo.getCustomer(widget.partyId!);
        if (c != null) _fill(c.name, c.phone, c.email, c.address, c.notes);
      } else {
        final s = await repo.getSupplier(widget.partyId!);
        if (s != null) _fill(s.name, s.phone, s.email, s.address, s.notes);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(String name, String? phone, String? email, String? address, String? notes) {
    _name.text = name;
    _phone.text = phone ?? '';
    _email.text = email ?? '';
    _address.text = address ?? '';
    _notes.text = notes ?? '';
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Value<String?> _v(TextEditingController c) => Value(c.text.trim().isEmpty ? null : c.text.trim());

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(pelangganRepositoryProvider);
      final id = _isCustomer
          ? await repo.saveCustomer(CustomersCompanion(
              id: _isEdit ? Value(widget.partyId!) : const Value.absent(),
              name: Value(_name.text.trim()),
              phone: _v(_phone),
              email: _v(_email),
              address: _v(_address),
              notes: _v(_notes),
            ))
          : await repo.saveSupplier(SuppliersCompanion(
              id: _isEdit ? Value(widget.partyId!) : const Value.absent(),
              name: Value(_name.text.trim()),
              phone: _v(_phone),
              email: _v(_email),
              address: _v(_address),
              notes: _v(_notes),
            ));
      if (mounted) {
        showSnack(context, 'Tersimpan');
        context.pop(id);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Hapus ${widget.kind.label.toLowerCase()}?',
        message: 'Kontak disembunyikan dari daftar. Transaksi lama tetap menampilkan namanya.',
        ok: 'Hapus',
        danger: true);
    if (!ok) return;
    final repo = ref.read(pelangganRepositoryProvider);
    _isCustomer ? await repo.deleteCustomer(widget.partyId!) : await repo.deleteSupplier(widget.partyId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final label = widget.kind.label;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah $label' : '$label baru'),
        actions: [
          if (_isEdit) IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama *'),
              validator: (v) => Validators.required(v, 'Nama wajib diisi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP / WhatsApp', hintText: '08xxxxxxxxxx'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v == null || v.trim().isEmpty ? null : Validators.email(v),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat')),
            const SizedBox(height: 16),
            TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan')),
            if (_isEdit) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  if (WhatsAppService.normalizePhone(_phone.text) != null)
                    ActionChip(
                      avatar: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: () => WhatsAppService.send(phone: _phone.text, message: 'Halo ${_name.text},'),
                    ),
                  if (_phone.text.trim().isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Telepon'),
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: _phone.text.trim())),
                    ),
                  if (_email.text.trim().isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Email'),
                      onPressed: () => launchUrl(Uri(scheme: 'mailto', path: _email.text.trim())),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
