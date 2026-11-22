import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../providers/app_providers.dart';

/// Jenis kontak: pelanggan atau supplier.
enum PartyKind {
  customer('Pelanggan', 'pelanggan', Icons.person_outline),
  supplier('Supplier', 'supplier', Icons.local_shipping_outlined);

  const PartyKind(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

/// Baris kontak yang seragam untuk pelanggan & supplier.
class PartyRow {
  const PartyRow(this.id, this.name, this.phone, this.email, this.address, this.notes);
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

Stream<List<PartyRow>> watchParties(WidgetRef ref, PartyKind kind, String search) {
  final repo = ref.read(pelangganRepositoryProvider);
  return kind == PartyKind.customer
      ? repo
            .watchCustomers(search: search)
            .map((l) => [for (final c in l) PartyRow(c.id, c.name, c.phone, c.email, c.address, c.notes)])
      : repo
            .watchSuppliers(search: search)
            .map((l) => [for (final s in l) PartyRow(s.id, s.name, s.phone, s.email, s.address, s.notes)]);
}

/// Daftar pelanggan/supplier. [pickMode] mengembalikan PartyRow terpilih.
class PartyListScreen extends ConsumerStatefulWidget {
  const PartyListScreen({super.key, required this.kind, this.pickMode = false});
  final PartyKind kind;
  final bool pickMode;

  @override
  ConsumerState<PartyListScreen> createState() => _PartyListScreenState();
}

class _PartyListScreenState extends ConsumerState<PartyListScreen> {
  String _query = '';
  late Stream<List<PartyRow>> _stream = watchParties(ref, widget.kind, '');

  @override
  Widget build(BuildContext context) {
    final k = widget.kind;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Pilih ${k.label.toLowerCase()}' : k.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await context.push<String>('/usaha/${k.path}/baru');
          if (id != null && widget.pickMode && context.mounted) {
            final list = await watchParties(ref, k, '').first;
            final row = list.where((p) => p.id == id).firstOrNull;
            if (row != null && context.mounted) context.pop(row);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (q) => setState(() {
                _query = q;
                _stream = watchParties(ref, k, q);
              }),
              decoration: const InputDecoration(hintText: 'Cari nama atau nomor HP', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PartyRow>>(
              stream: _stream,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty ? 'Belum ada ${k.label.toLowerCase()}.' : 'Tidak ada yang cocok dengan "$_query".',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(p.name.characters.first.toUpperCase())),
                      title: Text(p.name),
                      subtitle: Text(p.phone ?? p.email ?? '-'),
                      onTap: () => widget.pickMode ? context.pop(p) : context.push('/usaha/${k.path}/${p.id}'),
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
