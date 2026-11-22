import 'package:material_ui/material_ui.dart';

import '../../widgets/coming_soon.dart';

class BusinessHomeScreen extends StatelessWidget {
  const BusinessHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usaha')),
      body: const ComingSoon(
        icon: Icons.storefront,
        title: 'Manajemen Usaha',
        features: [
          'Produk & jasa (harga, stok, kategori)',
          'Penjualan & pembelian (stok otomatis)',
          'Hutang & piutang',
          'Invoice PDF → WhatsApp / email',
          'Pelanggan & supplier',
          'Scanner barcode & printer struk Bluetooth',
        ],
      ),
    );
  }
}
