import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/models/ayah.dart';
import '../database/app_database.dart';
import 'audio_reciter.dart';
import 'alquran_cloud_audio_provider.dart';

class AudioImportResult {
  final int imported;
  final int skipped;

  const AudioImportResult({required this.imported, required this.skipped});
}

class AudioDownloadResult {
  final int downloaded;
  final int alreadyAvailable;
  final int failed;

  const AudioDownloadResult({
    required this.downloaded,
    required this.alreadyAvailable,
    required this.failed,
  });
}

class OfflineAudioEntry {
  final int ayahId;
  final String reciter;
  final String reciterId;
  final String localPath;
  final String? sourceName;
  final String? sourceUrl;

  const OfflineAudioEntry({
    required this.ayahId,
    required this.reciter,
    required this.reciterId,
    required this.localPath,
    this.sourceName,
    this.sourceUrl,
  });

  File get file => File(localPath);
}

class AudioLibraryService {
  final AppDatabase database;
  final QuranAudioProvider provider;

  AudioLibraryService(this.database, {QuranAudioProvider? provider})
      : provider = provider ?? const AlQuranCloudAudioProvider();

  Future<OfflineAudioEntry?> forAyah(
    int ayahId, {
    String? reciterId,
  }) async {
    final db = await database.db;
    final rows = await db.query(
      'audio_metadata',
      where: 'ayah_id = ?',
      whereArgs: [ayahId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final path = row['local_path'] as String?;
    if (path == null || !await File(path).exists()) {
      await db.delete('audio_metadata', where: 'ayah_id = ?', whereArgs: [ayahId]);
      return null;
    }
    final storedReciterId = (row['reciter_id'] as String?) ?? 'local';
    if (reciterId != null &&
        storedReciterId != reciterId &&
        storedReciterId != 'local') {
      return null;
    }
    return OfflineAudioEntry(
      ayahId: ayahId,
      reciter: (row['reciter'] as String?) ?? 'Local audio',
      reciterId: storedReciterId,
      localPath: path,
      sourceName: row['source_name'] as String?,
      sourceUrl: row['source_url'] as String?,
    );
  }

  Future<int> count({String? reciterId}) async {
    final db = await database.db;
    final rows = reciterId == null
        ? await db.rawQuery('SELECT COUNT(*) AS c FROM audio_metadata')
        : await db.rawQuery(
            'SELECT COUNT(*) AS c FROM audio_metadata WHERE reciter_id = ?',
            [reciterId],
          );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> downloadedForSurah(int surahId, String reciterId) async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM audio_metadata m
      INNER JOIN ayahs a ON a.id = m.ayah_id
      WHERE a.surah_id = ? AND m.reciter_id = ?
    ''', [surahId, reciterId]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<AudioDownloadResult> downloadAyahs(
    List<Ayah> ayahs, {
    required AudioReciter reciter,
    void Function(int completed, int total)? onProgress,
  }) async {
    var downloaded = 0;
    var alreadyAvailable = 0;
    var failed = 0;
    var completed = 0;
    final total = ayahs.length;
    for (final ayah in ayahs) {
      try {
        final existing = await forAyah(ayah.id, reciterId: reciter.id);
        if (existing != null) {
          alreadyAvailable++;
        } else {
          await downloadAyah(ayah, reciter: reciter);
          downloaded++;
        }
      } catch (_) {
        failed++;
      }
      completed++;
      onProgress?.call(completed, total);
    }
    return AudioDownloadResult(
      downloaded: downloaded,
      alreadyAvailable: alreadyAvailable,
      failed: failed,
    );
  }

  Future<OfflineAudioEntry> downloadAyah(
    Ayah ayah, {
    required AudioReciter reciter,
  }) async {
    final uri = provider.ayahUri(
      reciter: reciter,
      globalAyahNumber: ayah.id,
    );
    final support = await getApplicationSupportDirectory();
    final audioDir = Directory(p.join(support.path, 'quran_audio', reciter.id));
    await audioDir.create(recursive: true);
    final output = File(
      p.join(
        audioDir.path,
        '${ayah.surahId.toString().padLeft(3, '0')}${ayah.ayahNumber.toString().padLeft(3, '0')}.mp3',
      ),
    );
    final temp = File('${output.path}.part');

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'HifzJourney/2.1.1');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Audio server returned ${response.statusCode}', uri: uri);
      }
      final sink = temp.openWrite();
      await response.pipe(sink);
      if (await output.exists()) await output.delete();
      await temp.rename(output.path);
    } finally {
      client.close(force: true);
      if (await temp.exists()) await temp.delete();
    }

    final db = await database.db;
    final previous = await db.query(
      'audio_metadata',
      columns: ['local_path'],
      where: 'ayah_id = ?',
      whereArgs: [ayah.id],
      limit: 1,
    );
    if (previous.isNotEmpty) {
      final oldPath = previous.first['local_path'] as String?;
      if (oldPath != null && oldPath != output.path) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      }
    }
    await db.insert(
      'audio_metadata',
      {
        'ayah_id': ayah.id,
        'reciter': reciter.name,
        'reciter_id': reciter.id,
        'local_path': output.path,
        'source_name': p.basename(output.path),
        'source_url': uri.toString(),
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return OfflineAudioEntry(
      ayahId: ayah.id,
      reciter: reciter.name,
      reciterId: reciter.id,
      localPath: output.path,
      sourceName: p.basename(output.path),
      sourceUrl: uri.toString(),
    );
  }

  Future<AudioImportResult> importAudioPack({String reciter = 'Local reciter'}) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import offline Qur’an audio',
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'ogg', 'wav'],
      allowMultiple: true,
    );
    if (files.isEmpty) return const AudioImportResult(imported: 0, skipped: 0);

    final support = await getApplicationSupportDirectory();
    final audioDir = Directory(p.join(support.path, 'quran_audio', 'local'));
    await audioDir.create(recursive: true);
    final db = await database.db;

    var imported = 0;
    var skipped = 0;
    for (final picked in files) {
      final reference = _referenceFromName(picked.name);
      if (reference == null) {
        skipped++;
        continue;
      }
      final ayahId = await _ayahId(reference.$1, reference.$2);
      if (ayahId == null) {
        skipped++;
        continue;
      }
      final ext = p.extension(picked.name).toLowerCase();
      final output = File(p.join(audioDir.path, '${ayahId.toString().padLeft(4, '0')}$ext'));
      await output.writeAsBytes(await picked.readAsBytes(), flush: true);
      await db.insert(
        'audio_metadata',
        {
          'ayah_id': ayahId,
          'reciter': reciter.trim().isEmpty ? 'Local reciter' : reciter.trim(),
          'reciter_id': 'local',
          'local_path': output.path,
          'source_name': picked.name,
          'source_url': null,
          'downloaded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      imported++;
    }
    return AudioImportResult(imported: imported, skipped: skipped);
  }

  Future<void> importForAyah(int ayahId, {String reciter = 'Local reciter'}) async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose audio for this ayah',
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'ogg', 'wav'],
    );
    if (picked == null) return;
    final support = await getApplicationSupportDirectory();
    final audioDir = Directory(p.join(support.path, 'quran_audio', 'local'));
    await audioDir.create(recursive: true);
    final ext = p.extension(picked.name).toLowerCase();
    final output = File(p.join(audioDir.path, '${ayahId.toString().padLeft(4, '0')}$ext'));
    await output.writeAsBytes(await picked.readAsBytes(), flush: true);
    final db = await database.db;
    await db.insert(
      'audio_metadata',
      {
        'ayah_id': ayahId,
        'reciter': reciter.trim().isEmpty ? 'Local reciter' : reciter.trim(),
        'reciter_id': 'local',
        'local_path': output.path,
        'source_name': picked.name,
        'source_url': null,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear({String? reciterId}) async {
    final db = await database.db;
    final rows = await db.query(
      'audio_metadata',
      columns: ['local_path'],
      where: reciterId == null ? null : 'reciter_id = ?',
      whereArgs: reciterId == null ? null : [reciterId],
    );
    for (final row in rows) {
      final path = row['local_path'] as String?;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    await db.delete(
      'audio_metadata',
      where: reciterId == null ? null : 'reciter_id = ?',
      whereArgs: reciterId == null ? null : [reciterId],
    );
  }

  (int, int)? _referenceFromName(String name) {
    final base = p.basenameWithoutExtension(name);
    final separated = RegExp(r'^(\d{1,3})[_\- ](\d{1,3})$').firstMatch(base);
    if (separated != null) {
      return (int.parse(separated.group(1)!), int.parse(separated.group(2)!));
    }
    final compact = RegExp(r'^(\d{3})(\d{3})$').firstMatch(base);
    if (compact != null) {
      return (int.parse(compact.group(1)!), int.parse(compact.group(2)!));
    }
    return null;
  }

  Future<int?> _ayahId(int surah, int ayah) async {
    final db = await database.db;
    final rows = await db.query(
      'ayahs',
      columns: ['id'],
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }
}
