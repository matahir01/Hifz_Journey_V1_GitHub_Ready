import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'hifz_journey.db');

    if (!await File(path).exists()) {
      final data = await rootBundle.load('assets/quran/quran.db');
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(
      path,
      version: 7,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: _ensureRuntimeSchema,
      onUpgrade: (database, oldVersion, newVersion) async {
        await _ensureRuntimeSchema(database);
      },
    );
  }

  Future<void> _ensureRuntimeSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS audio_metadata(
        ayah_id INTEGER PRIMARY KEY,
        reciter TEXT NOT NULL DEFAULT 'Local audio',
        local_path TEXT NOT NULL,
        source_name TEXT,
        downloaded_at TEXT NOT NULL,
        FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');
    await _ensureColumn(database, 'audio_metadata', 'source_name', 'TEXT');
    await _ensureColumn(database, 'audio_metadata', 'reciter_id', "TEXT NOT NULL DEFAULT 'local'");
    await _ensureColumn(database, 'audio_metadata', 'source_url', 'TEXT');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS recitation_attempts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ayah_id INTEGER NOT NULL,
        recognizer TEXT,
        transcript TEXT,
        score REAL NOT NULL DEFAULT 0,
        grade TEXT,
        issues TEXT,
        correct_words INTEGER NOT NULL DEFAULT 0,
        missing_words INTEGER NOT NULL DEFAULT 0,
        substituted_words INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');
    await _ensureColumn(database, 'recitation_attempts', 'recognizer', 'TEXT');
    await _ensureColumn(database, 'recitation_attempts', 'grade', 'TEXT');
    await _ensureColumn(database, 'recitation_attempts', 'issues', 'TEXT');
    await _ensureColumn(database, 'recitation_attempts', 'correct_words', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(database, 'recitation_attempts', 'missing_words', 'INTEGER NOT NULL DEFAULT 0');
    await _ensureColumn(database, 'recitation_attempts', 'substituted_words', 'INTEGER NOT NULL DEFAULT 0');

    await database.execute('''
      CREATE TABLE IF NOT EXISTS app_activity(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ayah_id INTEGER,
        kind TEXT NOT NULL,
        grade TEXT,
        score REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');

    await database.execute('CREATE INDEX IF NOT EXISTS idx_recitation_attempts_ayah ON recitation_attempts(ayah_id, created_at)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_surah ON ayahs(surah_id, ayah_number)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_page ON ayahs(page, id)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_ayahs_juz ON ayahs(juz, id)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_hifz_due ON hifz_progress(next_review_at, strength)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_activity_created ON app_activity(created_at)');
  }

  Future<void> _ensureColumn(
    Database database,
    String table,
    String column,
    String definition,
  ) async {
    final info = await database.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await database.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }
}
