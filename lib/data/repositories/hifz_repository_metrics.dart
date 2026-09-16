import 'package:sqflite/sqflite.dart';

import '../models/ayah.dart';
import 'hifz_repository.dart';

/// Corrected progress metrics kept separate from the core repository so the
/// definitions stay explicit and easy to test.
extension HifzRepositoryMetrics on HifzRepository {
  /// Counts pages completed as Hifz today.
  ///
  /// A page counts when every ayah on that Mushaf page has been introduced,
  /// and at least one ayah on that page was newly introduced today. This means
  /// finishing a page that was started on an earlier day still counts, while a
  /// single ayah from an otherwise incomplete page never does.
  Future<int> completedPagesToday() async {
    final db = await database.db;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c
      FROM (
        SELECT a.page
        FROM ayahs a
        LEFT JOIN hifz_progress h ON h.ayah_id = a.id
        GROUP BY a.page
        HAVING COUNT(a.id) = SUM(
          CASE WHEN h.introduced_at IS NOT NULL THEN 1 ELSE 0 END
        )
        AND a.page IN (
          SELECT DISTINCT page_ayah.page
          FROM app_activity activity
          JOIN ayahs page_ayah ON page_ayah.id = activity.ayah_id
          WHERE activity.kind = 'new'
            AND activity.created_at >= ?
            AND activity.created_at < ?
        )
      ) completed_pages
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );

    return Sqflite.firstIntValue(rows) ?? 0;
  }

  /// Ayahs only enter "Needs attention" after there is actual evidence of a
  /// recall problem. A newly introduced ayah with low initial strength is
  /// learning, not weak.
  Future<List<WeakAyah>> genuineWeakAyahs({int limit = 30}) async {
    final db = await database.db;
    final rows = await db.rawQuery(
      '''
      SELECT a.*, h.strength, h.failed_recalls, h.status
      FROM hifz_progress h
      JOIN ayahs a ON a.id = h.ayah_id
      WHERE h.introduced_at IS NOT NULL
        AND h.failed_recalls > 0
        AND (h.strength < 65 OR h.failed_recalls >= 2)
      ORDER BY h.failed_recalls DESC, h.strength ASC
      LIMIT ?
      ''',
      [limit],
    );

    return rows
        .map(
          (row) => WeakAyah(
            ayah: Ayah.fromMap(row),
            strength: (row['strength'] as num?)?.toDouble() ?? 0,
            failedRecalls: (row['failed_recalls'] as num?)?.toInt() ?? 0,
            status: row['status'] as String? ?? 'learning',
          ),
        )
        .toList();
  }
}
