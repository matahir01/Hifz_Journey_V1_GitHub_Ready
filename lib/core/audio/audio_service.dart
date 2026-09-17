import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/models/ayah.dart';
import 'audio_library_service.dart';
import 'audio_reciter.dart';
import 'alquran_cloud_audio_provider.dart';

class QuranAudioService {
  static const int _lastGlobalAyahId = 6236;
  static const int _continuationChunkAyahs = 80;

  final AudioPlayer player = AudioPlayer(maxSkipsOnError: 3);
  final QuranAudioProvider provider;
  final bool continuousQuran;
  final StreamController<int?> _activeAyahController =
      StreamController<int?>.broadcast();

  int _playGeneration = 0;
  int? _activeAyahId;
  Completer<void>? _playbackCompletion;

  QuranAudioService({
    QuranAudioProvider? provider,
    this.continuousQuran = false,
  }) : provider = provider ?? const AlQuranCloudAudioProvider();

  Stream<int?> get activeAyahIdStream => _activeAyahController.stream;
  Stream<bool> get playingStream => player.playingStream;
  int? get activeAyahId => _activeAyahId;
  bool get isPlaying => player.playing;

  void _setActiveAyah(int? id) {
    _activeAyahId = id;
    if (!_activeAyahController.isClosed) {
      _activeAyahController.add(id);
    }
  }

  MediaItem _mediaItem(Ayah ayah, AudioReciter reciter) {
    return MediaItem(
      id: 'ayah-${ayah.id}',
      album: 'Qur’an • ${reciter.name}',
      title: 'Surah ${ayah.surahId} • Ayah ${ayah.ayahNumber}',
      artist: reciter.name,
      extras: {
        'ayah_id': ayah.id,
        'surah_id': ayah.surahId,
        'ayah_number': ayah.ayahNumber,
      },
    );
  }

  MediaItem _mediaItemForGlobalAyah(int ayahId, AudioReciter reciter) {
    return MediaItem(
      id: 'ayah-$ayahId',
      album: 'Qur’an • ${reciter.name}',
      title: 'Qur’an • Ayah $ayahId',
      artist: reciter.name,
      extras: {'ayah_id': ayahId},
    );
  }

  Future<Uri> _uriForAyah(
    Ayah ayah, {
    required AudioReciter reciter,
    required AudioLibraryService library,
  }) async {
    return _uriForGlobalAyah(
      ayah.id,
      reciter: reciter,
      library: library,
    );
  }

  Future<Uri> _uriForGlobalAyah(
    int ayahId, {
    required AudioReciter reciter,
    required AudioLibraryService library,
  }) async {
    final local = await library.forAyah(ayahId, reciterId: reciter.id);
    if (local != null) return Uri.file(local.localPath);
    return provider.ayahUri(
      reciter: reciter,
      globalAyahNumber: ayahId,
    );
  }

  Future<void> playFile(File file, {double speed = 1.0}) async {
    await stop();
    final generation = ++_playGeneration;
    final source = AudioSource.file(
      file.path,
      tag: MediaItem(
        id: file.path,
        album: 'Hifz Journey',
        title: 'Qur’an audio',
      ),
    );
    await player.setSpeed(speed);
    await player.setAudioSource(source);
    if (generation != _playGeneration) return;
    await player.play();
  }

  Future<void> playAyah(
    Ayah ayah, {
    required AudioReciter reciter,
    required AudioLibraryService library,
    int repeat = 1,
    double speed = 1.0,
  }) {
    return playSequence(
      [ayah],
      reciter: reciter,
      library: library,
      repeatEach: repeat,
      speed: speed,
      continueBeyondSequence: false,
    );
  }

  Future<void> playSequence(
    List<Ayah> ayahs, {
    required AudioReciter reciter,
    required AudioLibraryService library,
    int repeatEach = 1,
    double speed = 1.0,
    int startIndex = 0,
    bool? continueBeyondSequence,
  }) async {
    if (ayahs.isEmpty) return;

    await stop();
    final generation = ++_playGeneration;
    final safeStart = startIndex.clamp(0, ayahs.length - 1).toInt();
    final repeats = repeatEach.clamp(1, 20).toInt();
    final shouldContinue = continueBeyondSequence ?? continuousQuran;
    final queueAyahIds = <int>[];
    final sources = <AudioSource>[];

    for (var index = safeStart; index < ayahs.length; index++) {
      if (generation != _playGeneration) return;
      final ayah = ayahs[index];
      final uri = await _uriForAyah(
        ayah,
        reciter: reciter,
        library: library,
      );
      final item = _mediaItem(ayah, reciter);
      for (var repeatIndex = 0; repeatIndex < repeats; repeatIndex++) {
        queueAyahIds.add(ayah.id);
        sources.add(AudioSource.uri(uri, tag: item));
      }
    }

    if (sources.isEmpty || generation != _playGeneration) return;

    var nextGlobalAyahId = ayahs.last.id + 1;

    Future<({List<AudioSource> sources, List<int> ids})>
        buildContinuationChunk() async {
      final chunkSources = <AudioSource>[];
      final chunkIds = <int>[];
      if (!shouldContinue || nextGlobalAyahId > _lastGlobalAyahId) {
        return (sources: chunkSources, ids: chunkIds);
      }

      final end = (nextGlobalAyahId + _continuationChunkAyahs - 1)
          .clamp(1, _lastGlobalAyahId)
          .toInt();
      for (var ayahId = nextGlobalAyahId; ayahId <= end; ayahId++) {
        if (generation != _playGeneration) break;
        final uri = await _uriForGlobalAyah(
          ayahId,
          reciter: reciter,
          library: library,
        );
        final item = _mediaItemForGlobalAyah(ayahId, reciter);
        for (var repeatIndex = 0; repeatIndex < repeats; repeatIndex++) {
          chunkIds.add(ayahId);
          chunkSources.add(AudioSource.uri(uri, tag: item));
        }
      }
      nextGlobalAyahId = end + 1;
      return (sources: chunkSources, ids: chunkIds);
    }

    if (shouldContinue && nextGlobalAyahId <= _lastGlobalAyahId) {
      final firstContinuation = await buildContinuationChunk();
      if (generation != _playGeneration) return;
      queueAyahIds.addAll(firstContinuation.ids);
      sources.addAll(firstContinuation.sources);
    }

    await player.setSpeed(speed);
    await player.setAudioSources(sources);
    if (generation != _playGeneration) return;

    final completion = Completer<void>();
    _playbackCompletion = completion;
    var playbackStarted = false;
    var continuationLoading = false;
    final refillThreshold = (repeats * 12) > 24 ? (repeats * 12) : 24;

    Future<void> appendContinuation() async {
      if (!shouldContinue ||
          continuationLoading ||
          nextGlobalAyahId > _lastGlobalAyahId ||
          generation != _playGeneration) {
        return;
      }
      continuationLoading = true;
      try {
        final chunk = await buildContinuationChunk();
        if (generation != _playGeneration || chunk.sources.isEmpty) return;
        queueAyahIds.addAll(chunk.ids);
        await player.addAudioSources(chunk.sources);
      } finally {
        continuationLoading = false;
      }
    }

    final stateSubscription = player.processingStateStream.listen((state) {
      if (!playbackStarted || completion.isCompleted) return;
      if (state == ProcessingState.completed ||
          state == ProcessingState.idle) {
        completion.complete();
      }
    });

    final indexSubscription = player.currentIndexStream.listen((index) {
      if (generation != _playGeneration ||
          index == null ||
          index < 0 ||
          index >= queueAyahIds.length) {
        return;
      }
      _setActiveAyah(queueAyahIds[index]);

      final remainingSources = queueAyahIds.length - index - 1;
      if (remainingSources <= refillThreshold) {
        unawaited(appendContinuation());
      }
    });

    _setActiveAyah(queueAyahIds.first);
    playbackStarted = true;
    unawaited(player.play());

    await completion.future;
    await stateSubscription.cancel();
    await indexSubscription.cancel();

    if (_playbackCompletion == completion) {
      _playbackCompletion = null;
    }
    if (generation == _playGeneration) {
      _setActiveAyah(null);
    }
  }

  Future<void> pause() => player.pause();

  Future<void> resume() => player.play();

  Future<void> stop() async {
    _playGeneration++;
    final completion = _playbackCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
    _playbackCompletion = null;
    await player.stop();
    _setActiveAyah(null);
  }

  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  Future<void> repeatFile(
    File file,
    int times, {
    double speed = 1.0,
  }) async {
    await stop();
    final generation = ++_playGeneration;
    final count = times.clamp(1, 20).toInt();
    final sources = <AudioSource>[
      for (var index = 0; index < count; index++)
        AudioSource.file(
          file.path,
          tag: MediaItem(
            id: '${file.path}#$index',
            album: 'Hifz Journey',
            title: 'Qur’an audio',
          ),
        ),
    ];
    await player.setSpeed(speed);
    await player.setAudioSources(sources);
    if (generation != _playGeneration) return;
    await player.play();
  }

  Future<void> dispose() async {
    final completion = _playbackCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
    _playbackCompletion = null;
    await _activeAyahController.close();
    await player.dispose();
  }
}
