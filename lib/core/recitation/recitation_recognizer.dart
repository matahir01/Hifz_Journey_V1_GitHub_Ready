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

  factory RecitationRecognitionState.initial() => const RecitationRecognitionState(
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
  Future<void> start({bool preferOnDevice = true});
  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

/// Free baseline recognizer using Android/iOS speech recognition.
///
/// On-device recognition is requested when the platform supports it. Some
/// devices may fall back to their speech service. The rest of Hifz Journey is
/// deliberately isolated behind [RecitationRecognizer] so a Quran-specialized
/// Whisper/Tarteel model can replace this adapter without changing the test UI
/// or retention engine.
class DeviceArabicRecitationRecognizer implements RecitationRecognizer {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _controller = StreamController<RecitationRecognitionState>.broadcast();
  RecitationRecognitionState _state = RecitationRecognitionState.initial();
  String? _arabicLocale;

  @override
  Stream<RecitationRecognitionState> get states => _controller.stream;

  @override
  RecitationRecognitionState get state => _state;

  void _emit(RecitationRecognitionState value) {
    _state = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  @override
  Future<bool> initialize() async {
    final available = await _speech.initialize(
      onError: (error) {
        _emit(_state.copyWith(
          listening: false,
          error: error.errorMsg,
        ));
      },
      onStatus: (status) {
        final listening = status == 'listening';
        if (_state.listening != listening) {
          _emit(_state.copyWith(listening: listening));
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

  @override
  Future<void> start({bool preferOnDevice = true}) async {
    if (!_state.available) {
      final ok = await initialize();
      if (!ok) return;
    }
    _emit(_state.copyWith(
      listening: true,
      transcript: '',
      confidence: 0,
      clearError: true,
    ));
    Future<void> begin(bool onDevice) async {
      await _speech.listen(
        onResult: (result) {
          _emit(_state.copyWith(
            listening: !result.finalResult,
            transcript: result.recognizedWords,
            confidence: result.hasConfidenceRating ? result.confidence : 0,
            clearError: true,
          ));
        },
        listenFor: const Duration(seconds: 90),
        pauseFor: const Duration(seconds: 5),
        localeId: _arabicLocale,
        partialResults: true,
        cancelOnError: false,
        onDevice: onDevice,
        listenMode: stt.ListenMode.dictation,
      );
    }

    try {
      await begin(preferOnDevice);
    } catch (error) {
      if (!preferOnDevice) rethrow;
      // Some Android speech services support Arabic but do not expose an
      // offline model. Fall back to the device's normal recognizer instead of
      // failing the Hifz session completely.
      try {
        await begin(false);
      } catch (fallbackError) {
        _emit(_state.copyWith(
          listening: false,
          error: '$fallbackError',
        ));
      }
    }
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    _emit(_state.copyWith(listening: false));
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _emit(_state.copyWith(listening: false, transcript: ''));
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _controller.close();
  }
}
