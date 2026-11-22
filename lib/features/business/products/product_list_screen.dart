import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/attachment_image.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../widgets/form_fields.dart';

const productKindLabels = {'barang': 'Barang', 'jasa': 'Jasa', 'digital': 'Digital'};

/// Daftar produk/jasa. Mode [pickMode] mengembalikan Product yang dipilih (untuk transaksi).
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key, this.pickMode = false});
  final bool pickMode;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _kind;
  late Stream<List<Product>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _makeStream();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Stream<List<Product>> _makeStream() => ref.read(produkRepositoryProvider).watchAll(search: _query);

  void _setQuery(String q) => setState(() {
    _query = q;
    _stream = _makeStream();
  });

  Future<void> _scan() async {
    final code = await BarcodeScannerPage.scan(context);
    if (code == null || !mounted) return;
    final p = await ref.read(produkRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      final add = await confirmDialog(
        context,
        title: 'Barcode belum terdaftar',
        message: 'Barcode $code belum ada. Tambah produk baru dengan barcode ini?',
        ok: 'Tambah',
      );
      if (add && mounted) context.push('/usaha/produk/baru', extra: code);
      return;
    }
    _open(p);
  }

  void _open(Product p) {
    if (widget.pickMode) {
      context.pop(p);
    } else {
      context.push('/usaha/produk/${p.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'Pilih produk/jasa' : 'Produk & Jasa'),
        actions: [
          IconButton(tooltip: 'Pindai barcode', icon: const Icon(Icons.qr_code_scanner), onPressed: _scan),
          if (!widget.pickMode)
            IconButton(
              tooltip: 'Kategori',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => context.push('/usaha/kategori'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await context.push<String>('/usaha/produk/baru');
          if (id != null && widget.pickMode && context.mounted) {
            final p = await ref.read(produkRepositoryProvider).getById(id);
            if (p != null && context.mounted) context.pop(p);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: _setQuery,
              decoration: InputDecoration(
                hintText: 'Cari nama, SKU, atau barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _setQuery('');
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final k in [null, ...productKindLabels.keys])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(k == null ? 'Semua' : productKindLabels[k]!),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!.where((p) => _kind == null || p.kind == _kind).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _query.isEmpty
                            ? 'Belum ada produk/jasa.\nKetuk "Tambah" untuk membuat yang pertama.'
                            : 'Tidak ada yang cocok dengan "$_query".',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 80),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final low = p.trackStock && p.stock <= p.minStock;
                    return ListTile(
                      leading: AttachmentImage(
                        p.imagePath,
                        fallback: p.kind == 'jasa'
                            ? Icons.handyman_outlined
                            : p.kind == 'digital'
                            ? Icons.cloud_download_outlined
                            : Icons.inventory_2_outlined,
                      ),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        [
                          productKindLabels[p.kind],
                          if (p.sku != null && p.sku!.isNotEmpty) p.sku,
                          if (!p.isActive) 'nonaktif',
                        ].join(' • '),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Fmt.rupiah(p.sellPrice), style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (p.trackStock)
                            Text(
                              'Stok ${Fmt.number(p.stock)} ${p.unit}',
                              style: TextStyle(fontSize: 12, color: low ? scheme.error : null),
                            ),
                        ],
                      ),
                      onTap: () => _open(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
