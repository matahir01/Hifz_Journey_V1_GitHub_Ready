import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class BackupService {
  final AppDatabase database;

  BackupService(this.database);

  static const _tables = <String>[
    'hifz_progress',
    'test_results',
    'sessions',
    'bookmarks',
    'reading_progress',
    'app_activity',
    'recitation_attempts',
  ];

  Future<Uri?> exportBackup() async {
    final db = await database.db;
    final prefs = await SharedPreferences.getInstance();
    final tables = <String, Object?>{};
    for (final table in _tables) {
      tables[table] = await db.query(table);
    }

    final settings = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is String || value is int || value is double || value is bool || value is List<String>) {
        settings[key] = value;
      }
    }

    final payload = <String, Object?>{
      'format': 'hifz-journey-backup',
      'version': 4,
      'created_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'tables': tables,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final now = DateTime.now();
    final stamp = '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';
    return FilePicker.saveFile(
      dialogTitle: 'Save Hifz Journey backup',
      fileName: 'hifz-journey-$stamp.hifzbackup',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['hifzbackup'],
    );
  }

  Future<bool> restoreBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Restore Hifz Journey backup',
      type: FileType.custom,
      allowedExtensions: const ['hifzbackup', 'json'],
    );
    if (file == null) return false;

    final text = utf8.decode(await file.readAsBytes());
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'hifz-journey-backup') {
      throw const FormatException('This is not a Hifz Journey backup.');
    }

    final db = await database.db;
    final rawTables = decoded['tables'];
    if (rawTables is! Map<String, dynamic>) {
      throw const FormatException('Backup tables are missing.');
    }

    await db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }
      for (final table in _tables) {
        final rows = rawTables[table];
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              await txn.insert(
                table,
                Map<String, Object?>.from(row),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final settings = decoded['settings'];
    if (settings is Map<String, dynamic>) {
      for (final entry in settings.entries) {
        final value = entry.value;
        if (value is String) await prefs.setString(entry.key, value);
        if (value is int) await prefs.setInt(entry.key, value);
        if (value is double) await prefs.setDouble(entry.key, value);
        if (value is bool) await prefs.setBool(entry.key, value);
        if (value is List) {
          await prefs.setStringList(entry.key, value.map((e) => '$e').toList());
        }
      }
    }
    return true;
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
