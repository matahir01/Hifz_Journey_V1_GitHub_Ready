import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../../data/models/ayah.dart';
import 'audio_library_service.dart';
import 'audio_reciter.dart';
import 'alquran_cloud_audio_provider.dart';

class QuranAudioService {
  final AudioPlayer player = AudioPlayer();
  final QuranAudioProvider provider;
  final StreamController<int?> _activeAyahController =
      StreamController<int?>.broadcast();
  int _playGeneration = 0;

  QuranAudioService({QuranAudioProvider? provider})
      : provider = provider ?? const AlQuranCloudAudioProvider();

  Stream<int?> get activeAyahIdStream => _activeAyahController.stream;

  Future<void> playFile(File file, {double speed = 1.0}) async {
    await player.setSpeed(speed);
    await player.setFilePath(file.path);
    await player.play();
  }

  Future<void> playAyah(
    Ayah ayah, {
    required AudioReciter reciter,
    required AudioLibraryService library,
    int repeat = 1,
    double speed = 1.0,
  }) async {
    await stop();
    final generation = ++_playGeneration;
    _activeAyahController.add(ayah.id);
    for (var i = 0; i < repeat; i++) {
      if (generation != _playGeneration) break;
      final local = await library.forAyah(ayah.id, reciterId: reciter.id);
      await player.setSpeed(speed);
      if (local != null) {
        await player.setFilePath(local.localPath);
      } else {
        final uri = provider.ayahUri(
          reciter: reciter,
          globalAyahNumber: ayah.id,
        );
        await player.setUrl(uri.toString());
      }
      await player.play();
      if (generation != _playGeneration ||
          player.processingState != ProcessingState.completed) {
        break;
      }
    }
    if (generation == _playGeneration) _activeAyahController.add(null);
  }

  Future<void> playSequence(
    List<Ayah> ayahs, {
    required AudioReciter reciter,
    required AudioLibraryService library,
    int repeatEach = 1,
    double speed = 1.0,
    int startIndex = 0,
  }) async {
    await stop();
    final generation = ++_playGeneration;
    for (var index = startIndex; index < ayahs.length; index++) {
      if (generation != _playGeneration) break;
      final ayah = ayahs[index];
      _activeAyahController.add(ayah.id);
      for (var r = 0; r < repeatEach; r++) {
        if (generation != _playGeneration) break;
        final local = await library.forAyah(ayah.id, reciterId: reciter.id);
        await player.setSpeed(speed);
        if (local != null) {
          await player.setFilePath(local.localPath);
        } else {
          final uri = provider.ayahUri(
            reciter: reciter,
            globalAyahNumber: ayah.id,
          );
          await player.setUrl(uri.toString());
        }
        await player.play();
        if (generation != _playGeneration ||
            player.processingState != ProcessingState.completed) {
          break;
        }
      }
    }
    if (generation == _playGeneration) _activeAyahController.add(null);
  }

  Future<void> pause() => player.pause();

  Future<void> resume() => player.play();

  Future<void> stop() async {
    _playGeneration++;
    await player.stop();
    _activeAyahController.add(null);
  }

  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> repeatFile(File file, int times, {double speed = 1.0}) async {
    await player.setSpeed(speed);
    for (var i = 0; i < times; i++) {
      await player.setFilePath(file.path);
      await player.play();
      await player.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
    }
  }

  Future<void> dispose() async {
    await _activeAyahController.close();
    await player.dispose();
  }
}
