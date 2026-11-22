import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../core/validators.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../services/attachment_service.dart';
import '../../../widgets/attachment_image.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../widgets/form_fields.dart';
import '../../../widgets/section_card.dart';
import 'product_list_screen.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId, this.initialBarcode});
  final String? productId;
  final String? initialBarcode;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'pcs');
  final _sell = TextEditingController();
  final _buy = TextEditingController();
  final _stock = TextEditingController();
  final _minStock = TextEditingController();
  final _desc = TextEditingController();
  String _kind = 'jasa';
  String? _categoryId;
  bool _trackStock = false;
  bool _active = true;
  String? _imagePath;
  Product? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    _barcode.text = widget.initialBarcode ?? '';
    if (widget.initialBarcode != null) {
      _kind = 'barang';
      _trackStock = true;
    }
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      final p = await ref.read(produkRepositoryProvider).getById(widget.productId!);
      if (p != null) {
        _existing = p;
        _name.text = p.name;
        _sku.text = p.sku ?? '';
        _barcode.text = p.barcode ?? '';
        _unit.text = p.unit;
        _sell.text = ThousandsInputFormatter.format(p.sellPrice);
        _buy.text = ThousandsInputFormatter.format(p.buyPrice);
        _stock.text = QtyField.format(p.stock);
        _minStock.text = QtyField.format(p.minStock);
        _desc.text = p.description ?? '';
        _kind = p.kind;
        _categoryId = p.categoryId;
        _trackStock = p.trackStock;
        _active = p.isActive;
        _imagePath = p.imagePath;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _unit, _sell, _buy, _stock, _minStock, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = ProductsCompanion(
        id: _isEdit ? Value(widget.productId!) : const Value.absent(),
        name: Value(_name.text.trim()),
        kind: Value(_kind),
        categoryId: Value(_categoryId),
        sku: Value(_nullIfEmpty(_sku)),
        barcode: Value(_nullIfEmpty(_barcode)),
        unit: Value(_unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim()),
        sellPrice: Value(MoneyField.read(_sell)),
        buyPrice: Value(MoneyField.read(_buy)),
        trackStock: Value(_trackStock),
        stock: Value(_isEdit ? 0 : QtyField.read(_stock)),
        minStock: Value(QtyField.read(_minStock)),
        description: Value(_nullIfEmpty(_desc)),
        imagePath: Value(_imagePath),
        isActive: Value(_active),
      );
      final id = await ref.read(produkRepositoryProvider).save(data);
      if (!mounted) return;
      showSnack(context, 'Tersimpan');
      context.pop(id);
    } catch (e) {
      if (mounted) {
        showSnack(context,
            e.toString().contains('UNIQUE') ? 'SKU sudah dipakai produk lain.' : 'Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final r = await AttachmentService.pick('produk', type: FileType.image);
      if (r == null) return;
      final old = _imagePath;
      setState(() => _imagePath = r.$1);
      if (old != null && old != _existing?.imagePath) await AttachmentService.delete(old);
    } catch (e) {
      if (mounted) showSnack(context, e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _adjustStock() async {
    final qty = TextEditingController();
    final note = TextEditingController();
    var add = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Penyesuaian stok'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Tambah'), icon: Icon(Icons.add)),
                  ButtonSegment(value: false, label: Text('Kurangi'), icon: Icon(Icons.remove)),
                ],
                selected: {add},
                onSelectionChanged: (s) => setD(() => add = s.first),
              ),
              const SizedBox(height: 12),
              QtyField(controller: qty, label: 'Jumlah (${_unit.text})', required: true),
              const SizedBox(height: 12),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Alasan (mis. rusak, stok opname)')),
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
    final amount = QtyField.read(qty);
    if (ok == true && amount > 0) {
      await ref.read(produkRepositoryProvider).adjustStock(widget.productId!, add ? amount : -amount,
          notes: note.text.trim().isEmpty ? null : note.text.trim());
      final p = await ref.read(produkRepositoryProvider).getById(widget.productId!);
      if (mounted && p != null) {
        setState(() {
          _existing = p;
          _stock.text = QtyField.format(p.stock);
        });
        showSnack(context, 'Stok sekarang ${Fmt.number(p.stock)} ${p.unit}');
      }
    }
    qty.dispose();
    note.dispose();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Hapus produk?',
        message: 'Produk disembunyikan dari daftar. Riwayat transaksi tetap aman.',
        ok: 'Hapus',
        danger: true);
    if (!ok) return;
    await ref.read(produkRepositoryProvider).softDelete(widget.productId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cats = ref.watch(_categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah produk/jasa' : 'Produk/jasa baru'),
        actions: [
          if (_isEdit) IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(10),
                  child: AttachmentImage(_imagePath, size: 72, fallback: Icons.add_a_photo_outlined),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama *'),
                    validator: (v) => Validators.required(v, 'Nama wajib diisi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                for (final e in productKindLabels.entries) ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                if (_kind != 'barang' && !_isEdit) _trackStock = false;
                if (_kind == 'barang' && !_isEdit) _trackStock = true;
              }),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: ValueKey('cat-${cats.value?.length}'),
              initialValue: (cats.value ?? const <Category>[]).any((c) => c.id == _categoryId)
                  ? _categoryId
                  : null,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Tanpa kategori —')),
                for (final c in cats.value ?? const <Category>[])
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/usaha/kategori'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Kelola kategori'),
              ),
            ),
            Row(
              children: [
                Expanded(child: MoneyField(controller: _sell, label: 'Harga jual')),
                const SizedBox(width: 12),
                Expanded(child: MoneyField(controller: _buy, label: 'Harga modal')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU / kode')),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Satuan')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode',
                suffixIcon: IconButton(
                  tooltip: 'Pindai',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final code = await BarcodeScannerPage.scan(context);
                    if (code != null) setState(() => _barcode.text = code);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lacak stok'),
              subtitle: const Text('Stok berkurang otomatis saat terjual, bertambah saat dibeli'),
              value: _trackStock,
              onChanged: (v) => setState(() => _trackStock = v),
            ),
            if (_trackStock)
              Row(
                children: [
                  Expanded(
                    child: _isEdit
                        ? InputDecorator(
                            decoration: const InputDecoration(labelText: 'Stok saat ini'),
                            child: Text('${Fmt.number(_existing?.stock)} ${_unit.text}'),
                          )
                        : QtyField(controller: _stock, label: 'Stok awal'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: QtyField(controller: _minStock, label: 'Stok minimum')),
                ],
              ),
            if (_trackStock && _isEdit)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _adjustStock,
                  icon: const Icon(Icons.tune),
                  label: const Text('Penyesuaian stok'),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aktif dijual'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              _LinkedContent(productId: widget.productId!),
              const SizedBox(height: 12),
              _StockHistory(productId: widget.productId!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Simpan'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

final _categoriesProvider = StreamProvider.autoDispose<List<Category>>(
    (ref) => ref.watch(produkRepositoryProvider).watchCategories());

/// Relasi 2 arah: ide konten yang mempromosikan produk ini.
class _LinkedContent extends ConsumerWidget {
  const _LinkedContent({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ContentIdea>>(
      stream: ref.watch(kontenRepositoryProvider).watchIdeasForProduct(productId),
      builder: (context, snap) {
        final ideas = snap.data ?? const [];
        return SectionCard(
          title: 'Konten yang mempromosikan',
          icon: Icons.lightbulb_outline,
          child: ideas.isEmpty
              ? const EmptyHint('Belum ada. Tautkan dari halaman ide konten.')
              : Column(children: [
                  for (final i in ideas)
                    ListTile(
                      dense: true,
                      title: Text(i.title),
                      subtitle: Text('Status: ${i.status}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/konten/ide/${i.id}'),
                    ),
                ]),
        );
      },
    );
  }
}

class _StockHistory extends ConsumerWidget {
  const _StockHistory({required this.productId});
  final String productId;

  static const _reasons = {
    'penjualan': 'Penjualan',
    'pembelian': 'Pembelian',
    'penyesuaian': 'Penyesuaian',
    'batal_penjualan': 'Batal jual',
    'batal_pembelian': 'Batal beli',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<StockMovement>>(
      stream: ref.watch(produkRepositoryProvider).watchMovements(productId),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return SectionCard(
          title: 'Riwayat stok',
          icon: Icons.history,
          child: Column(children: [
            for (final m in list.take(15))
              ListTile(
                dense: true,
                title: Text(_reasons[m.reason] ?? m.reason),
                subtitle: Text([Fmt.dateTime(m.createdAt), if (m.notes != null) m.notes!].join(' • ')),
                trailing: Text(
                  '${m.qtyChange > 0 ? '+' : ''}${Fmt.number(m.qtyChange)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: m.qtyChange < 0 ? Theme.of(context).colorScheme.error : Colors.green.shade700),
                ),
              ),
          ]),
        );
      },
    );
  }
}
