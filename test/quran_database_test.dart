import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hifz_journey/core/database/app_database.dart';
import 'package:hifz_journey/data/repositories/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final repository = QuranRepository(AppDatabase.instance);

  test('bundled database has 6236 ayahs', () async {
    final database = await AppDatabase.instance.db;
    final result = await database.rawQuery('SELECT COUNT(*) c FROM ayahs');
    expect(result.first['c'], 6236);
  });

  test('bundled database has 114 surahs', () async {
    final surahs = await repository.surahs();
    expect(surahs.length, 114);
  });

  test('Quran reference search resolves Ayat al-Kursi', () async {
    final result = await repository.search('2:255');
    expect(result, hasLength(1));
    expect(result.first.surahId, 2);
    expect(result.first.ayahNumber, 255);
  });

  test('juz and page navigation have starting ayahs', () async {
    expect(await repository.firstAyahOfJuz(1), isNotNull);
    expect(await repository.firstAyahOfJuz(30), isNotNull);
    expect(await repository.firstAyahOfPage(1), isNotNull);
    expect(await repository.firstAyahOfPage(604), isNotNull);
  });
}
