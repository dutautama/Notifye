import 'package:material_ui/material_ui.dart';

const contentPlatforms = {
  'instagram': 'Instagram',
  'tiktok': 'TikTok',
  'youtube': 'YouTube',
  'facebook': 'Facebook',
  'x': 'X',
  'threads': 'Threads',
  'linkedin': 'LinkedIn',
  'lainnya': 'Lainnya',
};

String platformLabel(String p) => contentPlatforms[p] ?? p;

const ideaStatusLabels = {'ide': 'Ide', 'produksi': 'Produksi', 'review': 'Review', 'publish': 'Publish'};

Color ideaStatusColor(String s) => switch (s) {
  'ide' => Colors.blueGrey,
  'produksi' => Colors.orange.shade700,
  'review' => Colors.purple,
  _ => Colors.green.shade700,
};

const priorityLabels = {1: 'Tinggi', 2: 'Sedang', 3: 'Rendah'};

const assetKindLabels = {
  'link': ('Link', Icons.link),
  'gdrive': ('Google Drive', Icons.add_to_drive),
  'video': ('Video', Icons.movie_outlined),
  'gambar': ('Gambar', Icons.image_outlined),
  'audio': ('Audio', Icons.audiotrack_outlined),
  'dokumen': ('Dokumen', Icons.description_outlined),
  'naskah': ('Naskah / catatan', Icons.notes),
};

const scheduleStatusLabels = {'terjadwal': 'Terjadwal', 'tayang': 'Tayang', 'batal': 'Batal'};

class IdeaStatusChip extends StatelessWidget {
  const IdeaStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = ideaStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(
        ideaStatusLabels[status] ?? status,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
