class Surah {
  final int id, ayahCount, revelationOrder, rukus; final String nameAr, translit, nameEn, type;
  const Surah({required this.id,required this.ayahCount,required this.revelationOrder,required this.rukus,required this.nameAr,required this.translit,required this.nameEn,required this.type});
  factory Surah.fromMap(Map<String,Object?> m)=>Surah(id:m['id'] as int,ayahCount:m['ayah_count'] as int,revelationOrder:m['revelation_order'] as int? ?? 0,rukus:m['rukus'] as int? ?? 0,nameAr:m['name_ar'] as String,translit:m['name_en_translit'] as String,nameEn:m['name_en'] as String,type:m['revelation_type'] as String);
}
