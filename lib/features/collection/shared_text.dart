/// Hasil penguraian teks yang dibagikan dari aplikasi lain (Chrome, YouTube, dll.).
class SharedItemDraft {
  const SharedItemDraft({required this.title, this.url, required this.type, this.platform});
  final String title;
  final String? url;
  final String type; // salah satu watchlistTypes
  final String? platform;
}

final _urlRe = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

/// Pisahkan judul & link dari teks share, lalu tebak jenis & platform dari domain.
/// Tidak membuka internet (aplikasi sengaja tanpa izin INTERNET).
SharedItemDraft? parseSharedText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final m = _urlRe.firstMatch(text);
  final url = m?.group(0)?.replaceAll(RegExp(r'[).,;!?]+$'), '');
  var title = (m == null ? text : text.replaceFirst(m.group(0)!, ''))
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-–—|:]+|[\s\-–—|:]+$'), '')
      .trim();
  final host = url == null ? '' : (Uri.tryParse(url)?.host.toLowerCase() ?? '');
  final (type, platform) = _guess(host, url ?? '');
  if (title.isEmpty) {
    title = platform != null
        ? '$platform — ${_shortPath(url!)}'
        : (host.isEmpty ? 'Item baru' : host.replaceFirst('www.', ''));
  }
  if (title.length > 300) title = title.substring(0, 300);
  return SharedItemDraft(title: title, url: url, type: type, platform: platform);
}

(String, String?) _guess(String host, String url) {
  bool h(String d) => host == d || host.endsWith('.$d');
  if (h('youtube.com') || h('youtu.be')) return ('video', 'YouTube');
  if (h('tiktok.com')) return ('video', 'TikTok');
  if (h('instagram.com')) return ('video', 'Instagram');
  if (h('vimeo.com')) return ('video', 'Vimeo');
  if (h('netflix.com')) return (url.contains('/title/') ? 'film' : 'serial', 'Netflix');
  if (h('primevideo.com')) return ('film', 'Prime Video');
  if (h('disneyplus.com') || h('hotstar.com')) return ('film', 'Disney+');
  if (h('vidio.com')) return ('serial', 'Vidio');
  if (h('imdb.com')) return ('film', 'IMDb');
  if (h('spotify.com')) {
    return (url.contains('/episode/') || url.contains('/show/') ? 'podcast' : 'lainnya', 'Spotify');
  }
  if (h('podcasts.apple.com') || h('podcasts.google.com') || h('castbox.fm')) return ('podcast', 'Podcast');
  if (h('goodreads.com') || h('books.google.com') || h('gramedia.com') || h('gramedia.digital')) return ('buku', null);
  if (h('medium.com') || h('substack.com') || h('kompas.com') || h('detik.com') || h('tempo.co')) {
    return ('artikel', null);
  }
  return (host.isEmpty ? 'lainnya' : 'artikel', null);
}

String _shortPath(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return url;
  final p = u.pathSegments.where((s) => s.isNotEmpty).toList();
  return p.isEmpty ? u.host : p.last;
}
