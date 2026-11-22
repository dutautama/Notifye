import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatters.dart';
import '../../../data/repositories/hutang_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../services/whatsapp_service.dart';
import '../../../widgets/form_fields.dart';

/// Hutang & piutang (transaksi belum lunas), dikelompokkan per tab.
class DebtListScreen extends ConsumerWidget {
  const DebtListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hutang & Piutang'),
          bottom: const TabBar(tabs: [Tab(text: 'Piutang'), Tab(text: 'Hutang')]),
        ),
        body: const TabBarView(children: [_DebtTab(kind: 'piutang'), _DebtTab(kind: 'hutang')]),
      ),
    );
  }
}

class _DebtTab extends ConsumerWidget {
  const _DebtTab({required this.kind});
  final String kind;

  Future<void> _remind(BuildContext context, DebtRow d) async {
    final due = d.dueDate == null ? '' : ' yang jatuh tempo ${Fmt.date(d.dueDate)}';
    final ok = await WhatsAppService.send(
      phone: d.partyPhone,
      message: 'Halo ${d.partyName}, kami ingin mengingatkan tagihan ${d.number} '
          'sebesar ${Fmt.rupiah(d.remaining)}$due. Terima kasih 🙏',
    );
    if (!ok && context.mounted) showSnack(context, 'Tidak dapat membuka WhatsApp');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<DebtRow>>(
      stream: ref.watch(hutangRepositoryProvider).watchDebts(kind: kind),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        final total = list.fold<double>(0, (s, d) => s + d.remaining);
        final overdue = list.where((d) => d.isOverdue(today)).fold<double>(0, (s, d) => s + d.remaining);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total ${kind == 'piutang' ? 'piutang' : 'hutang'} (${list.length})'),
                        Text(Fmt.rupiah(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    if (overdue > 0)
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Terlambat', style: TextStyle(color: scheme.error)),
                        Text(Fmt.rupiah(overdue),
                            style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold)),
                      ]),
                  ]),
                ),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(kind == 'piutang' ? 'Tidak ada piutang. 🎉' : 'Tidak ada hutang.',
                    textAlign: TextAlign.center),
              ),
            for (final d in list)
              ListTile(
                title: Text('${d.partyName} • ${d.number}'),
                subtitle: Text(
                  d.dueDate == null
                      ? 'Tanpa jatuh tempo • ${Fmt.date(d.trxDate)}'
                      : '${d.isOverdue(today) ? 'TERLAMBAT sejak' : 'Jatuh tempo'} ${Fmt.date(d.dueDate)}',
                  style: d.isOverdue(today) ? TextStyle(color: scheme.error) : null,
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Fmt.rupiah(d.remaining), style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('dari ${Fmt.rupiah(d.total)}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  if (d.isReceivable)
                    IconButton(
                        tooltip: 'Ingatkan via WhatsApp',
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: () => _remind(context, d)),
                ]),
                onTap: () => context.push('/usaha/transaksi/${d.transactionId}'),
              ),
          ],
        );
      },
    );
  }
}
