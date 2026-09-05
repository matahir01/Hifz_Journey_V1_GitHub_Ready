class Ayah {
  final int id, surahId, ayahNumber, page, juz;
  final String textUthmani, textSimple;
  const Ayah({required this.id, required this.surahId, required this.ayahNumber, required this.textUthmani, required this.textSimple, required this.page, required this.juz});
  factory Ayah.fromMap(Map<String,Object?> m)=>Ayah(id:m['id'] as int,surahId:m['surah_id'] as int,ayahNumber:m['ayah_number'] as int,textUthmani:m['text_uthmani'] as String,textSimple:m['text_simple'] as String,page:m['page'] as int,juz:m['juz'] as int);
}
