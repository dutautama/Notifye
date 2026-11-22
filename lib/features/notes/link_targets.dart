import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../data/repositories/catatan_repository.dart';
import '../../providers/app_providers.dart';

/// Metadata tampilan per jenis tautan: label, ikon, rute detail.
class LinkTargetInfo {
  const LinkTargetInfo(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String Function(String id) route;
}

final linkTargets = <String, LinkTargetInfo>{
  LinkType.product: LinkTargetInfo('Produk/jasa', Icons.inventory_2_outlined, (id) => '/usaha/produk/$id'),
  LinkType.customer: LinkTargetInfo('Pelanggan', Icons.person_outline, (id) => '/usaha/pelanggan/$id'),
  LinkType.supplier: LinkTargetInfo('Supplier', Icons.local_shipping_outlined, (id) => '/usaha/supplier/$id'),
  LinkType.transaction: LinkTargetInfo('Transaksi', Icons.receipt_long_outlined, (id) => '/usaha/transaksi/$id'),
  LinkType.contentIdea: LinkTargetInfo('Ide konten', Icons.lightbulb_outline, (id) => '/konten/ide/$id'),
  LinkType.watchlistItem: LinkTargetInfo('Koleksi', Icons.menu_book_outlined, (id) => '/koleksi/$id'),
};

/// Satu pilihan di pemilih entitas.
class PickOption {
  const PickOption(this.id, this.title, this.subtitle);
  final String id;
  final String title;
  final String subtitle;
}

/// Sumber data pilihan per jenis entitas.
Stream<List<PickOption>> pickOptions(WidgetRef ref, String type, String search) {
  final s = search.trim().toLowerCase();
  bool hit(String v) => s.isEmpty || v.toLowerCase().contains(s);
  switch (type) {
    case LinkType.product:
      return ref.read(produkRepositoryProvider).watchAll(search: search, includeInactive: true).map(
          (l) => [for (final p in l) PickOption(p.id, p.name, Fmt.rupiah(p.sellPrice))]);
    case LinkType.customer:
      return ref.read(pelangganRepositoryProvider).watchCustomers(search: search).map(
          (l) => [for (final c in l) PickOption(c.id, c.name, c.phone ?? '')]);
    case LinkType.supplier:
      return ref.read(pelangganRepositoryProvider).watchSuppliers(search: search).map(
          (l) => [for (final c in l) PickOption(c.id, c.name, c.phone ?? '')]);
    case LinkType.transaction:
      return ref.read(transaksiRepositoryProvider).watchList(search: search, limit: 100).map((l) => [
            for (final r in l)
              PickOption(r.trx.id, '${r.trx.number} • ${r.partyName}', '${Fmt.date(r.trx.trxDate)} • ${Fmt.rupiah(r.trx.total)}'),
          ]);
    case LinkType.contentIdea:
      return ref.read(kontenRepositoryProvider).watchIdeas().map(
          (l) => [for (final i in l) if (hit(i.title)) PickOption(i.id, i.title, i.status)]);
    case LinkType.watchlistItem:
      return ref.read(koleksiRepositoryProvider).watchItems().map(
          (l) => [for (final i in l) if (hit(i.title)) PickOption(i.id, i.title, i.creator ?? i.type)]);
  }
  return Stream.value(const []);
}

/// Bottom sheet: pilih jenis entitas, lalu pilih datanya. Mengembalikan (jenis, id).
Future<(String, String)?> pickLinkTarget(BuildContext context, {List<String>? types}) async {
  final allowed = types ?? LinkType.all;
  final type = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const ListTile(title: Text('Tautkan ke…', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final t in allowed)
          ListTile(
            leading: Icon(linkTargets[t]!.icon),
            title: Text(linkTargets[t]!.label),
            onTap: () => Navigator.pop(ctx, t),
          ),
      ]),
    ),
  );
  if (type == null || !context.mounted) return null;
  final id = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => _EntityPickerPage(type: type)),
  );
  return id == null ? null : (type, id);
}

class _EntityPickerPage extends ConsumerStatefulWidget {
  const _EntityPickerPage({required this.type});
  final String type;

  @override
  ConsumerState<_EntityPickerPage> createState() => _EntityPickerPageState();
}

class _EntityPickerPageState extends ConsumerState<_EntityPickerPage> {
  String _search = '';
  late Stream<List<PickOption>> _stream = pickOptions(ref, widget.type, '');

  @override
  Widget build(BuildContext context) {
    final info = linkTargets[widget.type]!;
    return Scaffold(
      appBar: AppBar(title: Text('Pilih ${info.label.toLowerCase()}')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() {
              _search = v;
              _stream = pickOptions(ref, widget.type, v);
            }),
            decoration: const InputDecoration(hintText: 'Cari', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PickOption>>(
            stream: _stream,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              if (list.isEmpty) {
                return Center(child: Text(_search.isEmpty ? 'Belum ada data.' : 'Tidak ditemukan.'));
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => ListTile(
                  leading: Icon(info.icon),
                  title: Text(list[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: list[i].subtitle.isEmpty ? null : Text(list[i].subtitle),
                  onTap: () => Navigator.pop(context, list[i].id),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
