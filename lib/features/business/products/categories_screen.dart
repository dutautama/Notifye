import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/form_fields.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, [Category? c]) async {
    final ctrl = TextEditingController(text: c?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(c == null ? 'Kategori baru' : 'Ubah kategori'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama kategori'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(produkRepositoryProvider).saveCategory(id: c?.id, name: name);
    } catch (_) {
      if (context.mounted) showSnack(context, 'Nama kategori sudah ada.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah kategori',
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Category>>(
        stream: ref.watch(produkRepositoryProvider).watchCategories(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Belum ada kategori.'));
          return ListView(
            children: [
              for (final c in list)
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(c.name),
                  onTap: () => _edit(context, ref, c),
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirmDialog(context,
                          title: 'Hapus kategori?',
                          message: 'Produk di kategori ini tetap ada (tanpa kategori).',
                          ok: 'Hapus',
                          danger: true)) {
                        await ref.read(produkRepositoryProvider).deleteCategory(c.id);
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
