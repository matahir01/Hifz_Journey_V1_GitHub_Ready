class Surah {
  final int id;
  final int ayahCount;
  final int revelationOrder;
  final int rukus;
  final String nameAr;
  final String translit;
  final String nameEn;
  final String type;

  const Surah({
    required this.id,
    required this.ayahCount,
    required this.revelationOrder,
    required this.rukus,
    required this.nameAr,
    required this.translit,
    required this.nameEn,
    required this.type,
  });

  factory Surah.fromMap(Map<String, Object?> map) {
    return Surah(
      id: map['id'] as int,
      ayahCount: map['ayah_count'] as int,
      revelationOrder: map['revelation_order'] as int? ?? 0,
      rukus: map['rukus'] as int? ?? 0,
      nameAr: map['name_ar'] as String,
      translit: map['name_en_translit'] as String,
      nameEn: map['name_en'] as String,
      type: map['revelation_type'] as String,
    );
  }
}
