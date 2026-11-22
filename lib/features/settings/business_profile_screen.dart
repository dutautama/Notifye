import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/validators.dart';
import '../../data/database/app_database.dart';
import '../../providers/app_providers.dart';
import '../../services/attachment_service.dart';
import '../../widgets/attachment_image.dart';
import '../../widgets/form_fields.dart';

/// Profil usaha: tampil di invoice & struk.
class BusinessProfileScreen extends ConsumerStatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  ConsumerState<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends ConsumerState<BusinessProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _invPrefix = TextEditingController();
  final _poPrefix = TextEditingController();
  final _footer = TextEditingController();
  final _bank = TextEditingController();
  final _tax = TextEditingController();
  String? _logo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ref.read(invoiceRepositoryProvider).getProfile().then((p) {
      _name.text = p.name;
      _address.text = p.address ?? '';
      _phone.text = p.phone ?? '';
      _email.text = p.email ?? '';
      _invPrefix.text = p.invoicePrefix;
      _poPrefix.text = p.purchasePrefix;
      _footer.text = p.invoiceFooter ?? '';
      _bank.text = p.bankInfo ?? '';
      _tax.text = p.taxPercent == 0 ? '' : QtyField.format(p.taxPercent);
      _logo = p.logoPath;
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _email, _invPrefix, _poPrefix, _footer, _bank, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  Value<String?> _v(TextEditingController c) => Value(c.text.trim().isEmpty ? null : c.text.trim());

  String? _prefix(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Wajib diisi';
    if (!RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(s)) return 'Huruf/angka, maks. 8';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(invoiceRepositoryProvider)
        .updateProfile(
          BusinessProfileCompanion(
            name: Value(_name.text.trim()),
            address: _v(_address),
            phone: _v(_phone),
            email: _v(_email),
            invoicePrefix: Value(_invPrefix.text.trim().toUpperCase()),
            purchasePrefix: Value(_poPrefix.text.trim().toUpperCase()),
            invoiceFooter: _v(_footer),
            bankInfo: _v(_bank),
            taxPercent: Value(QtyField.read(_tax)),
            logoPath: Value(_logo),
          ),
        );
    if (mounted) {
      showSnack(context, 'Profil usaha tersimpan');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Usaha')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final r = await AttachmentService.pick('profil', type: FileType.image);
                  if (r != null) setState(() => _logo = r.$1);
                },
                child: AttachmentImage(_logo, size: 96, fallback: Icons.add_photo_alternate_outlined),
              ),
            ),
            const Center(child: Text('Logo (ketuk untuk memilih)')),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama usaha *'),
              validator: (v) => Validators.required(v, 'Nama usaha wajib diisi'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. HP / WhatsApp'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => v == null || v.trim().isEmpty ? null : Validators.email(v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _invPrefix,
                    decoration: const InputDecoration(labelText: 'Awalan invoice', helperText: 'mis. INV'),
                    validator: _prefix,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _poPrefix,
                    decoration: const InputDecoration(labelText: 'Awalan pembelian', helperText: 'mis. PO'),
                    validator: _prefix,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            QtyField(controller: _tax, label: 'Pajak default (%) — kosongkan jika tidak ada'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bank,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Info pembayaran',
                hintText: 'mis. BCA 1234567890 a.n. Nama',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _footer,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan kaki invoice'),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Simpan')),
          ],
        ),
      ),
    );
  }
}
