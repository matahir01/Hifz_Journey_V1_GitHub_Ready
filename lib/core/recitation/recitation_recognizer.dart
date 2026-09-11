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
/// Android speech providers can end an individual recognition session after a
/// pause or an internal time limit. Hifz Journey therefore treats those endings
/// as short segments and keeps one accumulated transcript until the user
/// explicitly finishes or resets the test.
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
  bool _allowTranscriptReset = false;
  final List<String> _segments = <String>[];
  String _currentSegment = '';
  Timer? _restartTimer;
  int _busyRetries = 0;

  @override
  Stream<RecitationRecognitionState> get states => _controller.stream;

  @override
  RecitationRecognitionState get state => _state;

  static List<String> _words(String text) => text
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  static String _mergeStableText(String previous, String current) {
    final oldWords = _words(previous);
    final newWords = _words(current);

    if (oldWords.isEmpty) return newWords.join(' ');
    if (newWords.isEmpty) return oldWords.join(' ');

    // If the speech service is returning a revised cumulative hypothesis for
    // the same utterance, never allow a shorter result to erase words that have
    // already been captured. When it grows, accept the newer hypothesis.
    final minLength = oldWords.length < newWords.length
        ? oldWords.length
        : newWords.length;
    var commonPrefix = 0;
    while (commonPrefix < minLength &&
        oldWords[commonPrefix] == newWords[commonPrefix]) {
      commonPrefix++;
    }

    final prefixThreshold = minLength <= 2 ? minLength : 3;
    if (commonPrefix >= prefixThreshold) {
      if (newWords.length < oldWords.length) return oldWords.join(' ');
      return newWords.join(' ');
    }

    // If Android briefly sends only a suffix/subset already present in the
    // accumulated transcript, retain the accumulated transcript unchanged.
    if (newWords.length <= oldWords.length) {
      for (var start = 0;
          start <= oldWords.length - newWords.length;
          start++) {
        var same = true;
        for (var i = 0; i < newWords.length; i++) {
          if (oldWords[start + i] != newWords[i]) {
            same = false;
            break;
          }
        }
        if (same) return oldWords.join(' ');
      }
    }

    // Otherwise this is most likely a fresh segment after Android restarted
    // recognition. Append it while removing any suffix/prefix overlap.
    final maxOverlap =
        oldWords.length < newWords.length ? oldWords.length : newWords.length;
    var overlap = 0;
    for (var count = maxOverlap; count > 0; count--) {
      var same = true;
      for (var i = 0; i < count; i++) {
        if (oldWords[oldWords.length - count + i] != newWords[i]) {
          same = false;
          break;
        }
      }
      if (same) {
        overlap = count;
        break;
      }
    }

    return <String>[
      ...oldWords,
      ...newWords.skip(overlap),
    ].join(' ');
  }

  void _emit(RecitationRecognitionState value) {
    var next = value;

    // During one active test the transcript is monotonic. Platform callbacks
    // are allowed to revise or shorten their own partial hypothesis, but they
    // are never allowed to remove text that Hifz Journey already displayed.
    if (!_allowTranscriptReset && _keepListening) {
      final previous = _state.transcript.trim();
      final incoming = value.transcript.trim();
      if (previous.isNotEmpty) {
        next = value.copyWith(
          transcript: _mergeStableText(previous, incoming),
        );
      }
    }

    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  String get _activeLocale =>
      _arabicLocales.isEmpty ? 'ar-SA' : _arabicLocales[_localeIndex];

  static String _mergeText(String previous, String current) =>
      _mergeStableText(previous, current);

  String get _committedTranscript => _segments.join(' ').trim();

  String get _combinedTranscript =>
      _mergeText(_committedTranscript, _currentSegment.trim());

  void _commitCurrentSegment() {
    final current = _currentSegment.trim();
    if (current.isEmpty) return;

    final merged = _mergeText(_committedTranscript, current);
    _segments
      ..clear()
      ..add(merged);
    _currentSegment = '';
  }

  static bool _containsArabicScript(String text) {
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text);
  }

  static bool _containsLatinLetters(String text) {
    return RegExp(r'[A-Za-z]').hasMatch(text);
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

        if (!_keepListening) {
          _emit(_state.copyWith(listening: false, error: message));
          return;
        }

        _commitCurrentSegment();

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
            delay: const Duration(milliseconds: 650),
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
          delay: const Duration(milliseconds: 1000),
          releaseRecognizerFirst: true,
        );
      },
      onStatus: (status) {
        if (!_keepListening) return;
        if (status == 'done' || status == 'notListening') {
          _commitCurrentSegment();
          _emit(_state.copyWith(
            listening: true,
            transcript: _combinedTranscript,
            clearError: true,
          ));
          _scheduleRestart(delay: const Duration(milliseconds: 650));
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
    Duration delay = const Duration(milliseconds: 650),
    bool releaseRecognizerFirst = false,
  }) {
    if (!_keepListening || _starting || _switchingLocale) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (!_keepListening) return;

      if (releaseRecognizerFirst) {
        _commitCurrentSegment();
        try {
          await _speech.cancel().timeout(const Duration(milliseconds: 900));
        } catch (_) {}
        if (!_keepListening) return;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      if (_speech.isListening) {
        _scheduleRestart(delay: const Duration(milliseconds: 550));
        return;
      }

      try {
        await _begin(onDevice: false);
      } catch (_) {
        if (!_keepListening) return;
        _scheduleRestart(
          delay: const Duration(milliseconds: 1000),
          releaseRecognizerFirst: true,
        );
      }
    });
  }

  Future<void> _tryNextArabicLocale() async {
    if (!_keepListening || _switchingLocale) return;
    if (_localeIndex + 1 >= _arabicLocales.length) {
      _commitCurrentSegment();
      _emit(_state.copyWith(
        listening: false,
        transcript: _combinedTranscript,
        error:
            'The phone speech service returned Latin transliteration instead of Arabic text. Arabic recognition is enabled, but this speech provider is not returning Arabic script to Hifz Journey.',
      ));
      _keepListening = false;
      return;
    }

    _commitCurrentSegment();
    _switchingLocale = true;
    _localeIndex++;
    try {
      await _speech.cancel().timeout(const Duration(seconds: 1));
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _switchingLocale = false;

    if (_keepListening) {
      await _begin(onDevice: false);
    }
  }

  Future<void> _begin({required bool onDevice}) async {
    if (_starting || !_keepListening) return;
    _starting = true;

    _commitCurrentSegment();

    try {
      await _speech.listen(
        onResult: (result) {
          final raw = result.recognizedWords.trim();
          if (raw.isEmpty) return;

          final isArabic = _containsArabicScript(raw);
          final looksLatinOnly = !isArabic && _containsLatinLetters(raw);

          if (looksLatinOnly) {
            if (result.finalResult) unawaited(_tryNextArabicLocale());
            return;
          }

          if (!isArabic) return;

          _busyRetries = 0;
          _currentSegment = raw;

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
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 30),
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
    _segments.clear();
    _currentSegment = '';
    _localeIndex = 0;
    _busyRetries = 0;
    _allowTranscriptReset = true;
    _keepListening = true;
    _emit(_state.copyWith(
      listening: true,
      transcript: '',
      confidence: 0,
      clearError: true,
    ));
    _allowTranscriptReset = false;

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

    _commitCurrentSegment();
    try {
      await _speech.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _commitCurrentSegment();

    _emit(_state.copyWith(
      listening: false,
      transcript: _mergeStableText(_state.transcript, _combinedTranscript),
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
    _segments.clear();
    _currentSegment = '';
    _allowTranscriptReset = true;
    _emit(_state.copyWith(
      listening: false,
      transcript: '',
      clearError: true,
    ));
    _allowTranscriptReset = false;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _controller.close();
  }
}
