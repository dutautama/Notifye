import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../providers/app_providers.dart';
import '../../services/report_service.dart';
import '../../services/share_service.dart';
import '../../widgets/error_view.dart';
import '../../widgets/form_fields.dart';
import '../../widgets/section_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/two_column_grid.dart';

enum _Preset { today, week, month, lastMonth, year, custom }

const _presetLabels = {
  _Preset.today: 'Hari ini',
  _Preset.week: '7 hari',
  _Preset.month: 'Bulan ini',
  _Preset.lastMonth: 'Bulan lalu',
  _Preset.year: 'Tahun ini',
  _Preset.custom: 'Pilih tanggal',
};

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Preset _preset = _Preset.month;
  late DateTimeRange _range = _rangeFor(_Preset.month);
  late Future<ReportData> _future = _load();
  bool _exporting = false;

  static DateTimeRange _rangeFor(_Preset p) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return switch (p) {
      _Preset.today => DateTimeRange(start: today, end: today),
      _Preset.week => DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      _Preset.month => DateTimeRange(start: DateTime(n.year, n.month, 1), end: today),
      _Preset.lastMonth => DateTimeRange(start: DateTime(n.year, n.month - 1, 1), end: DateTime(n.year, n.month, 0)),
      _Preset.year => DateTimeRange(start: DateTime(n.year, 1, 1), end: today),
      _Preset.custom => DateTimeRange(start: today, end: today),
    };
  }

  Future<ReportData> _load() => ref.read(reportServiceProvider).load(_range.start, _range.end);

  Future<void> _choose(_Preset p) async {
    var range = _rangeFor(p);
    if (p == _Preset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange: _range,
      );
      if (picked == null) return;
      range = picked;
    }
    setState(() {
      _preset = p;
      _range = range;
      _future = _load();
    });
  }

  Future<void> _export(ReportData d, bool excel) async {
    setState(() => _exporting = true);
    try {
      final stamp = DateFormat('yyyyMMdd').format(d.from);
      final stamp2 = DateFormat('yyyyMMdd').format(d.to);
      final name = 'Laporan-UsahaKonten-$stamp-$stamp2.${excel ? 'xlsx' : 'pdf'}';
      final bytes = excel ? buildReportXlsx(d) : await buildReportPdf(d);
      final file = await ShareService.saveTemp(name, bytes);
      await ShareService.shareFile(
        file,
        mime: excel ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'application/pdf',
        subject: 'Laporan ${d.businessName} ${d.periodLabel}',
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Gagal membuat laporan: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<ReportData>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
            final d = snap.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final p in _Preset.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          child: ChoiceChip(
                            label: Text(_presetLabels[p]!),
                            selected: _preset == p,
                            onSelected: (_) => _choose(p),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '${Fmt.date(_range.start)} – ${Fmt.date(_range.end)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (d == null)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exporting ? null : () => _export(d, true),
                          icon: const Icon(Icons.table_view),
                          label: const Text('Excel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _exporting ? null : () => _export(d, false),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (_exporting) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                  const SizedBox(height: 16),
                  _Kpis(d: d),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Item terlaris',
                    icon: Icons.emoji_events_outlined,
                    child: d.soldItems.isEmpty
                        ? const EmptyHint('Belum ada penjualan di periode ini.')
                        : Column(
                            children: [
                              for (final i in d.soldItems.take(10))
                                ListTile(
                                  dense: true,
                                  title: Text(i.name),
                                  subtitle: Text('Terjual ${Fmt.number(i.qty)}'),
                                  trailing: Text(Fmt.rupiah(i.revenue)),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Penjualan (${d.sales.length})',
                    icon: Icons.receipt_long_outlined,
                    child: d.sales.isEmpty
                        ? const EmptyHint('Tidak ada transaksi.')
                        : Column(
                            children: [
                              for (final r in d.sales.reversed.take(30))
                                ListTile(
                                  dense: true,
                                  title: Text('${r.trx.number} • ${r.partyName}'),
                                  subtitle: Text(Fmt.date(r.trx.trxDate)),
                                  trailing: Text(Fmt.rupiah(r.trx.total)),
                                  onTap: () => context.push('/usaha/transaksi/${r.trx.id}'),
                                ),
                              if (d.sales.length > 30) const EmptyHint('Daftar lengkap ada di file Excel/PDF.'),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Stok (${d.products.length} produk)',
                    icon: Icons.inventory_2_outlined,
                    child: d.products.isEmpty
                        ? const EmptyHint('Belum ada produk yang dilacak stoknya.')
                        : Column(
                            children: [
                              for (final p in (d.products.toList()..sort((a, b) => a.stock.compareTo(b.stock))).take(
                                15,
                              ))
                                ListTile(
                                  dense: true,
                                  title: Text(p.name),
                                  subtitle: Text('Nilai ${Fmt.rupiah(p.stock * p.buyPrice)}'),
                                  trailing: Text(
                                    '${Fmt.number(p.stock)} ${p.unit}',
                                    style: TextStyle(
                                      color: p.stock <= p.minStock ? Theme.of(context).colorScheme.error : null,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Performa konten',
                    icon: Icons.insights_outlined,
                    child: d.content.isEmpty
                        ? const EmptyHint('Belum ada publikasi di periode ini.')
                        : Column(
                            children: [
                              for (final c in d.content.take(10))
                                ListTile(
                                  dense: true,
                                  title: Text(c.title),
                                  subtitle: Text(
                                    'Reach ${Fmt.compact(c.reach)} • ER ${c.engagementRate.toStringAsFixed(1)}%'
                                    '${c.leads > 0 ? ' • ${c.leads} leads' : ''}',
                                  ),
                                  onTap: () => context.push('/konten/ide/${c.ideaId}'),
                                ),
                            ],
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.d});
  final ReportData d;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        label: 'Omzet',
        value: Fmt.rupiah(d.omzet),
        caption: '${d.sales.length} transaksi',
        icon: Icons.trending_up,
      ),
      StatCard(label: 'Uang diterima', value: Fmt.rupiah(d.received), icon: Icons.payments_outlined),
      StatCard(
        label: 'Pembelian',
        value: Fmt.rupiah(d.purchaseTotal),
        caption: '${d.purchases.length} transaksi',
        icon: Icons.shopping_cart_outlined,
      ),
      StatCard(
        label: 'Nilai stok',
        value: Fmt.rupiah(d.stockValue),
        caption: '${d.lowStockCount} menipis',
        icon: Icons.inventory_outlined,
      ),
      StatCard(
        label: 'Piutang',
        value: Fmt.rupiah(d.receivable),
        icon: Icons.call_received,
        color: Colors.orange.shade700,
      ),
      StatCard(
        label: 'Hutang',
        value: Fmt.rupiah(d.payable),
        icon: Icons.call_made,
        color: Theme.of(context).colorScheme.error,
      ),
    ];
    return TwoColumnGrid(children: cards);
  }
}
