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

  Future<Surah?> surah(int id) async {
    final db = await database.db;
    final rows = await db.query(
      'surahs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Surah.fromMap(rows.first);
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

  Future<List<Ayah>> allAyahs() async {
    final db = await database.db;
    final rows = await db.query('ayahs', orderBy: 'id');
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

  Future<List<Ayah>> search(String query, {int limit = 80}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await database.db;

    final reference = RegExp(r'^(\d{1,3})\s*[:：]\s*(\d{1,3})$').firstMatch(q);
    if (reference != null) {
      final surahId = int.tryParse(reference.group(1)!);
      final ayahNumber = int.tryParse(reference.group(2)!);
      if (surahId != null && ayahNumber != null) {
        final rows = await db.query(
          'ayahs',
          where: 'surah_id = ? AND ayah_number = ?',
          whereArgs: [surahId, ayahNumber],
          limit: 1,
        );
        return rows.map(Ayah.fromMap).toList();
      }
    }

    final rows = await db.query(
      'ayahs',
      where: 'text_simple LIKE ? OR text_uthmani LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'id',
      limit: limit,
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<void> saveReadingProgress(Ayah ayah) async {
    final db = await database.db;
    await db.insert(
      'reading_progress',
      {
        'id': 1,
        'last_ayah_id': ayah.id,
        'last_page': ayah.page,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Ayah?> lastRead() async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT a.*
      FROM reading_progress r
      JOIN ayahs a ON a.id = r.last_ayah_id
      WHERE r.id = 1 AND r.last_ayah_id IS NOT NULL
      LIMIT 1
    ''');
    return rows.isEmpty ? null : Ayah.fromMap(rows.first);
  }

  Future<bool> isBookmarked(int ayahId) async {
    final db = await database.db;
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'ayah_id = ? AND type = ?',
      whereArgs: [ayahId, 'ayah'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<int>> bookmarkedIdsForSurah(int surahId) async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT b.ayah_id
      FROM bookmarks b
      JOIN ayahs a ON a.id = b.ayah_id
      WHERE b.type = 'ayah' AND a.surah_id = ?
    ''', [surahId]);
    return rows.map((row) => row['ayah_id'] as int).toSet();
  }

  Future<void> setBookmark(int ayahId, bool bookmarked) async {
    final db = await database.db;
    if (bookmarked) {
      await db.insert(
        'bookmarks',
        {
          'ayah_id': ayahId,
          'type': 'ayah',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete(
        'bookmarks',
        where: 'ayah_id = ? AND type = ?',
        whereArgs: [ayahId, 'ayah'],
      );
    }
  }

  Future<List<Ayah>> bookmarks() async {
    final db = await database.db;
    final rows = await db.rawQuery('''
      SELECT a.*
      FROM bookmarks b
      JOIN ayahs a ON a.id = b.ayah_id
      WHERE b.type = 'ayah'
      ORDER BY b.created_at DESC
    ''');
    return rows.map(Ayah.fromMap).toList();
  }

  Future<Ayah?> firstAyahOfJuz(int juz) async {
    final db = await database.db;
    final rows = await db.query(
      'ayahs',
      where: 'juz = ?',
      whereArgs: [juz],
      orderBy: 'id',
      limit: 1,
    );
    return rows.isEmpty ? null : Ayah.fromMap(rows.first);
  }

  Future<Ayah?> firstAyahOfPage(int page) async {
    final db = await database.db;
    final rows = await db.query(
      'ayahs',
      where: 'page = ?',
      whereArgs: [page],
      orderBy: 'id',
      limit: 1,
    );
    return rows.isEmpty ? null : Ayah.fromMap(rows.first);
  }

  Future<int> maxPage() async {
    final db = await database.db;
    final rows = await db.rawQuery('SELECT MAX(page) AS page FROM ayahs');
    return (rows.first['page'] as int?) ?? 604;
  }
}
