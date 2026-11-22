import 'package:material_ui/material_ui.dart';

import '../../widgets/coming_soon.dart';

class ContentHomeScreen extends StatelessWidget {
  const ContentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konten')),
      body: const ComingSoon(
        icon: Icons.lightbulb,
        title: 'Manajemen Konten',
        features: [
          'Ide konten: ide → produksi → review → publish',
          'Aset produksi (Google Drive, video, naskah)',
          'Kalender konten bulanan / mingguan',
          'Link publikasi & angka reach / engagement',
          'Tautan ide konten ↔ produk/jasa',
        ],
      ),
    );
  }
}
