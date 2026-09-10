import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'recitation_recognizer.dart';
import 'tarteel_model_manager.dart';

class RecitationRecognizerState {
  final String transcript;
  final bool listening;

  const RecitationRecognizerState({
    required this.transcript,
    required this.listening,
  });
}

/// Hybrid Qur'an recitation recognizer.
///
/// The fast path uses Android/iOS system speech recognition with online Arabic
/// recognition enabled. This gives immediate partial results on phones whose
/// Google speech service supports Arabic. If the system recognizer is
/// unavailable or reports a language/service error, the app transparently
/// falls back to the downloaded Qur'an-tuned Whisper model.
///
/// Whisper remains the privacy/offline fallback; the expected ayah text is not
/// supplied to either recognizer as a prompt so recall scores are not inflated.
class OfflineWhisperRecitationRecognizer {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperController _whisper = WhisperController();
  final DeviceArabicRecitationRecognizer _device =
      DeviceArabicRecitationRecognizer();
  final TarteelModelManager modelManager;
  final StreamController<RecitationRecognizerState> _states =
      StreamController<RecitationRecognizerState>.broadcast();

  WhisperLiveSession? _session;
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<RecitationRecognitionState>? _deviceSubscription;

  bool _listening = false;
  bool _usingDevice = false;
  bool _switchingRecognizer = false;
  bool _stopping = false;
  String _latest = '';

  OfflineWhisperRecitationRecognizer({TarteelModelManager? modelManager})
      : modelManager = modelManager ?? TarteelModelManager();

  Stream<RecitationRecognizerState> get states => _states.stream;
  bool get isListening => _listening;
  String get latestTranscript => _latest;

  void _emit() {
    if (_states.isClosed) return;
    _states.add(
      RecitationRecognizerState(
        transcript: _latest,
        listening: _listening,
      ),
    );
  }

  Future<void> start({String? initialPrompt}) async {
    if (_listening || _switchingRecognizer) return;

    _latest = '';
    _stopping = false;

    // Prefer Google's normal/network Arabic recognizer. The previous build
    // requested on-device Arabic first; on some Android phones that produces
    // error_language_unavailable even though Arabic voice typing works in
    // Gboard. Using onDevice:false intentionally avoids that mismatch.
    try {
      final available = await _device.initialize();
      if (available) {
        await _deviceSubscription?.cancel();
        _deviceSubscription = _device.states.listen(_onDeviceState);
        _usingDevice = true;
        _listening = true;
        _emit();
        await _device.start(preferOnDevice: false);
        return;
      }
    } catch (_) {
      // Fall through to the Qur'an Whisper recognizer below.
    }

    await _startWhisper(initialPrompt: initialPrompt);
  }

  void _onDeviceState(RecitationRecognitionState state) {
    if (_stopping || !_usingDevice) return;

    final next = state.transcript.trim();
    if (next.isNotEmpty && next != _latest) {
      _latest = next;
    }

    final message = state.error?.toLowerCase() ?? '';
    if (message.isNotEmpty) {
      final shouldFallback =
          message.contains('language_unavailable') ||
          message.contains('language_not_supported') ||
          message.contains('error_client') ||
          message.contains('error_network') ||
          message.contains('error_server');
      if (shouldFallback) {
        unawaited(_switchToWhisper());
        return;
      }
    }

    _listening = state.listening;
    _emit();
  }

  Future<void> _switchToWhisper() async {
    if (_switchingRecognizer || _stopping || !_usingDevice) return;
    _switchingRecognizer = true;
    try {
      await _device.cancel();
      _usingDevice = false;
      _listening = false;
      _emit();
      await _startWhisper();
    } finally {
      _switchingRecognizer = false;
    }
  }

  Future<void> _startWhisper({String? initialPrompt}) async {
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

    await _partialSubscription?.cancel();
    _partialSubscription = _session!.partials.listen((text) {
      final next = text.trim();
      if (next == _latest || next.isEmpty) return;
      _latest = next;
      _emit();
    });

    _usingDevice = false;
    _listening = true;
    _emit();
  }

  Future<String> stop() async {
    if (!_listening && !_usingDevice) return _latest;
    _stopping = true;

    try {
      if (_usingDevice) {
        await _device.stop();
        _usingDevice = false;
        final finalText = _device.state.transcript.trim();
        if (finalText.isNotEmpty) _latest = finalText;
        _listening = false;
        _emit();
        return _latest;
      }

      await _recorder.stop();
      final session = _session;
      if (session != null) {
        final value = await session.stop();
        final finalText = value.trim();
        if (finalText.isNotEmpty) _latest = finalText;
      }
      await _partialSubscription?.cancel();
      _partialSubscription = null;
      _session = null;
      _listening = false;
      _emit();
      return _latest;
    } finally {
      _stopping = false;
    }
  }

  Future<void> cancel() async {
    _stopping = true;
    try {
      if (_usingDevice) {
        await _device.cancel();
      }
      _usingDevice = false;

      if (_session != null || _listening) {
        try {
          await _recorder.cancel();
        } catch (_) {}
        try {
          await _session?.stop();
        } catch (_) {}
      }

      await _partialSubscription?.cancel();
      _partialSubscription = null;
      _session = null;
      _listening = false;
      _latest = '';
      _emit();
    } finally {
      _stopping = false;
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _deviceSubscription?.cancel();
    await _device.dispose();
    await _whisper.releaseModel();
    await _recorder.dispose();
    await modelManager.dispose();
    await _states.close();
  }
}
