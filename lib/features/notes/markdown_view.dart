import 'package:material_ui/material_ui.dart';

import 'markdown_text.dart';

/// Penampil markdown ringan (judul, tebal, miring, bullet, nomor, checkbox yang bisa diketuk).
/// Dibuat sendiri karena paket markdown populer memakai `flutter/material` lama yang
/// tidak kompatibel dengan material_ui di Flutter 3.50.
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.text, this.onToggleCheckbox});

  final String text;
  final ValueChanged<int>? onToggleCheckbox;

  static final _heading = RegExp(r'^(#{1,3}) (.*)$');
  static final _bullet = RegExp(r'^(\s*)[-*] (.*)$');
  static final _numbered = RegExp(r'^(\s*)(\d+)\. (.*)$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
    final lines = text.split('\n');
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      final cb = MarkdownText.checkboxRe.firstMatch(line);
      if (cb != null) {
        final checked = cb.group(2)!.toLowerCase() == 'x';
        final content = line.substring(cb.end);
        children.add(InkWell(
          onTap: onToggleCheckbox == null ? null : () => onToggleCheckbox!(i),
          child: Padding(
            padding: EdgeInsets.only(left: cb.group(1)!.length * 8.0, top: 2, bottom: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 22, color: checked ? theme.colorScheme.primary : null),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  _inline(content, base.copyWith(
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? theme.colorScheme.onSurfaceVariant : null,
                  )),
                ),
              ),
            ]),
          ),
        ));
        continue;
      }
      final h = _heading.firstMatch(line);
      if (h != null) {
        final style = switch (h.group(1)!.length) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          _ => theme.textTheme.titleMedium,
        };
        children.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text.rich(_inline(h.group(2)!, (style ?? base).copyWith(fontWeight: FontWeight.bold))),
        ));
        continue;
      }
      final n = _numbered.firstMatch(line);
      final b = n == null ? _bullet.firstMatch(line) : null;
      if (n != null || b != null) {
        final indent = (n?.group(1) ?? b!.group(1)!).length * 8.0;
        final marker = n != null ? '${n.group(2)}.' : '•';
        final content = n?.group(3) ?? b!.group(2)!;
        children.add(Padding(
          padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(marker, style: base)),
            Expanded(child: Text.rich(_inline(content, base))),
          ]),
        ));
        continue;
      }
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(_inline(line, base)),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  static final _inlineRe = RegExp(r'\*\*(.+?)\*\*|(?<![\w])_(.+?)_(?![\w])');

  static TextSpan _inline(String s, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: style, children: spans);
  }
}
