class Ayah {
  final int id;
  final int surahId;
  final int ayahNumber;
  final int page;
  final int juz;
  final String textUthmani;
  final String textSimple;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.textUthmani,
    required this.textSimple,
    required this.page,
    required this.juz,
  });

  factory Ayah.fromMap(Map<String, Object?> map) {
    return Ayah(
      id: map['id'] as int,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int,
      textUthmani: map['text_uthmani'] as String,
      textSimple: map['text_simple'] as String,
      page: map['page'] as int,
      juz: map['juz'] as int,
    );
  }
}
