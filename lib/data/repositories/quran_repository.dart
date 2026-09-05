import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../models/ayah.dart';
import '../models/surah.dart';

class QuranRepository {
  final AppDatabase database;

  QuranRepository(this.database);

  Future<List<Surah>> surahs() async {
    final db = await database.db;
    final rows = await db.query('surahs', orderBy: 'id');
    return rows.map(Surah.fromMap).toList();
  }

  Future<List<Ayah>> ayahsForSurah(int id) async {
    final db = await database.db;
    final rows = await db.query(
      'ayahs',
      where: 'surah_id = ?',
      whereArgs: [id],
      orderBy: 'ayah_number',
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<Ayah?> ayah(int id) async {
    final db = await database.db;
    final rows = await db.query(
      'ayahs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Ayah.fromMap(rows.first);
  }

  Future<List<Ayah>> nextAyahs(int? afterId, int count) async {
    final db = await database.db;
    final rows = afterId == null
        ? await db.query('ayahs', orderBy: 'id', limit: count)
        : await db.query(
            'ayahs',
            where: 'id > ?',
            whereArgs: [afterId],
            orderBy: 'id',
            limit: count,
          );
    return rows.map(Ayah.fromMap).toList();
  }
}
