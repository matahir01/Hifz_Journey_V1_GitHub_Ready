class AudioReciter {
  final String id;
  final String name;
  final String edition;
  final int bitrateKbps;
  final String style;

  const AudioReciter({
    required this.id,
    required this.name,
    required this.edition,
    required this.bitrateKbps,
    this.style = 'Murattal',
  });
}

class AudioReciters {
  static const alafasy = AudioReciter(
    id: 'alquran_ar_alafasy_128',
    name: 'Mishary Rashid Alafasy',
    edition: 'ar.alafasy',
    bitrateKbps: 128,
  );

  static const sudais = AudioReciter(
    id: 'alquran_ar_sudais_192',
    name: 'Abdul Rahman Al-Sudais',
    edition: 'ar.sudais',
    bitrateKbps: 192,
  );

  static const husary = AudioReciter(
    id: 'alquran_ar_husary_128',
    name: 'Mahmoud Khalil Al-Husary',
    edition: 'ar.husary',
    bitrateKbps: 128,
  );

  static const minshawi = AudioReciter(
    id: 'alquran_ar_minshawi_128',
    name: 'Mohamed Siddiq Al-Minshawi',
    edition: 'ar.minshawi',
    bitrateKbps: 128,
  );

  static const shuraim = AudioReciter(
    id: 'alquran_ar_shuraim_128',
    name: 'Saud Al-Shuraim',
    edition: 'ar.shuraim',
    bitrateKbps: 128,
  );

  static const abdulBasit = AudioReciter(
    id: 'alquran_ar_abdulbasit_192',
    name: 'Abdul Basit Abdul Samad',
    edition: 'ar.abdulbasit',
    bitrateKbps: 192,
  );

  static const ajamy = AudioReciter(
    id: 'alquran_ar_ajamy_128',
    name: 'Ahmed ibn Ali Al-Ajamy',
    edition: 'ar.ajamy',
    bitrateKbps: 128,
  );

  static const hudhaify = AudioReciter(
    id: 'alquran_ar_hudhaify_128',
    name: 'Ali Al-Hudhaify',
    edition: 'ar.hudhaify',
    bitrateKbps: 128,
  );

  static const all = <AudioReciter>[
    alafasy,
    sudais,
    husary,
    minshawi,
    shuraim,
    abdulBasit,
    ajamy,
    hudhaify,
  ];

  static AudioReciter byId(String? id) => all.firstWhere(
        (reciter) => reciter.id == id,
        orElse: () => alafasy,
      );
}
