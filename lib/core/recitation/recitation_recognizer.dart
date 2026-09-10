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
/// Hifz Journey deliberately uses the normal network-backed speech service by
/// default. The recognizer also verifies that returned text is actually Arabic
/// script. Some Android speech providers silently fall back to English and
/// return transliteration such as "alhamdulillah"; those results are rejected
/// and another Arabic locale is tried automatically.
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
  final List<String> _segments = <String>[];
  String _currentSegment = '';
  Timer? _restartTimer;

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

  String get _combinedTranscript {
    final values = <String>[..._segments];
    final current = _currentSegment.trim();
    if (current.isNotEmpty) values.add(current);
    return values.join(' ').trim();
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

    // Saudi Arabic first because it matches the user's Google voice setting
    // and is the most natural default for Qur'an recitation.
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

    // Some Android recognizers accept ar-SA even when locales() does not list
    // it. Keeping this explicit fallback prevents accidental English default.
    if (_arabicLocales.isEmpty) _arabicLocales.add('ar-SA');
    _localeIndex = 0;
  }

  @override
  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) {
        final message = error.errorMsg;
        if (message == 'error_no_match' && _keepListening) {
          _scheduleRestart();
          return;
        }
        _emit(_state.copyWith(
          listening: false,
          error: message,
        ));
        if (_keepListening) _scheduleRestart();
      },
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _keepListening) {
          _scheduleRestart();
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

  void _scheduleRestart() {
    if (!_keepListening || _starting || _switchingLocale) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!_keepListening) return;
      try {
        await _begin(onDevice: false);
      } catch (e) {
        _emit(_state.copyWith(
          listening: false,
          error: e.toString(),
        ));
      }
    });
  }

  Future<void> _tryNextArabicLocale() async {
    if (!_keepListening || _switchingLocale) return;
    if (_localeIndex + 1 >= _arabicLocales.length) {
      _emit(_state.copyWith(
        listening: false,
        error:
            'The phone speech service returned Latin transliteration instead of Arabic text. Arabic recognition is enabled, but this speech provider is not returning Arabic script to Hifz Journey.',
      ));
      _keepListening = false;
      return;
    }

    _switchingLocale = true;
    _localeIndex++;
    _currentSegment = '';
    try {
      await _speech.cancel().timeout(const Duration(seconds: 1));
    } catch (_) {}
    _switchingLocale = false;

    if (_keepListening) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
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
            // Do not display or grade transliteration as if it were Qur'an
            // Arabic. Wait for a final result before changing locale so that a
            // temporary partial hypothesis does not interrupt the user.
            if (result.finalResult) {
              unawaited(_tryNextArabicLocale());
            }
            return;
          }

          if (!isArabic) return;

          _currentSegment = raw;

          if (result.finalResult) {
            final last = _segments.isEmpty ? null : _segments.last;
            if (last != _currentSegment) _segments.add(_currentSegment);
            _currentSegment = '';
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
        pauseFor: const Duration(seconds: 4),
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
      } catch (_) {
        // Continue to the normal internet-backed recognizer below.
      }
    }

    // Network recognition is intentional for speed and quality.
    await _begin(onDevice: false);
  }

  @override
  Future<void> stop() async {
    _keepListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.stop().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Preserve the latest Arabic partial result rather than making Stop hang.
    }
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
    _segments.clear();
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
