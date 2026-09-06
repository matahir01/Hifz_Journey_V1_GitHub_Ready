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
      version: 2,
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
        reciter TEXT,
        local_path TEXT,
        downloaded_at TEXT,
        FOREIGN KEY(ayah_id) REFERENCES ayahs(id)
      )
    ''');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_ayahs_surah ON ayahs(surah_id, ayah_number)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_ayahs_page ON ayahs(page, id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_ayahs_juz ON ayahs(juz, id)',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_hifz_due ON hifz_progress(next_review_at, strength)',
    );
  }
}
