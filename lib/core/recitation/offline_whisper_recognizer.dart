import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'tarteel_model_manager.dart';

class RecitationRecognizerState {
  final String transcript;
  final bool listening;

  const RecitationRecognizerState({
    required this.transcript,
    required this.listening,
  });
}

/// On-device Qur'an recitation recognizer backed by the Tarteel-tuned Whisper
/// Base model converted to GGML q8_0 for whisper.cpp.
class OfflineWhisperRecitationRecognizer {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperController _whisper = WhisperController();
  final TarteelModelManager modelManager;
  final StreamController<RecitationRecognizerState> _states =
      StreamController<RecitationRecognizerState>.broadcast();

  WhisperLiveSession? _session;
  StreamSubscription<String>? _partialSubscription;
  bool _listening = false;
  String _latest = '';

  OfflineWhisperRecitationRecognizer({TarteelModelManager? modelManager})
      : modelManager = modelManager ?? TarteelModelManager();

  Stream<RecitationRecognizerState> get states => _states.stream;
  bool get isListening => _listening;
  String get latestTranscript => _latest;

  Future<void> start({String? initialPrompt}) async {
    if (_listening) return;
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }

    final modelPath = await modelManager.ensureInstalled();
    final Stream<Uint8List> pcm = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _latest = '';
    try {
      _session = await _whisper.transcribeLive(
        modelPath: modelPath,
        pcm16Stream: pcm,
        lang: 'ar',
        initialPrompt: initialPrompt,
        suppressNonSpeechTokens: true,
        keepModelLoaded: true,
        gateRmsMin: 0.0010,
        gateVoiceRatio: 1.8,
        gateNoiseFloorCap: 0.008,
      );
    } catch (_) {
      await _recorder.cancel();
      rethrow;
    }

    _partialSubscription = _session!.partials.listen((text) {
      final next = text.trim();
      if (next == _latest) return;
      _latest = next;
      _states.add(
        RecitationRecognizerState(transcript: _latest, listening: true),
      );
    });
    _listening = true;
    _states.add(
      const RecitationRecognizerState(transcript: '', listening: true),
    );
  }

  Future<String> stop() async {
    if (!_listening) return _latest;
    await _recorder.stop();
    final value = await _session!.stop();
    final finalText = value.trim();
    if (finalText.isNotEmpty) _latest = finalText;
    await _partialSubscription?.cancel();
    _partialSubscription = null;
    _session = null;
    _listening = false;
    _states.add(
      RecitationRecognizerState(transcript: _latest, listening: false),
    );
    return _latest;
  }

  Future<void> cancel() async {
    if (_listening) {
      await _recorder.cancel();
      try {
        await _session?.stop();
      } catch (_) {}
    }
    await _partialSubscription?.cancel();
    _partialSubscription = null;
    _session = null;
    _listening = false;
    _latest = '';
    _states.add(
      const RecitationRecognizerState(transcript: '', listening: false),
    );
  }

  Future<void> dispose() async {
    await cancel();
    await _whisper.releaseModel();
    await _recorder.dispose();
    await modelManager.dispose();
    await _states.close();
  }
}
