import 'audio_reciter.dart';

abstract class QuranAudioProvider {
  Uri ayahUri({
    required AudioReciter reciter,
    required int globalAyahNumber,
  });
}

class AlQuranCloudAudioProvider implements QuranAudioProvider {
  static const _base = 'https://cdn.islamic.network/quran/audio';

  const AlQuranCloudAudioProvider();

  @override
  Uri ayahUri({
    required AudioReciter reciter,
    required int globalAyahNumber,
  }) {
    if (globalAyahNumber < 1 || globalAyahNumber > 6236) {
      throw RangeError.range(
        globalAyahNumber,
        1,
        6236,
        'globalAyahNumber',
      );
    }
    return Uri.parse(
      '$_base/${reciter.bitrateKbps}/${reciter.edition}/$globalAyahNumber.mp3',
    );
  }
}
