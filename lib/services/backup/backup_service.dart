import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_info.dart';
import '../../data/database/app_database.dart';
import '../../data/database/migrations/migration_strategy.dart';
import '../../data/repositories/meta_repository.dart';
import '../../features/auth/app_reset_service.dart';
import 'backup_codec.dart';

class BackupFileInfo {
  const BackupFileInfo(this.file, this.modified, this.sizeBytes, {required this.isAuto});
  final File file;
  final DateTime modified;
  final int sizeBytes;
  final bool isAuto;
  String get name => file.uri.pathSegments.last;
}

/// Buat/bagikan/pulihkan file backup UsahaKonten-backup-YYYYMMDD-HHmm.zip.
/// Isi zip: data.json, meta.json, attachments/...
class BackupService {
  BackupService(
    this._db,
    this._meta, {
    Future<Directory> Function()? baseDir,
    Future<Directory> Function()? attachmentsDir,
    this.now = DateTime.now,
  }) : _baseDir = baseDir ?? getApplicationSupportDirectory,
       _attachmentsDir = attachmentsDir ?? AppResetService.attachmentsDir;

  final AppDatabase _db;
  final MetaRepository _meta;
  final Future<Directory> Function() _baseDir;
  final Future<Directory> Function() _attachmentsDir;
  final DateTime Function() now;

  static const autoKeep = 4;
  static const autoInterval = Duration(days: 7);

  BackupCodec get _codec => BackupCodec(_db);

  Future<Directory> _dir(String sub) async {
    final d = Directory('${(await _baseDir()).path}/backups/$sub');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<Directory> get manualDir => _dir('manual');
  Future<Directory> get autoDir => _dir('auto');

  static String fileNameFor(DateTime t) => 'UsahaKonten-backup-${DateFormat('yyyyMMdd-HHmm').format(t)}.zip';

  // ------------------------------------------------------------ export
  Future<File> createBackup({bool auto = false}) async {
    final t = now();
    final data = await _codec.exportData();
    final counts = await _codec.rowCounts();
    final meta = {
      'format': backupFormat,
      'schema_version': currentSchemaVersion,
      'app_version': AppInfo.version,
      'created_at': t.toUtc().toIso8601String(),
      'row_counts': counts,
    };

    final attDir = await _attachmentsDir();
    final attFiles = <String, List<int>>{};
    if (await attDir.exists()) {
      await for (final f in attDir.list(recursive: true)) {
        if (f is File) {
          final rel = f.path.substring(attDir.path.length + 1).replaceAll('\\', '/');
          attFiles['attachments/$rel'] = await f.readAsBytes();
        }
      }
    }

    final dataJson = utf8.encode(jsonEncode(data));
    final metaJson = utf8.encode(const JsonEncoder.withIndent('  ').convert(meta));
    final bytes = await Isolate.run(() {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('meta.json', metaJson))
        ..addFile(ArchiveFile.bytes('data.json', dataJson));
      for (final e in attFiles.entries) {
        archive.addFile(ArchiveFile.bytes(e.key, e.value));
      }
      return ZipEncoder().encodeBytes(archive);
    });

    final dir = auto ? await autoDir : await manualDir;
    var file = File('${dir.path}/${fileNameFor(t)}');
    var n = 2;
    while (await file.exists()) {
      file = File('${dir.path}/${fileNameFor(t).replaceFirst('.zip', '-$n.zip')}');
      n++;
    }
    await file.writeAsBytes(bytes, flush: true);
    if (auto) {
      await _meta.set(MetaRepository.lastAutoBackup, t.toUtc().toIso8601String());
      await _rotateAuto();
    }
    return file;
  }

  Future<void> _rotateAuto() async {
    final list = await listBackups(includeManual: false);
    for (final b in list.skip(autoKeep)) {
      await b.file.delete();
    }
  }

  /// Backup otomatis jika yang terakhir ≥ 7 hari lalu (dipanggil saat aplikasi dibuka).
  /// Mengembalikan file baru atau null bila belum waktunya.
  Future<File?> runAutoBackupIfDue() async {
    final last = DateTime.tryParse(await _meta.get(MetaRepository.lastAutoBackup) ?? '');
    if (last != null && now().difference(last) < autoInterval) return null;
    return createBackup(auto: true);
  }

  Future<DateTime?> lastAutoBackupAt() async =>
      DateTime.tryParse(await _meta.get(MetaRepository.lastAutoBackup) ?? '')?.toLocal();

  /// Semua backup tersimpan di HP, terbaru dulu.
  Future<List<BackupFileInfo>> listBackups({bool includeManual = true}) async {
    final out = <BackupFileInfo>[];
    for (final (dir, isAuto) in [(await autoDir, true), if (includeManual) (await manualDir, false)]) {
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.zip')) {
          final stat = await f.stat();
          out.add(BackupFileInfo(f, stat.modified, stat.size, isAuto: isAuto));
        }
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<ShareResult> share(File file) => SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/zip')],
      subject: 'Backup UsahaKonten',
      text:
          'Backup data UsahaKonten (${file.uri.pathSegments.last}). '
          'Simpan di Google Drive. Pulihkan lewat Pengaturan → Backup & Restore.',
    ),
  );

  // ----------------------------------------------------------- restore
  /// Baca file .zip (backup) atau .json (data.json / export Supabase).
  Future<ParsedBackup> parse(File file) async => parseBytes(await file.readAsBytes());

  Future<ParsedBackup> parseBytes(List<int> bytes) async {
    final isZip = bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (!isZip) {
      final decoded = _decodeJson(bytes, 'File');
      final v = BackupCodec.validate(decoded);
      return ParsedBackup(decoded, const {}, v.schemaVersion, v.source, null);
    }
    final archive = await Isolate.run(() => ZipDecoder().decodeBytes(bytes));
    Object? data;
    Map<String, dynamic>? meta;
    final attachments = <String, List<int>>{};
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/');
      if (name == 'data.json') {
        data = _decodeJson(entry.content, 'data.json');
      } else if (name == 'meta.json') {
        final m = _decodeJson(entry.content, 'meta.json');
        if (m is Map<String, dynamic>) meta = m;
      } else if (name.startsWith('attachments/')) {
        final rel = safeAttachmentPath(name.substring('attachments/'.length));
        if (rel == null) {
          throw BackupFormatException('File backup berisi path lampiran yang tidak aman: $name');
        }
        attachments[rel] = entry.content;
      }
    }
    if (data == null) throw BackupFormatException('data.json tidak ditemukan di dalam zip.');
    final v = BackupCodec.validate(data);
    return ParsedBackup(data, attachments, v.schemaVersion, v.source, meta);
  }

  Future<RestoreResult> restore(ParsedBackup backup, RestoreMode mode) async {
    // Backup keselamatan otomatis sebelum menimpa data.
    await createBackup(auto: true);
    final result = await _codec.restore(backup.data, mode);

    final attDir = await _attachmentsDir();
    if (mode == RestoreMode.replace && await attDir.exists()) {
      await attDir.delete(recursive: true);
    }
    for (final e in backup.attachments.entries) {
      final f = File('${attDir.path}/${e.key}');
      if (mode == RestoreMode.merge && await f.exists()) continue;
      await f.parent.create(recursive: true);
      await f.writeAsBytes(e.value, flush: true);
    }
    return result;
  }

  static Object? _decodeJson(List<int> bytes, String what) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw BackupFormatException('$what bukan JSON yang valid.');
    }
  }

  /// Cegah "zip slip": hanya path relatif biasa tanpa `..`, tanpa path absolut.
  static String? safeAttachmentPath(String rel) {
    if (rel.isEmpty || rel.startsWith('/') || rel.contains(':')) return null;
    final parts = rel.split('/');
    if (parts.any((p) => p.isEmpty || p == '.' || p == '..')) return null;
    return parts.join('/');
  }
}

class ParsedBackup {
  const ParsedBackup(this.data, this.attachments, this.schemaVersion, this.source, this.meta);
  final Object? data;
  final Map<String, List<int>> attachments;
  final int schemaVersion;
  final String source;
  final Map<String, dynamic>? meta;

  Map<String, int> get rowCounts {
    final tables = (data as Map<String, dynamic>)['tables'] as Map<String, dynamic>;
    return {for (final e in tables.entries) e.key: (e.value as List).length};
  }

  DateTime? get createdAt => DateTime.tryParse('${meta?['created_at']}')?.toLocal();
}
