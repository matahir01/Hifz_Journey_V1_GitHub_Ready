import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hifz_journey/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('bundled database has 6236 ayahs', () async {
    final database = await AppDatabase.instance.db;
    final result = await database.rawQuery('SELECT COUNT(*) c FROM ayahs');
    expect(result.first['c'], 6236);
  });

  test('has 114 surahs', () async {
    final database = await AppDatabase.instance.db;
    final result = await database.rawQuery('SELECT COUNT(*) c FROM surahs');
    expect(result.first['c'], 114);
  });
}
