import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/session_specs.dart';
import '../models/shoot_plan.dart';

/// Saves sessions under `Documents/WheelShot/<name>/`.
class SessionStore {
  SessionStore._(
    this.rootDir,
    this.sessionName,
    this.category, {
    this.config,
    this.dezentNotes = const [],
    this.spareHasRim = true,
  });

  final Directory rootDir;
  final String sessionName;
  final ShootCategory category;
  final ShootConfig? config;
  final List<String> dezentNotes;
  final bool spareHasRim;

  String? get dezentType1 =>
      dezentNotes.isNotEmpty ? dezentNotes[0] : null;
  String? get dezentType2 =>
      dezentNotes.length > 1 ? dezentNotes[1] : null;

  Directory get sessionDir => Directory(p.join(rootDir.path, sessionName));

  static Future<Directory> documentsRoot() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      final publicDocs = Directory('/storage/emulated/0/Documents/WheelShot');
      try {
        if (!await publicDocs.exists()) {
          await publicDocs.create(recursive: true);
        }
        final probe = File(p.join(publicDocs.path, '.write_test'));
        await probe.writeAsString('ok');
        await probe.delete();
        return publicDocs;
      } catch (_) {
        final base = ext ?? await getApplicationDocumentsDirectory();
        final dir = Directory(p.join(base.path, 'WheelShot'));
        await dir.create(recursive: true);
        return dir;
      }
    }

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'WheelShot'));
    await dir.create(recursive: true);
    return dir;
  }

  static String sanitizeName(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '_');
    if (cleaned.isEmpty) {
      return 'shoot_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    }
    return cleaned;
  }

  static Future<SessionStore> create({
    required String name,
    required ShootCategory category,
    ShootConfig? config,
    List<String> dezentNotes = const [],
    bool spareHasRim = true,
  }) async {
    final root = await documentsRoot();
    final safe = sanitizeName(name);
    final store = SessionStore._(
      root,
      safe,
      category,
      config: config,
      dezentNotes: dezentNotes,
      spareHasRim: spareHasRim,
    );
    await store.sessionDir.create(recursive: true);

    final buf = StringBuffer()
      ..writeln('category: ${category.name}')
      ..writeln('title: ${category.title}')
      ..writeln('created: ${DateTime.now().toIso8601String()}');
    if (category == ShootCategory.spare) {
      buf.writeln('spare_has_rim: $spareHasRim');
    }
    if (config != null) {
      buf
        ..writeln('pieces: ${config.pieceCount}')
        ..writeln('tire_types: ${config.tireTypes}')
        ..writeln('rim_types: ${config.rimTypes}')
        ..writeln('rims_differ_by_axis: ${config.rimsDifferByAxis}')
        ..writeln('et_only_by_axis: ${config.etOnlyByAxis}')
        ..writeln('layout: ${config.label}')
        ..writeln('layout_note: ${config.mixNote}');
    }
    for (var i = 0; i < dezentNotes.length; i++) {
      final d = dezentNotes[i].trim();
      if (d.isNotEmpty) {
        buf.writeln('dezent_type${i + 1}: $d');
      }
    }

    await File(p.join(store.sessionDir.path, 'session.txt'))
        .writeAsString(buf.toString());
    return store;
  }

  Future<File> saveCapture({
    required String stepId,
    required String sourcePath,
  }) async {
    final dest = File(p.join(sessionDir.path, '$stepId.jpg'));
    await File(sourcePath).copy(dest.path);
    try {
      await File(sourcePath).delete();
    } catch (_) {}
    return dest;
  }

  Future<List<File>> listPhotos() async {
    if (!await sessionDir.exists()) return [];
    final files = await sessionDir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.jpg'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  /// stepId → jpg path for every `<stepId>.jpg` in the session folder.
  Future<Map<String, String>> existingCaptures() async {
    final out = <String, String>{};
    for (final f in await listPhotos()) {
      final base = p.basename(f.path);
      out[base.substring(0, base.length - '.jpg'.length)] = f.path;
    }
    return out;
  }

  /// Writes `specs.json` (machine-readable) and `specs.txt` (ad skill).
  Future<File> saveSpecs(SessionSpecs specs) async {
    await File(p.join(sessionDir.path, 'specs.json')).writeAsString(
      specs.toJsonString(category: category, config: config),
    );
    final file = File(p.join(sessionDir.path, 'specs.txt'));
    await file.writeAsString(
      specs.toFileContents(category: category, config: config),
    );
    return file;
  }

  /// Reads `specs.json` if present; null otherwise.
  Future<SessionSpecs?> loadSpecs() async {
    final file = File(p.join(sessionDir.path, 'specs.json'));
    if (!await file.exists()) return null;
    return SessionSpecs.tryParseJson(await file.readAsString());
  }

  static Future<List<PastSession>> listPastSessions() async {
    final root = await documentsRoot();
    if (!await root.exists()) return [];
    final dirs = <Directory>[];
    await for (final e in root.list()) {
      if (e is Directory) dirs.add(e);
    }
    final out = <PastSession>[];
    for (final dir in dirs) {
      final name = p.basename(dir.path);
      if (name.startsWith('.')) continue;
      var photoCount = 0;
      File? thumb;
      DateTime? modified;
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final lower = e.path.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          photoCount++;
          thumb ??= e;
          final m = await e.lastModified();
          if (modified == null || m.isAfter(modified)) modified = m;
        }
      }
      String? category;
      String? title;
      final meta = File(p.join(dir.path, 'session.txt'));
      if (await meta.exists()) {
        for (final line in (await meta.readAsString()).split('\n')) {
          final t = line.trim();
          if (t.startsWith('category:')) {
            category = t.substring('category:'.length).trim();
          } else if (t.startsWith('title:')) {
            title = t.substring('title:'.length).trim();
          } else if (t.startsWith('created:') && modified == null) {
            modified = DateTime.tryParse(t.substring('created:'.length).trim());
          }
        }
        final m = await meta.lastModified();
        if (modified == null || m.isAfter(modified)) modified = m;
      }
      if (photoCount == 0 && category == null) continue;
      out.add(
        PastSession(
          name: name,
          path: dir.path,
          photoCount: photoCount,
          category: category,
          title: title,
          modified: modified,
          thumbPath: thumb?.path,
        ),
      );
    }
    out.sort((a, b) {
      final am = a.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bm = b.modified ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bm.compareTo(am);
    });
    return out;
  }

  static Future<SessionStore?> openExisting(String sessionName) async {
    final root = await documentsRoot();
    final dir = Directory(p.join(root.path, sessionName));
    if (!await dir.exists()) return null;
    var category = ShootCategory.wheelSet;
    var spareHasRim = true;
    int? pieces;
    var tireTypes = 1;
    var rimTypes = 1;
    var rimsDifferByAxis = false;
    var etOnlyByAxis = false;
    final dezent = <int, String>{};
    final meta = File(p.join(dir.path, 'session.txt'));
    if (await meta.exists()) {
      for (final line in (await meta.readAsString()).split('\n')) {
        final t = line.trim();
        final i = t.indexOf(':');
        if (i < 0) continue;
        final key = t.substring(0, i).trim();
        final val = t.substring(i + 1).trim();
        switch (key) {
          case 'category':
            category = ShootCategory.values.firstWhere(
              (c) => c.name == val,
              orElse: () => ShootCategory.wheelSet,
            );
          case 'pieces':
            pieces = int.tryParse(val) ?? pieces;
          case 'tire_types':
            tireTypes = int.tryParse(val) ?? tireTypes;
          case 'rim_types':
            rimTypes = int.tryParse(val) ?? rimTypes;
          case 'rims_differ_by_axis':
            rimsDifferByAxis = val == 'true';
          case 'et_only_by_axis':
            etOnlyByAxis = val == 'true';
          case 'spare_has_rim':
            spareHasRim = val != 'false';
          default:
            final m = RegExp(r'^dezent_type(\d+)$').firstMatch(key);
            if (m != null && val.isNotEmpty) {
              dezent[int.parse(m.group(1)!)] = val;
            }
        }
      }
    }
    final notes = (dezent.keys.toList()..sort()).map((k) => dezent[k]!).toList();
    final cfg = (pieces != null && category.usesShootConfig)
        ? ShootConfig(
            pieceCount: pieces,
            tireTypes: tireTypes,
            rimTypes: rimTypes,
            rimsDifferByAxis: rimsDifferByAxis,
            etOnlyByAxis: etOnlyByAxis,
          )
        : null;
    return SessionStore._(
      root,
      sessionName,
      category,
      config: cfg,
      dezentNotes: notes,
      spareHasRim: spareHasRim,
    );
  }
}

class PastSession {
  const PastSession({
    required this.name,
    required this.path,
    required this.photoCount,
    this.category,
    this.title,
    this.modified,
    this.thumbPath,
  });

  final String name;
  final String path;
  final int photoCount;
  final String? category;
  final String? title;
  final DateTime? modified;
  final String? thumbPath;
}
