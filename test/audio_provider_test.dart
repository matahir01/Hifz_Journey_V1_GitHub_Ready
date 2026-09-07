import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/core/audio/alquran_cloud_audio_provider.dart';
import 'package:hifz_journey/core/audio/audio_reciter.dart';

void main() {
  test('Al Quran Cloud provider builds ayah CDN URL', () {
    const provider = AlQuranCloudAudioProvider();
    final uri = provider.ayahUri(
      reciter: AudioReciters.alafasy,
      globalAyahNumber: 262,
    );
    expect(
      uri.toString(),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3',
    );
  });

  test('Al Quran Cloud provider rejects invalid global ayah number', () {
    const provider = AlQuranCloudAudioProvider();
    expect(
      () => provider.ayahUri(
        reciter: AudioReciters.alafasy,
        globalAyahNumber: 0,
      ),
      throwsRangeError,
    );
  });
}
