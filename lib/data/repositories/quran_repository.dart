import 'package:sqflite/sqflite.dart';
import '../models/ayah.dart'; import '../models/surah.dart'; import '../../core/database/app_database.dart';
class QuranRepository {
  final AppDatabase database; QuranRepository(this.database);
  Future<List<Surah>> surahs() async {final d=await database.db; final r=await d.query('surahs',orderBy:'id'); return r.map(Surah.fromMap).toList();}
  Future<List<Ayah>> ayahsForSurah(int id) async {final d=await database.db; final r=await d.query('ayahs',where:'surah_id=?',whereArgs:[id],orderBy:'ayah_number'); return r.map(Ayah.fromMap).toList();}
  Future<Ayah?> ayah(int id) async {final d=await database.db; final r=await d.query('ayahs',where:'id=?',whereArgs:[id],limit:1); return r.isEmpty?null:Ayah.fromMap(r.first);}
  Future<List<Ayah>> nextAyahs(int? afterId,int count) async {final d=await database.db; final r=afterId==null?await d.query('ayahs',orderBy:'id',limit:count):await d.query('ayahs',where:'id>?',whereArgs:[afterId],orderBy:'id',limit:count); return r.map(Ayah.fromMap).toList();}
}
