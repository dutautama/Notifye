import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/transaksi_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/barcode_scanner_page.dart';
import '../../../widgets/form_fields.dart';
import '../parties/party_list_screen.dart';
import 'trx_form_logic.dart';
import 'trx_labels.dart';

/// Form transaksi baru: penjualan (sale) atau pembelian (purchase).
class TrxFormScreen extends ConsumerStatefulWidget {
  const TrxFormScreen({super.key, required this.type});
  final String type;

  @override
  ConsumerState<TrxFormScreen> createState() => _TrxFormScreenState();
}

class _TrxFormScreenState extends ConsumerState<TrxFormScreen> {
  final _items = <DraftItem>[];
  final _discount = TextEditingController();
  final _taxPct = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();
  PartyRow? _party;
  DateTime _date = DateTime.now();
  DateTime? _due;
  String _method = 'tunai';
  bool _payFull = true;
  bool _saving = false;

  bool get _isSale => widget.type == 'sale';
  PartyKind get _partyKind => _isSale ? PartyKind.customer : PartyKind.supplier;

  @override
  void initState() {
    super.initState();
    if (_isSale) {
      ref.read(invoiceRepositoryProvider).getProfile().then((p) {
        if (p.taxPercent > 0 && mounted) setState(() => _taxPct.text = QtyField.format(p.taxPercent));
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_discount, _taxPct, _paid, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  DraftTotals get _totals =>
      computeDraftTotals(_items, discount: MoneyField.read(_discount), taxPercent: QtyField.read(_taxPct));

  Future<void> _addProduct([Product? preset]) async {
    final p = preset ?? await context.push<Product>('/usaha/produk/pilih');
    if (p == null || !mounted) return;
    final price = _isSale ? p.sellPrice : p.buyPrice;
    final item = await _editItemDialog(
      DraftItem(productId: p.id, name: p.name, qty: 1, price: price, unit: p.unit, unitCost: _isSale ? p.buyPrice : price),
      stockInfo: p.trackStock ? 'Stok: ${Fmt.number(p.stock)} ${p.unit}' : null,
    );
    if (item != null) setState(() => addOrMergeItem(_items, item));
  }

  Future<void> _scan() async {
    final code = await BarcodeScannerPage.scan(context);
    if (code == null || !mounted) return;
    final p = await ref.read(produkRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (p == null) {
      showSnack(context, 'Barcode $code tidak ditemukan di daftar produk.');
    } else {
      await _addProduct(p);
    }
  }

  Future<void> _addManual() async {
    final item = await _editItemDialog(DraftItem(name: '', qty: 1, price: 0), manual: true);
    if (item != null) setState(() => _items.add(item));
  }

  Future<DraftItem?> _editItemDialog(DraftItem item, {bool manual = false, String? stockInfo}) async {
    final name = TextEditingController(text: item.name);
    final qty = TextEditingController(text: QtyField.format(item.qty));
    final price = TextEditingController(text: ThousandsInputFormatter.format(item.price));
    final cost = TextEditingController(text: ThousandsInputFormatter.format(item.unitCost ?? 0));
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(manual ? 'Item manual' : item.name),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stockInfo != null) Text(stockInfo),
              if (manual)
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nama item'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                ),
              const SizedBox(height: 12),
              QtyField(controller: qty, label: 'Jumlah (${item.unit})', required: true),
              const SizedBox(height: 12),
              MoneyField(controller: price, label: 'Harga satuan', required: true),
              if (_isSale) ...[
                const SizedBox(height: 12),
                MoneyField(
                  controller: cost,
                  label: 'Modal per unit',
                  helper: 'Untuk hitung laba. Kosongkan bila tanpa modal (jasa).',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {
              if (key.currentState!.validate() && QtyField.read(qty) > 0) Navigator.pop(ctx, true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    final result = ok == true
        ? DraftItem(
            productId: item.productId,
            name: manual ? name.text.trim() : item.name,
            qty: QtyField.read(qty),
            price: MoneyField.read(price),
            unit: item.unit,
            unitCost: _isSale ? MoneyField.read(cost) : MoneyField.read(price),
          )
        : null;
    name.dispose();
    qty.dispose();
    price.dispose();
    cost.dispose();
    return result;
  }

  Future<void> _pickParty() async {
    final p = await context.push<PartyRow>('/usaha/${_partyKind.path}/pilih');
    if (p != null) setState(() => _party = p);
  }

  Future<DateTime?> _pickDate(DateTime initial) =>
      showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));

  Future<void> _save() async {
    if (_items.isEmpty) {
      showSnack(context, 'Tambahkan minimal 1 item.');
      return;
    }
    final t = _totals;
    final paid = _payFull ? t.total : MoneyField.read(_paid).clamp(0, t.total).toDouble();
    if (!_payFull && paid < t.total && _party == null && _isSale) {
      final ok = await confirmDialog(
        context,
        title: 'Tanpa nama pelanggan?',
        message: 'Transaksi belum lunas akan menjadi piutang "Umum". Sebaiknya pilih pelanggan agar mudah ditagih.',
        ok: 'Tetap simpan',
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final trx = await ref
          .read(transaksiRepositoryProvider)
          .createTransaction(
            TrxInput(
              type: widget.type,
              items: [for (final i in _items) i.toInput()],
              trxDate: _date,
              dueDate: paid < t.total ? (_due ?? _date.add(const Duration(days: 7))) : null,
              customerId: _isSale ? _party?.id : null,
              supplierId: _isSale ? null : _party?.id,
              discount: t.discount,
              tax: t.tax,
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              initialPayment: paid,
              paymentMethod: _method,
            ),
          );
      if (!mounted) return;
      context.pushReplacement('/usaha/transaksi/${trx.id}');
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${trxTypeLabels[widget.type]} baru'),
        actions: [IconButton(tooltip: 'Pindai barcode', icon: const Icon(Icons.qr_code_scanner), onPressed: _scan)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(_partyKind.icon),
                  title: Text(_party?.name ?? '${_partyKind.label}: Umum'),
                  subtitle: Text(_party == null ? 'Ketuk untuk memilih' : (_party!.phone ?? '')),
                  trailing: _party == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: 'Hapus pilihan',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _party = null),
                        ),
                  onTap: _pickParty,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('Tanggal: ${Fmt.date(_date)}'),
                  onTap: () async {
                    final d = await _pickDate(_date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Item (${_items.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add),
                  label: const Text('Produk'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _addManual,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manual'),
                ),
              ),
            ],
          ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Belum ada item. Tambah dari daftar produk, pindai barcode, atau item manual.',
                textAlign: TextAlign.center,
              ),
            ),
          for (var i = 0; i < _items.length; i++)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text(_items[i].name),
                subtitle: Text('${QtyField.format(_items[i].qty)} ${_items[i].unit} × ${Fmt.rupiah(_items[i].price)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Fmt.rupiah(_items[i].subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      tooltip: 'Hapus item',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ],
                ),
                onTap: () async {
                  final edited = await _editItemDialog(_items[i], manual: _items[i].productId == null);
                  if (edited != null) setState(() => _items[i] = edited);
                },
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: MoneyField(controller: _discount, label: 'Diskon', onChanged: (_) => setState(() {})),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QtyField(controller: _taxPct, label: 'Pajak (%)', onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row('Subtotal', Fmt.rupiah(t.subtotal)),
                  if (t.discount > 0) _row('Diskon', '- ${Fmt.rupiah(t.discount)}'),
                  if (t.tax > 0) _row('Pajak', Fmt.rupiah(t.tax)),
                  const Divider(),
                  _row('TOTAL', Fmt.rupiah(t.total), bold: true),
                  if (_isSale && _items.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _row('Perkiraan laba', Fmt.rupiah(estimateProfit(_items, t.discount))),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_isSale ? 'Dibayar lunas sekarang' : 'Dibayar lunas ke supplier'),
            subtitle: Text(_payFull ? 'Status: Lunas' : (_isSale ? 'Sisa menjadi piutang' : 'Sisa menjadi hutang')),
            value: _payFull,
            onChanged: (v) => setState(() => _payFull = v),
          ),
          if (!_payFull) ...[
            MoneyField(
              controller: _paid,
              label: 'Dibayar sekarang (DP)',
              helper: 'Kosongkan jika belum ada pembayaran',
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text('Jatuh tempo: ${Fmt.date(_due ?? _date.add(const Duration(days: 7)))}'),
              onTap: () async {
                final d = await _pickDate(_due ?? _date.add(const Duration(days: 7)));
                if (d != null) setState(() => _due = d);
              },
            ),
          ],
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Metode pembayaran'),
            items: [for (final e in paymentMethodLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _method = v ?? 'tunai'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Text('Simpan • ${Fmt.rupiah(t.total)}'),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 18 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
