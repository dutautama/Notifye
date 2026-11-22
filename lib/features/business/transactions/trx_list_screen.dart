import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/repositories/transaksi_repository.dart';
import '../../../providers/app_providers.dart';
import 'trx_labels.dart';

class TrxListScreen extends ConsumerStatefulWidget {
  const TrxListScreen({super.key});

  @override
  ConsumerState<TrxListScreen> createState() => _TrxListScreenState();
}

class _TrxListScreenState extends ConsumerState<TrxListScreen> {
  String _filter = 'all'; // all | sale | purchase | unpaid | cancelled
  String _search = '';
  late Stream<List<TrxListRow>> _stream = _make();

  Stream<List<TrxListRow>> _make() {
    final repo = ref.read(transaksiRepositoryProvider);
    return switch (_filter) {
      'sale' || 'purchase' => repo.watchList(type: _filter, search: _search),
      'unpaid' => repo.watchList(unpaidOnly: true, search: _search),
      'cancelled' => repo.watchList(includeDeleted: true, search: _search)
          .map((l) => l.where((r) => r.trx.deletedAt != null).toList()),
      _ => repo.watchList(search: _search),
    };
  }

  void _update(VoidCallback fn) => setState(() {
        fn();
        _stream = _make();
      });

  @override
  Widget build(BuildContext context) {
    const filters = {
      'all': 'Semua',
      'sale': 'Penjualan',
      'purchase': 'Pembelian',
      'unpaid': 'Belum lunas',
      'cancelled': 'Dibatalkan',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat transaksi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/usaha/transaksi/baru?jenis=sale'),
        icon: const Icon(Icons.add),
        label: const Text('Penjualan'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            onChanged: (v) => _update(() => _search = v),
            decoration: const InputDecoration(hintText: 'Cari nomor atau nama', prefixIcon: Icon(Icons.search)),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final e in filters.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => _update(() => _filter = e.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<TrxListRow>>(
            stream: _stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              if (list.isEmpty) return const Center(child: Text('Belum ada transaksi.'));
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = list[i];
                  final isSale = r.trx.type == 'sale';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(isSale ? Icons.arrow_upward : Icons.arrow_downward,
                          color: isSale ? Colors.green.shade700 : Colors.blue.shade700),
                    ),
                    title: Text('${r.trx.number} • ${r.partyName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      Text(Fmt.date(r.trx.trxDate)),
                      const SizedBox(width: 8),
                      TrxStatusChip(r.trx.status, cancelled: r.trx.deletedAt != null),
                    ]),
                    trailing: Text(Fmt.rupiah(r.trx.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => context.push('/usaha/transaksi/${r.trx.id}'),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
