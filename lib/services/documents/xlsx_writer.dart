import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Satu sheet: baris pertama dianggap header (dicetak tebal).
class XlsxSheet {
  XlsxSheet(this.name, this.rows);
  final String name;
  final List<List<Object?>> rows; // num → angka, lainnya → teks
}

/// Penulis XLSX minimal (Office Open XML) tanpa dependensi tambahan.
/// Cukup untuk laporan: banyak sheet, teks, angka, header tebal, lebar kolom.
class XlsxWriter {
  XlsxWriter._();

  static Uint8List build(List<XlsxSheet> sheets) {
    if (sheets.isEmpty) throw ArgumentError('Minimal 1 sheet');
    final names = <String>{};
    final safeNames = [
      for (final s in sheets) _uniqueName(_sanitizeSheetName(s.name), names),
    ];
    final archive = Archive()
      ..addFile(_file('[Content_Types].xml', _contentTypes(sheets.length)))
      ..addFile(_file('_rels/.rels', _rootRels))
      ..addFile(_file('xl/workbook.xml', _workbook(safeNames)))
      ..addFile(_file('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length)))
      ..addFile(_file('xl/styles.xml', _styles));
    for (var i = 0; i < sheets.length; i++) {
      archive.addFile(_file('xl/worksheets/sheet${i + 1}.xml', _sheet(sheets[i].rows)));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  static ArchiveFile _file(String name, String content) => ArchiveFile.bytes(name, utf8.encode(content));

  static String _sanitizeSheetName(String n) {
    final s = n.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
    final t = s.isEmpty ? 'Sheet' : s;
    return t.length > 31 ? t.substring(0, 31) : t;
  }

  static String _uniqueName(String base, Set<String> used) {
    var n = base;
    var i = 2;
    while (!used.add(n.toLowerCase())) {
      final suffix = ' ($i)';
      n = (base.length + suffix.length > 31 ? base.substring(0, 31 - suffix.length) : base) + suffix;
      i++;
    }
    return n;
  }

  /// 0 → A, 25 → Z, 26 → AA
  static String columnName(int index) {
    var i = index;
    var s = '';
    do {
      s = String.fromCharCode(65 + i % 26) + s;
      i = i ~/ 26 - 1;
    } while (i >= 0);
    return s;
  }

  static String _esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String _sheet(List<List<Object?>> rows) {
    final colCount = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final widths = List<int>.filled(colCount, 8);
    for (final r in rows) {
      for (var c = 0; c < r.length; c++) {
        final len = '${r[c] ?? ''}'.length + 2;
        if (len > widths[c]) widths[c] = len > 60 ? 60 : len;
      }
    }
    final b = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    if (colCount > 0) {
      b.write('<cols>');
      for (var c = 0; c < colCount; c++) {
        b.write('<col min="${c + 1}" max="${c + 1}" width="${widths[c]}" customWidth="1"/>');
      }
      b.write('</cols>');
    }
    b.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      b.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v == null) continue;
        final ref = '${columnName(c)}${r + 1}';
        final style = r == 0 ? ' s="1"' : '';
        if (v is num && v.isFinite) {
          b.write('<c r="$ref"$style><v>$v</v></c>');
        } else {
          b.write('<c r="$ref" t="inlineStr"$style><is><t xml:space="preserve">${_esc('$v')}</t></is></c>');
        }
      }
      b.write('</row>');
    }
    b.write('</sheetData></worksheet>');
    return b.toString();
  }

  static String _contentTypes(int n) {
    final sheets = [
      for (var i = 1; i <= n; i++)
        '<Override PartName="/xl/worksheets/sheet$i.xml" '
            'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
    ].join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '$sheets</Types>';
  }

  static const _rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/></Relationships>';

  static String _workbook(List<String> names) {
    final sheets = [
      for (var i = 0; i < names.length; i++)
        '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'
    ].join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets>$sheets</sheets></workbook>';
  }

  static String _workbookRels(int n) {
    final rels = [
      for (var i = 1; i <= n; i++)
        '<Relationship Id="rId$i" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet$i.xml"/>'
    ].join();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels<Relationship Id="rId${n + 1}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
        'Target="styles.xml"/></Relationships>';
  }

  static const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
