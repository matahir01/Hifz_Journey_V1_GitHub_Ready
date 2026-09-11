import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class BackupService {
  final AppDatabase database;

  BackupService(this.database);

  static const _format = 'hifz-journey-backup';
  static const _backupVersion = 5;

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
      if (value is String ||
          value is int ||
          value is double ||
          value is bool ||
          value is List<String>) {
        settings[key] = value;
      }
    }

    final payload = <String, Object?>{
      'format': _format,
      'version': _backupVersion,
      'created_at': DateTime.now().toIso8601String(),
      'settings': settings,
      'tables': tables,
    };

    final encoded = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    if (bytes.isEmpty) {
      throw const FileSystemException('Backup data could not be created.');
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';

    // Use a normal JSON document rather than a custom extension. Android's
    // Storage Access Framework can otherwise show the file but make it
    // unavailable to the restore picker on some devices/file managers.
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Save Hifz Journey backup',
      fileName: 'hifz-journey-backup-$stamp.json',
      bytes: bytes,
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );

    if (uri == null) return null;

    // Desktop/file:// destinations can be verified immediately. Android SAF
    // normally returns content://, where file_picker owns the actual write.
    if (uri.scheme == 'file') {
      final saved = File.fromUri(uri);
      final length = await saved.length();
      if (length <= 0) {
        throw const FileSystemException('The backup file was saved empty.');
      }
    }

    return uri;
  }

  Future<bool> restoreBackup() async {
    // FileType.any is intentional. Several Android document providers do not
    // expose custom extensions consistently. We validate the selected file's
    // contents ourselves before touching the user's current data.
    final file = await FilePicker.pickFile(
      dialogTitle: 'Restore Hifz Journey backup',
      type: FileType.any,
    );
    if (file == null) return false;

    final length = file.lengthSync() ?? await file.length();
    if (length <= 0) {
      throw const FormatException('The selected backup file is empty.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('The selected backup file is empty.');
    }

    final decoded = _decodeBackup(bytes);
    final rawTables = decoded['tables'] as Map<String, dynamic>;
    final settings = decoded['settings'] as Map<String, dynamic>;

    // Validate and normalize every row before opening the destructive database
    // transaction. A corrupt/incompatible backup can therefore never clear the
    // user's current Hifz data.
    final validatedTables = <String, List<Map<String, Object?>>>{};
    for (final table in _tables) {
      final rows = rawTables[table];
      if (rows == null) {
        validatedTables[table] = <Map<String, Object?>>[];
        continue;
      }
      if (rows is! List) {
        throw FormatException('Invalid backup data for $table.');
      }

      final normalizedRows = <Map<String, Object?>>[];
      for (final row in rows) {
        if (row is! Map) {
          throw FormatException('Invalid row in backup table $table.');
        }
        normalizedRows.add(Map<String, Object?>.from(row));
      }
      validatedTables[table] = normalizedRows;
    }

    _validateSettings(settings);

    final db = await database.db;
    await db.transaction((txn) async {
      for (final table in _tables.reversed) {
        await txn.delete(table);
      }

      for (final table in _tables) {
        for (final row in validatedTables[table]!) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    final prefs = await SharedPreferences.getInstance();
    for (final entry in settings.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(
          entry.key,
          value.map((e) => e.toString()).toList(growable: false),
        );
      }
    }

    return true;
  }

  Map<String, dynamic> _decodeBackup(Uint8List bytes) {
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('The selected file is not a valid backup.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('The selected file is not valid backup JSON.');
    }

    if (decoded is! Map<String, dynamic> || decoded['format'] != _format) {
      throw const FormatException('This is not a Hifz Journey backup.');
    }

    final version = decoded['version'];
    if (version is! int || version < 1 || version > _backupVersion) {
      throw const FormatException('This backup version is not supported.');
    }

    if (decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('Backup tables are missing.');
    }
    if (decoded['settings'] is! Map<String, dynamic>) {
      throw const FormatException('Backup settings are missing.');
    }

    return decoded;
  }

  void _validateSettings(Map<String, dynamic> settings) {
    for (final entry in settings.entries) {
      final value = entry.value;
      final valid = value is String ||
          value is int ||
          value is double ||
          value is bool ||
          (value is List && value.every((item) => item is String));
      if (!valid) {
        throw FormatException('Invalid setting in backup: ${entry.key}.');
      }
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
