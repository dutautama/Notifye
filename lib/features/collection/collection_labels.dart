import 'package:material_ui/material_ui.dart';

const watchlistTypeLabels = {
  'buku': ('Buku', Icons.menu_book_outlined),
  'artikel': ('Artikel', Icons.article_outlined),
  'video': ('Video', Icons.smart_display_outlined),
  'film': ('Film', Icons.movie_outlined),
  'serial': ('Serial', Icons.live_tv_outlined),
  'podcast': ('Podcast', Icons.podcasts_outlined),
  'lainnya': ('Lainnya', Icons.bookmark_outline),
};

const watchlistStatusLabels = {
  'ingin': 'Ingin',
  'sedang': 'Sedang',
  'selesai': 'Selesai',
  'ditunda': 'Ditunda',
  'drop': 'Drop',
};

Color watchlistStatusColor(String s) => switch (s) {
  'sedang' => Colors.blue.shade700,
  'selesai' => Colors.green.shade700,
  'ditunda' => Colors.orange.shade800,
  'drop' => Colors.grey.shade600,
  _ => Colors.purple,
};

/// Satuan progress sesuai jenis (halaman/episode/menit).
String progressUnit(String type) => switch (type) {
  'buku' => 'hal.',
  'serial' || 'podcast' => 'eps.',
  'video' || 'film' => 'menit',
  _ => 'bagian',
};

class WatchlistStatusChip extends StatelessWidget {
  const WatchlistStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = watchlistStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(
        watchlistStatusLabels[status] ?? status,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Bintang 1–5. [onChanged] null → hanya tampil. Mengetuk bintang yang sama menghapus rating.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 28});
  final int? value;
  final ValueChanged<int?>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Colors.amber.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          onChanged == null
              ? Icon((value ?? 0) >= i ? Icons.star : Icons.star_border, size: size, color: color)
              : IconButton(
                  tooltip: '$i bintang',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
                  icon: Icon((value ?? 0) >= i ? Icons.star : Icons.star_border, size: size, color: color),
                  onPressed: () => onChanged!(value == i ? null : i),
                ),
      ],
    );
  }
}
