import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final instance = AppDatabase._();
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
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(
      path,
      version: 1,
      onOpen: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
}
