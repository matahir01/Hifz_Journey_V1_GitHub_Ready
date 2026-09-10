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

/// Fast recognizer using Android/iOS speech recognition.
///
/// Hifz Journey deliberately requests the normal network-backed recognizer by
/// default. This matches the path that usually powers fast Arabic voice typing
/// on Android. Long recitations are handled by automatically reopening the
/// recognizer when the speech service ends a segment.
class DeviceArabicRecitationRecognizer implements RecitationRecognizer {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _controller =
      StreamController<RecitationRecognitionState>.broadcast();

  RecitationRecognitionState _state =
      RecitationRecognitionState.initial();
  String? _arabicLocale;
  bool _keepListening = false;
  bool _starting = false;
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

  String get _combinedTranscript {
    final values = <String>[..._segments];
    final current = _currentSegment.trim();
    if (current.isNotEmpty) values.add(current);
    return values.join(' ').trim();
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
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id == 'ar_sa' || id == 'ar-sa') {
          _arabicLocale = locale.localeId;
          break;
        }
        if (_arabicLocale == null && id.startsWith('ar')) {
          _arabicLocale = locale.localeId;
        }
      }
    }

    _emit(_state.copyWith(available: available, clearError: true));
    return available;
  }

  void _scheduleRestart() {
    if (!_keepListening || _starting) return;
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

  Future<void> _begin({required bool onDevice}) async {
    if (_starting || !_keepListening) return;
    _starting = true;
    _currentSegment = '';
    try {
      await _speech.listen(
        onResult: (result) {
          _currentSegment = result.recognizedWords.trim();

          if (result.finalResult && _currentSegment.isNotEmpty) {
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
        localeId: _arabicLocale,
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
    _keepListening = true;
    _emit(_state.copyWith(
      listening: true,
      transcript: '',
      confidence: 0,
      clearError: true,
    ));

    // Network-backed recognition is intentional. If the caller explicitly
    // asks for on-device recognition, try it once and fall back to network.
    if (preferOnDevice) {
      try {
        await _begin(onDevice: true);
        return;
      } catch (_) {
        // Continue to the normal online recognizer below.
      }
    }
    await _begin(onDevice: false);
  }

  @override
  Future<void> stop() async {
    _keepListening = false;
    _restartTimer?.cancel();
    try {
      await _speech.stop().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Preserve the partial transcript instead of making Stop feel stuck.
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
