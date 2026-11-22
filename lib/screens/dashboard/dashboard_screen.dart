import 'package:material_ui/material_ui.dart';

import '../../widgets/coming_soon.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beranda')),
      body: const ComingSoon(
        icon: Icons.dashboard,
        title: 'Dashboard',
        features: [
          'Omzet hari ini & bulan ini',
          'Piutang & hutang jatuh tempo',
          'Stok menipis',
          'Jadwal konten minggu ini',
        ],
      ),
    );
  }
}
