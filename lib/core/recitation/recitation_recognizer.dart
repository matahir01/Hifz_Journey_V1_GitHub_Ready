import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

class RecitationRecognitionState {
  final bool available;
  final bool listening;
  final String transcript;
  final double confidence;
  final String? error;

  const RecitationRecognitionState({
    required this.available,
    required this.listening,
    required this.transcript,
    required this.confidence,
    this.error,
  });

  factory RecitationRecognitionState.initial() =>
      const RecitationRecognitionState(
        available: false,
        listening: false,
        transcript: '',
        confidence: 0,
      );

  RecitationRecognitionState copyWith({
    bool? available,
    bool? listening,
    String? transcript,
    double? confidence,
    String? error,
    bool clearError = false,
  }) {
    return RecitationRecognitionState(
      available: available ?? this.available,
      listening: listening ?? this.listening,
      transcript: transcript ?? this.transcript,
      confidence: confidence ?? this.confidence,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

abstract class RecitationRecognizer {
  Stream<RecitationRecognitionState> get states;
  RecitationRecognitionState get state;

  Future<bool> initialize();
  Future<void> start({bool preferOnDevice = false});
  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

/// Fast Android/iOS Arabic recognizer.
///
/// Uses the normal network-backed speech service by default. Android speech
/// providers often end an individual recognition session after a pause or a
/// short internal limit, and some providers emit rolling partial chunks rather
/// than one cumulative sentence. Hifz Journey therefore checkpoints every
/// recognized chunk and silently opens a new provider segment when necessary.
/// Already-heard text is monotonic: later callbacks may add/correct the tail,
/// but they are never allowed to erase earlier recitation progress.
class DeviceArabicRecitationRecognizer implements RecitationRecognizer {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _controller =
      StreamController<RecitationRecognitionState>.broadcast();

  RecitationRecognitionState _state =
      RecitationRecognitionState.initial();

  final List<String> _arabicLocales = <String>[];
  int _localeIndex = 0;
  bool _keepListening = false;
  bool _starting = false;
  bool _switchingLocale = false;
  String _committedTranscript = '';
  String _currentSegment = '';
  Timer? _restartTimer;
  int _busyRetries = 0;
  int _latinOnlyStreak = 0;

  @override
  Stream<RecitationRecognitionState> get states => _controller.stream;

  @override
  RecitationRecognitionState get state => _state;

  void _emit(RecitationRecognitionState value) {
    _state = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  String get _activeLocale =>
      _arabicLocales.isEmpty ? 'ar-SA' : _arabicLocales[_localeIndex];

  String get _combinedTranscript =>
      _mergeText(_committedTranscript, _currentSegment);

  static bool _containsArabicScript(String text) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text);
  }

  static bool _containsLatinLetters(String text) {
    return RegExp(r'[A-Za-z]').hasMatch(text);
  }

  static String _normalizeToken(String value) {
    return value
        .replaceAll(
          RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
          '',
        )
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'[^\u0621-\u064A]'), '');
  }

  static List<String> _normalizedWords(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .map(_normalizeToken)
      .where((word) => word.isNotEmpty)
      .toList(growable: false);

  static bool _isPrefix(List<String> prefix, List<String> value) {
    if (prefix.length > value.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != value[i]) return false;
    }
    return true;
  }

  /// Merge speech-provider hypotheses without ever letting a later callback
  /// erase words that were already heard. Some Android providers send a full
  /// cumulative hypothesis, while others send short rolling chunks. We handle
  /// both forms here.
  static String _mergeText(String previous, String current) {
    final oldText = previous.trim();
    final newText = current.trim();
    if (oldText.isEmpty) return newText;
    if (newText.isEmpty) return oldText;

    final oldWords = oldText.split(RegExp(r'\s+'));
    final newWords = newText.split(RegExp(r'\s+'));
    final oldNorm = _normalizedWords(oldText);
    final newNorm = _normalizedWords(newText);

    if (oldNorm.isNotEmpty && newNorm.isNotEmpty) {
      // Normal cumulative partial: the provider extends what it already sent.
      if (_isPrefix(oldNorm, newNorm)) return newText;

      // Provider briefly regressed to a shorter partial. Keep the longer text.
      if (_isPrefix(newNorm, oldNorm)) return oldText;

      // Same cumulative hypothesis with a revised tail. Prefer the longer/newer
      // form, but preserve the previous one if the provider shortened it.
      final minLength =
          oldNorm.length < newNorm.length ? oldNorm.length : newNorm.length;
      var commonPrefix = 0;
      while (commonPrefix < minLength &&
          oldNorm[commonPrefix] == newNorm[commonPrefix]) {
        commonPrefix++;
      }
      if (commonPrefix >= 2 && commonPrefix * 2 >= minLength) {
        return newNorm.length >= oldNorm.length ? newText : oldText;
      }
    }

    // Rolling-chunk mode: append only the non-overlapping tail.
    final maxOverlap =
        oldWords.length < newWords.length ? oldWords.length : newWords.length;
    var overlap = 0;
    for (var count = maxOverlap; count > 0; count--) {
      var same = true;
      for (var i = 0; i < count; i++) {
        final a = _normalizeToken(oldWords[oldWords.length - count + i]);
        final b = _normalizeToken(newWords[i]);
        if (a.isEmpty || b.isEmpty || a != b) {
          same = false;
          break;
        }
      }
      if (same) {
        overlap = count;
        break;
      }
    }

    if (overlap == newWords.length) return oldText;
    return <String>[
      ...oldWords,
      ...newWords.skip(overlap),
    ].join(' ');
  }

  void _commitCurrentSegment() {
    final current = _currentSegment.trim();
    if (current.isEmpty) return;
    _committedTranscript = _mergeText(_committedTranscript, current);
    _currentSegment = '';
  }

  void _buildArabicLocaleList(List<stt.LocaleName> locales) {
    _arabicLocales.clear();

    void addMatching(String wanted) {
      final normalizedWanted = wanted.toLowerCase().replaceAll('-', '_');
      for (final locale in locales) {
        final normalized = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (normalized == normalizedWanted &&
            !_arabicLocales.contains(locale.localeId)) {
          _arabicLocales.add(locale.localeId);
        }
      }
    }

    for (final preferred in const [
      'ar_SA',
      'ar_EG',
      'ar_AE',
      'ar_QA',
      'ar_KW',
      'ar_BH',
      'ar_OM',
      'ar_JO',
    ]) {
      addMatching(preferred);
    }

    for (final locale in locales) {
      final normalized = locale.localeId.toLowerCase();
      if (normalized.startsWith('ar') &&
          !_arabicLocales.contains(locale.localeId)) {
        _arabicLocales.add(locale.localeId);
      }
    }

    if (_arabicLocales.isEmpty) _arabicLocales.add('ar-SA');
    _localeIndex = 0;
  }

  @override
  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) {
        final message = error.errorMsg;

        // Android can terminate a session without marking the latest partial
        // as final. Preserve it before any recovery path.
        _commitCurrentSegment();

        if (!_keepListening) {
          _emit(_state.copyWith(listening: false, error: message));
          return;
        }

        // Android can report BUSY when a replacement recognition session is
        // opened before the previous one has fully released the microphone.
        // This is recoverable and should be invisible to the user.
        if (message == 'error_busy') {
          _busyRetries++;
          _emit(_state.copyWith(
            listening: true,
            transcript: _combinedTranscript,
            clearError: true,
          ));
          _scheduleRestart(
            delay: Duration(milliseconds: 900 + (_busyRetries * 350)),
            releaseRecognizerFirst: true,
          );
          return;
        }

        if (message == 'error_no_match' || message == 'error_speech_timeout') {
          _emit(_state.copyWith(
            listening: true,
            transcript: _combinedTranscript,
            clearError: true,
          ));
          _scheduleRestart(
            delay: const Duration(milliseconds: 750),
            releaseRecognizerFirst: true,
          );
          return;
        }

        _emit(_state.copyWith(
          listening: true,
          transcript: _combinedTranscript,
          error: message,
        ));
        _scheduleRestart(
          delay: const Duration(milliseconds: 1100),
          releaseRecognizerFirst: true,
        );
      },
      onStatus: (status) {
        if (!_keepListening) return;
        if (status == 'done' || status == 'notListening') {
          _commitCurrentSegment();

          // Do not change the app UI to Ready here. The platform session ended,
          // but the Hifz recitation session is still active and will continue.
          _emit(_state.copyWith(
            listening: true,
            transcript: _combinedTranscript,
            clearError: true,
          ));
          _scheduleRestart(delay: const Duration(milliseconds: 800));
        }
      },
    );

    if (available) {
      final locales = await _speech.locales();
      _buildArabicLocaleList(locales);
    }

    _emit(_state.copyWith(available: available, clearError: true));
    return available;
  }

  void _scheduleRestart({
    Duration delay = const Duration(milliseconds: 800),
    bool releaseRecognizerFirst = false,
  }) {
    if (!_keepListening || _starting || _switchingLocale) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (!_keepListening) return;

      if (releaseRecognizerFirst) {
        try {
          await _speech.cancel().timeout(const Duration(milliseconds: 900));
        } catch (_) {}
        if (!_keepListening) return;
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      // A provider may still report itself as listening briefly after a status
      // callback. Give it time to relinquish the microphone rather than racing
      // it and producing error_busy.
      if (_speech.isListening) {
        _scheduleRestart(delay: const Duration(milliseconds: 650));
        return;
      }

      try {
        await _begin(onDevice: false);
      } catch (e) {
        if (!_keepListening) return;
        _scheduleRestart(
          delay: const Duration(milliseconds: 1200),
          releaseRecognizerFirst: true,
        );
      }
    });
  }

  Future<void> _tryNextArabicLocale() async {
    if (!_keepListening || _switchingLocale) return;

    // Only switch after sustained Latin-only output. If this phone exposes no
    // alternate Arabic locale, do not restart or stop the session: just keep
    // listening and wait for Arabic results to return.
    if (_localeIndex + 1 >= _arabicLocales.length) {
      _emit(_state.copyWith(
        listening: true,
        transcript: _combinedTranscript,
        error:
            'Having trouble hearing Arabic clearly. Still listening — keep reciting.',
      ));
      return;
    }

    _switchingLocale = true;
    _localeIndex++;
    _commitCurrentSegment();
    try {
      await _speech.cancel().timeout(const Duration(seconds: 1));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _switchingLocale = false;

    if (_keepListening) {
      await _begin(onDevice: false);
    }
  }

  Future<void> _begin({required bool onDevice}) async {
    if (_starting || !_keepListening) return;
    _starting = true;
    _currentSegment = '';

    try {
      await _speech.listen(
        onResult: (result) {
          final raw = result.recognizedWords.trim();
          if (raw.isEmpty) return;

          final isArabic = _containsArabicScript(raw);
          final looksLatinOnly = !isArabic && _containsLatinLetters(raw);

          if (looksLatinOnly) {
            if (result.finalResult) {
              _latinOnlyStreak++;
              if (_latinOnlyStreak >= 3) {
                _latinOnlyStreak = 0;
                unawaited(_tryNextArabicLocale());
              }
            }
            return;
          }

          if (!isArabic) return;

          _busyRetries = 0;
          _latinOnlyStreak = 0;

          // Never replace the whole live segment with a later partial. Some
          // Android providers send rolling chunks rather than cumulative text;
          // replacing here is what made previously revealed Qur'an words vanish.
          _currentSegment = _mergeText(_currentSegment, raw);

          if (result.finalResult) {
            _commitCurrentSegment();
          }

          _emit(_state.copyWith(
            listening: _keepListening,
            transcript: _combinedTranscript,
            confidence:
                result.hasConfidenceRating ? result.confidence : 0,
            clearError: true,
          ));
        },
        listenFor: const Duration(minutes: 5),
        // A longer pause window reduces premature session termination during
        // natural breathing or hesitation in memorized recitation.
        pauseFor: const Duration(seconds: 12),
        localeId: _activeLocale,
        partialResults: true,
        cancelOnError: false,
        onDevice: onDevice,
        listenMode: stt.ListenMode.dictation,
      );

      _emit(_state.copyWith(
        listening: true,
        transcript: _combinedTranscript,
        clearError: true,
      ));
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> start({bool preferOnDevice = false}) async {
    if (!_state.available) {
      final ok = await initialize();
      if (!ok) {
        _emit(_state.copyWith(
          listening: false,
          error: 'Speech recognition is unavailable on this device.',
        ));
        return;
      }
    }

    _restartTimer?.cancel();
    _committedTranscript = '';
    _currentSegment = '';
    _localeIndex = 0;
    _busyRetries = 0;
    _latinOnlyStreak = 0;
    _keepListening = true;
    _emit(_state.copyWith(
      listening: true,
      transcript: '',
      confidence: 0,
      clearError: true,
    ));

    if (preferOnDevice) {
      try {
        await _begin(onDevice: true);
        return;
      } catch (_) {}
    }

    await _begin(onDevice: false);
  }

  @override
  Future<void> stop() async {
    _keepListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _commitCurrentSegment();
    _emit(_state.copyWith(
      listening: false,
      transcript: _combinedTranscript,
      clearError: true,
    ));
  }

  @override
  Future<void> cancel() async {
    _keepListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _committedTranscript = '';
    _currentSegment = '';
    _emit(_state.copyWith(
      listening: false,
      transcript: '',
      clearError: true,
    ));
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _controller.close();
  }
}
