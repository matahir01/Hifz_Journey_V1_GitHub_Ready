import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

class HifzRepository {
  final AppDatabase database;

  HifzRepository(this.database);

  Future<Map<String, Object?>?> progress(int id) async {
    final db = await database.db;
    final rows = await db.query(
      'hifz_progress',
      where: 'ayah_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> ensure(int id) async {
    final db = await database.db;
    await db.insert(
      'hifz_progress',
      {'ayah_id': id},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> record(int id, bool success, {double? score}) async {
    final db = await database.db;
    await ensure(id);

    final now = DateTime.now();
    final old = await progress(id);
    final strength = (old?['strength'] as num? ?? 0).toDouble();
    final newStrength = (success
            ? strength + ((100 - strength) * 0.22)
            : strength * 0.55)
        .clamp(0, 100)
        .toDouble();
    final successfulRecalls =
        (old?['successful_recalls'] as int? ?? 0) + (success ? 1 : 0);
    final failedRecalls =
        (old?['failed_recalls'] as int? ?? 0) + (success ? 0 : 1);
    final consecutiveSuccesses = success
        ? (old?['consecutive_successes'] as int? ?? 0) + 1
        : 0;
    final intervals = [1, 2, 4, 7, 14, 30, 60];
    final intervalIndex = (consecutiveSuccesses - 1).clamp(0, 6);
    final interval = success ? intervals[intervalIndex] : 1;
    final next = now.add(Duration(days: interval));
    final status = newStrength >= 85
        ? 'mastered'
        : newStrength >= 65
            ? 'stable'
            : newStrength > 0
                ? 'learning'
                : 'new';

    await db.update(
      'hifz_progress',
      {
        'status': status,
        'strength': newStrength,
        'last_reviewed_at': now.toIso8601String(),
        'next_review_at': next.toIso8601String(),
        'successful_recalls': successfulRecalls,
        'failed_recalls': failedRecalls,
        'consecutive_successes': consecutiveSuccesses,
        'introduced_at': old?['introduced_at'] ?? now.toIso8601String(),
      },
      where: 'ayah_id = ?',
      whereArgs: [id],
    );
  }

  Future<List<int>> dueIds({int limit = 20}) async {
    final db = await database.db;
    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'hifz_progress',
      columns: ['ayah_id'],
      where: 'next_review_at IS NOT NULL AND next_review_at <= ?',
      whereArgs: [now],
      orderBy: 'strength ASC, next_review_at ASC',
      limit: limit,
    );
    return rows.map((row) => row['ayah_id'] as int).toList();
  }

  Future<int> memorizedCount() async {
    final db = await database.db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM hifz_progress WHERE strength >= 65',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
