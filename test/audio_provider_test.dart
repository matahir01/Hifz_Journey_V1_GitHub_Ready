import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/core/audio/alquran_cloud_audio_provider.dart';
import 'package:hifz_journey/core/audio/audio_reciter.dart';

void main() {
  const provider = AlQuranCloudAudioProvider();

  test('Al Quran Cloud provider builds Alafasy ayah CDN URL', () {
    final uri = provider.ayahUri(
      reciter: AudioReciters.alafasy,
      globalAyahNumber: 262,
    );
    expect(
      uri.toString(),
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/262.mp3',
    );
  });

  test('uses canonical CDN editions for the repaired reciters', () {
    expect(
      provider
          .ayahUri(reciter: AudioReciters.sudais, globalAyahNumber: 1)
          .toString(),
      'https://cdn.islamic.network/quran/audio/192/ar.abdurrahmaansudais/1.mp3',
    );
    expect(
      provider
          .ayahUri(reciter: AudioReciters.shuraim, globalAyahNumber: 1)
          .toString(),
      'https://cdn.islamic.network/quran/audio/64/ar.saoodshuraym/1.mp3',
    );
    expect(
      provider
          .ayahUri(reciter: AudioReciters.abdulBasit, globalAyahNumber: 1)
          .toString(),
      'https://cdn.islamic.network/quran/audio/192/ar.abdulbasitmurattal/1.mp3',
    );
    expect(
      provider
          .ayahUri(reciter: AudioReciters.ajamy, globalAyahNumber: 1)
          .toString(),
      'https://cdn.islamic.network/quran/audio/128/ar.ahmedajamy/1.mp3',
    );
  });

  test('Al Quran Cloud provider rejects invalid global ayah number', () {
    expect(
      () => provider.ayahUri(
        reciter: AudioReciters.alafasy,
        globalAyahNumber: 0,
      ),
      throwsRangeError,
    );
  });
}
