import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/repositories/hutang_repository.dart';
import '../../providers/app_providers.dart';

final _debtSummaryProvider = StreamProvider.autoDispose<List<DebtRow>>(
  (ref) => ref.watch(hutangRepositoryProvider).watchDebts(),
);

class BusinessHomeScreen extends ConsumerWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final debts = ref.watch(_debtSummaryProvider).value ?? const [];
    final receivable = debts.where((d) => d.isReceivable).fold<double>(0, (s, d) => s + d.remaining);
    final payable = debts.where((d) => !d.isReceivable).fold<double>(0, (s, d) => s + d.remaining);

    Widget action(IconData icon, String label, String route, {Color? color}) => Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color ?? scheme.primary),
              const SizedBox(height: 6),
              Flexible(
                child: Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Usaha')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/usaha/transaksi/baru?jenis=sale'),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Penjualan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => context.push('/usaha/transaksi/baru?jenis=purchase'),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Pembelian'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/usaha/hutang-piutang'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Piutang (belum dibayar pelanggan)'),
                          Text(
                            Fmt.rupiah(receivable),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hutang (ke supplier)'),
                          Text(
                            Fmt.rupiah(payable),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scheme.error),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              action(Icons.receipt_long_outlined, 'Riwayat transaksi', '/usaha/transaksi'),
              action(Icons.account_balance_wallet_outlined, 'Hutang & piutang', '/usaha/hutang-piutang'),
              action(Icons.inventory_2_outlined, 'Produk & jasa', '/usaha/produk'),
              action(Icons.people_outline, 'Pelanggan', '/usaha/pelanggan'),
              action(Icons.local_shipping_outlined, 'Supplier', '/usaha/supplier'),
              action(Icons.category_outlined, 'Kategori', '/usaha/kategori'),
              action(Icons.bar_chart_outlined, 'Laporan', '/laporan'),
              action(Icons.sticky_note_2_outlined, 'Catatan', '/catatan'),
              action(Icons.settings_outlined, 'Pengaturan', '/lainnya'),
            ],
          ),
        ],
      ),
    );
  }
}
