import 'package:material_ui/material_ui.dart';

import '../../widgets/coming_soon.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: const ComingSoon(
        icon: Icons.bar_chart,
        title: 'Laporan',
        features: [
          'Laporan penjualan',
          'Laporan stok',
          'Laporan hutang & piutang',
          'Performa konten',
          'Export Excel & PDF',
        ],
      ),
    );
  }
}
