import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/repositories/invoice_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/attachment_service.dart';
import '../../../services/documents/escpos.dart';
import '../../../services/documents/invoice_pdf.dart';
import '../../../services/printer_service.dart';
import '../../../services/share_service.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/form_fields.dart';
import '../../../widgets/section_card.dart';
import 'trx_labels.dart';

class TrxDetailScreen extends ConsumerStatefulWidget {
  const TrxDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  ConsumerState<TrxDetailScreen> createState() => _TrxDetailScreenState();
}

class _TrxDetailScreenState extends ConsumerState<TrxDetailScreen> {
  late final Stream<InvoiceData?> _stream = ref.read(invoiceRepositoryProvider).watchInvoiceData(widget.transactionId);
  bool _busy = false;

  Future<void> _guard(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } on PrinterException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf(InvoiceData d) => _guard(() async {
    final logo = d.profile.logoPath == null ? null : await AttachmentService.fileFor(d.profile.logoPath!);
    final bytes = await buildInvoicePdf(d, logoFile: logo);
    final file = await ShareService.saveTemp('${d.trx.number}.pdf', bytes);
    final party = d.customer?.name ?? d.supplier?.name;
    await ShareService.shareFile(
      file,
      mime: 'application/pdf',
      subject: '${d.trx.type == 'sale' ? 'Invoice' : 'PO'} ${d.trx.number} - ${d.profile.name}',
      text:
          '${party == null ? '' : 'Halo $party, '}berikut ${d.trx.type == 'sale' ? 'invoice' : 'pesanan'} '
          '${d.trx.number} sebesar ${Fmt.rupiah(d.trx.total)}.',
    );
  });

  Future<void> _print(InvoiceData d) => _guard(() async {
    final printer = ref.read(printerServiceProvider);
    await printer.printBytes(buildReceipt(d, width: await printer.charsPerLine()));
    if (mounted) showSnack(context, 'Struk dikirim ke printer');
  });

  Future<void> _remind(InvoiceData d) async {
    final remaining = d.trx.total - d.trx.paidAmount;
    final ok = await WhatsAppService.send(
      phone: d.customer?.phone,
      message:
          'Halo ${d.customer?.name ?? ''}, tagihan ${d.trx.number} sebesar ${Fmt.rupiah(remaining)}'
          '${d.trx.dueDate == null ? '' : ' jatuh tempo ${Fmt.date(d.trx.dueDate)}'}.'
          '${d.profile.bankInfo == null ? '' : '\nPembayaran ke: ${d.profile.bankInfo}'}\nTerima kasih 🙏',
    );
    if (!ok && mounted) showSnack(context, 'Tidak dapat membuka WhatsApp');
  }

  Future<void> _addPayment(InvoiceData d) async {
    final remaining = d.trx.total - d.trx.paidAmount;
    final amount = TextEditingController(text: ThousandsInputFormatter.format(remaining));
    var method = 'tunai';
    var date = DateTime.now();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Catat pembayaran'),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sisa: ${Fmt.rupiah(remaining)}'),
                const SizedBox(height: 12),
                MoneyField(controller: amount, label: 'Jumlah', required: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Metode'),
                  items: [
                    for (final e in paymentMethodLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => method = v ?? 'tunai',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(Fmt.date(date)),
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setD(() => date = p);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () {
                if (key.currentState!.validate() && MoneyField.read(amount) > 0) Navigator.pop(ctx, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final value = MoneyField.read(amount);
    amount.dispose();
    if (ok != true) return;
    if (value > remaining + 0.5 && mounted) {
      final go = await confirmDialog(
        context,
        title: 'Melebihi sisa tagihan',
        message: 'Jumlah ${Fmt.rupiah(value)} lebih besar dari sisa ${Fmt.rupiah(remaining)}. Tetap simpan?',
        ok: 'Simpan',
      );
      if (!go) return;
    }
    await _guard(
      () => ref
          .read(transaksiRepositoryProvider)
          .addPayment(widget.transactionId, amount: value, method: method, date: date),
    );
  }

  Future<void> _cancelOrRestore(InvoiceData d) async {
    final cancelled = d.trx.deletedAt != null;
    final ok = await confirmDialog(
      context,
      title: cancelled ? 'Pulihkan transaksi?' : 'Batalkan transaksi?',
      message: cancelled
          ? 'Transaksi aktif kembali dan stok disesuaikan lagi.'
          : 'Transaksi ditandai batal, stok dikembalikan, dan tidak dihitung di laporan. Bisa dipulihkan.',
      ok: cancelled ? 'Pulihkan' : 'Batalkan transaksi',
      danger: !cancelled,
    );
    if (!ok) return;
    final repo = ref.read(transaksiRepositoryProvider);
    await _guard(() => cancelled ? repo.restore(d.trx.id) : repo.softDelete(d.trx.id));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<InvoiceData?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final d = snap.data;
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Transaksi tidak ditemukan.')),
          );
        }
        final t = d.trx;
        final cancelled = t.deletedAt != null;
        final remaining = t.total - t.paidAmount;
        final party = d.customer?.name ?? d.supplier?.name ?? 'Umum';
        return Scaffold(
          appBar: AppBar(
            title: Text(t.number),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Lainnya',
                onSelected: (v) => v == 'cancel' ? _cancelOrRestore(d) : null,
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'cancel', child: Text(cancelled ? 'Pulihkan transaksi' : 'Batalkan transaksi')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(trxTypeLabels[t.type]!, style: Theme.of(context).textTheme.labelLarge)),
                          TrxStatusChip(t.status, cancelled: cancelled),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(Fmt.rupiah(t.total), style: Theme.of(context).textTheme.headlineSmall),
                      Text('$party • ${Fmt.date(t.trxDate)}'),
                      if (remaining > 0 && !cancelled) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Sisa: ${Fmt.rupiah(remaining)}'
                          '${t.dueDate == null ? '' : ' • jatuh tempo ${Fmt.date(t.dueDate)}'}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600),
                        ),
                      ],
                      if (t.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t.notes!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (remaining > 0 && !cancelled)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: _busy ? null : () => _addPayment(d),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Catat bayar'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _sharePdf(d),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Invoice PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _print(d),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak struk'),
                  ),
                  if (t.type == 'sale' && remaining > 0 && !cancelled && d.customer?.phone != null)
                    OutlinedButton.icon(
                      onPressed: () => _remind(d),
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Tagih via WA'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Item',
                icon: Icons.list_alt,
                child: Column(
                  children: [
                    for (final i in d.items)
                      ListTile(
                        dense: true,
                        title: Text(i.name),
                        subtitle: Text('${Fmt.number(i.qty)} × ${Fmt.rupiah(i.price)}'),
                        trailing: Text(Fmt.rupiah(i.subtotal)),
                      ),
                    const Divider(),
                    _line('Subtotal', Fmt.rupiah(t.subtotal)),
                    if (t.discount > 0) _line('Diskon', '- ${Fmt.rupiah(t.discount)}'),
                    if (t.tax > 0) _line('Pajak', Fmt.rupiah(t.tax)),
                    _line('Total', Fmt.rupiah(t.total), bold: true),
                    _line('Dibayar', Fmt.rupiah(t.paidAmount)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Pembayaran',
                icon: Icons.payments_outlined,
                child: d.payments.isEmpty
                    ? const EmptyHint('Belum ada pembayaran.')
                    : Column(
                        children: [
                          for (final p in d.payments)
                            ListTile(
                              dense: true,
                              title: Text(Fmt.rupiah(p.amount)),
                              subtitle: Text('${Fmt.date(p.payDate)} • ${paymentMethodLabels[p.method] ?? p.method}'),
                              trailing: cancelled
                                  ? null
                                  : IconButton(
                                      tooltip: 'Hapus pembayaran',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        if (await confirmDialog(
                                          context,
                                          title: 'Hapus pembayaran?',
                                          message: 'Sisa tagihan akan dihitung ulang.',
                                          ok: 'Hapus',
                                          danger: true,
                                        )) {
                                          await _guard(() => ref.read(transaksiRepositoryProvider).deletePayment(p.id));
                                        }
                                      },
                                    ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _line(String a, String b, {bool bold = false}) {
    final s = TextStyle(fontWeight: bold ? FontWeight.bold : null);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(a, style: s)),
          Text(b, style: s),
        ],
      ),
    );
  }
}
