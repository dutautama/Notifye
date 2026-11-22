import 'package:flutter/services.dart';

/// Helper markdown ringan untuk editor catatan (fungsi murni, diuji di test/notes_test.dart).
/// Sintaks yang didukung: # judul, **tebal**, _miring_, - bullet, 1. nomor, - [ ] / - [x] checkbox.
class MarkdownText {
  MarkdownText._();

  static final checkboxRe = RegExp(r'^(\s*)[-*] \[( |x|X)\] ');

  /// Bungkus teks terpilih dengan [marker] (mis. ** atau _). Tanpa seleksi → sisipkan pasangan & taruh kursor di tengah.
  static TextEditingValue wrap(TextEditingValue v, String marker) {
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final selected = sel.textInside(v.text);
    final text = v.text.replaceRange(sel.start, sel.end, '$marker$selected$marker');
    final offset = selected.isEmpty ? sel.start + marker.length : sel.start + marker.length * 2 + selected.length;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }

  /// Tambah/hapus awalan [prefix] pada semua baris yang tersentuh seleksi (toggle).
  static TextEditingValue togglePrefix(TextEditingValue v, String prefix) {
    final text = v.text;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: text.length);
    final lineStart = text.lastIndexOf('\n', sel.start == 0 ? 0 : sel.start - 1) + 1;
    var lineEnd = text.indexOf('\n', sel.end);
    if (lineEnd == -1) lineEnd = text.length;
    final lines = text.substring(lineStart, lineEnd).split('\n');
    final allHave = lines.every((l) => _hasPrefix(l, prefix));
    final changed = [
      for (final l in lines)
        allHave ? l.substring(prefix.length) : (_hasPrefix(l, prefix) ? l : '$prefix${_stripListPrefix(l)}'),
    ].join('\n');
    final newText = text.replaceRange(lineStart, lineEnd, changed);
    return TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: lineStart + changed.length));
  }

  /// Baris checklist ("- [ ] ") bukan bullet biasa walau sama-sama diawali "- ".
  static bool _hasPrefix(String line, String prefix) =>
      line.startsWith(prefix) && (prefix != '- ' || !checkboxRe.hasMatch(line));

  static String _stripListPrefix(String l) =>
      l.replaceFirst(RegExp(r'^(#{1,3} |[-*] \[( |x|X)\] |[-*] |\d+\. )'), '');

  /// Centang/batal centang checkbox pada baris ke-[lineIndex].
  static String toggleCheckbox(String body, int lineIndex) {
    final lines = body.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return body;
    final m = checkboxRe.firstMatch(lines[lineIndex]);
    if (m == null) return body;
    final checked = m.group(2)!.toLowerCase() == 'x';
    lines[lineIndex] = lines[lineIndex].replaceFirst(checkboxRe, '${m.group(1)}- [${checked ? ' ' : 'x'}] ');
    return lines.join('\n');
  }

  /// Teks untuk dibagikan (WhatsApp/email): checkbox → ☐/☑, penanda tebal/miring dibuang.
  static String toShareText(String title, String body) {
    final b = body
        .split('\n')
        .map((l) => l
            .replaceFirstMapped(checkboxRe, (m) => '${m.group(1)}${m.group(2)!.toLowerCase() == 'x' ? '☑' : '☐'} ')
            .replaceFirst(RegExp(r'^#{1,3} '), '')
            .replaceFirstMapped(RegExp(r'^(\s*)[-*] '), (m) => '${m.group(1)}• ')
            .replaceAll('**', '')
            .replaceAllMapped(RegExp(r'(^|\s)_(\S[^_]*?)_(?=\s|$|[.,!?])'), (m) => '${m.group(1)}${m.group(2)}'))
        .join('\n')
        .trim();
    final t = title.trim();
    return t.isEmpty ? b : (b.isEmpty ? t : '$t\n\n$b');
  }

  /// Pratinjau satu-dua baris untuk daftar catatan.
  static String preview(String body, {int maxChars = 140}) {
    final plain = toShareText('', body).replaceAll(RegExp(r'\s+'), ' ').trim();
    return plain.length > maxChars ? '${plain.substring(0, maxChars)}…' : plain;
  }

  /// Statistik checklist: (selesai, total).
  static (int, int) checklistProgress(String body) {
    var done = 0, total = 0;
    for (final l in body.split('\n')) {
      final m = checkboxRe.firstMatch(l);
      if (m == null) continue;
      total++;
      if (m.group(2)!.toLowerCase() == 'x') done++;
    }
    return (done, total);
  }
}
