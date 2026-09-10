import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TarteelModelStatus {
  final bool installed;
  final bool downloading;
  final int receivedBytes;
  final int? totalBytes;
  final String? error;

  const TarteelModelStatus({
    required this.installed,
    this.downloading = false,
    this.receivedBytes = 0,
    this.totalBytes,
    this.error,
  });

  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0, 1);
  }
}

/// Manages the Qur'an-specialized Whisper Tiny Q8 model used by Hifz Journey.
///
/// Tiny is deliberately preferred over Base for live mobile recitation: it is
/// substantially smaller and faster on Android CPUs while remaining tuned for
/// Qur'anic Arabic. The model is downloaded once and stored privately.
class TarteelModelManager {
  static const modelFileName =
      'tarteel-ai-whisper-tiny-ar-quran-ggml-q8_0.bin';
  static const modelDownloadUrl =
      'https://huggingface.co/MI9153/rafiq-quran-ai/resolve/main/tarteel-ai-whisper-tiny-ar-quran-ggml-q8_0.bin?download=true';

  static const minimumValidBytes = 35 * 1024 * 1024;
  static const maximumExpectedBytes = 55 * 1024 * 1024;

  final StreamController<TarteelModelStatus> _states =
      StreamController<TarteelModelStatus>.broadcast();

  HttpClient? _activeClient;
  bool _downloading = false;

  Stream<TarteelModelStatus> get states => _states.stream;
  bool get isDownloading => _downloading;

  Future<Directory> _modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory =
        Directory('${support.path}${Platform.pathSeparator}models');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String> modelPath() async {
    final directory = await _modelDirectory();
    return '${directory.path}${Platform.pathSeparator}$modelFileName';
  }

  Future<bool> isInstalled() async {
    final file = File(await modelPath());
    if (!await file.exists()) return false;
    final size = await file.length();
    return size >= minimumValidBytes && size <= maximumExpectedBytes;
  }

  Future<TarteelModelStatus> status() async {
    final installed = await isInstalled();
    final file = File(await modelPath());
    final size = await file.exists() ? await file.length() : 0;
    return TarteelModelStatus(
      installed: installed,
      downloading: _downloading,
      receivedBytes: size,
    );
  }

  Future<String> ensureInstalled() async {
    if (!await isInstalled()) {
      throw StateError(
        'Qur’an recitation model is not installed. Download it first.',
      );
    }
    return modelPath();
  }

  Future<String> download() async {
    if (_downloading) {
      throw StateError('The Qur’an recitation model is already downloading.');
    }
    _downloading = true;
    final destination = File(await modelPath());
    final partial = File('${destination.path}.part');
    final client = HttpClient()..userAgent = 'HifzJourney/3';
    _activeClient = client;

    try {
      if (await partial.exists()) await partial.delete();
      _states.add(
        const TarteelModelStatus(installed: false, downloading: true),
      );

      final request = await client.getUrl(Uri.parse(modelDownloadUrl));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/octet-stream',
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Model download failed with HTTP ${response.statusCode}.',
          uri: Uri.parse(modelDownloadUrl),
        );
      }

      final total = response.contentLength > 0 ? response.contentLength : null;
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          _states.add(
            TarteelModelStatus(
              installed: false,
              downloading: true,
              receivedBytes: received,
              totalBytes: total,
            ),
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final size = await partial.length();
      if (size < minimumValidBytes || size > maximumExpectedBytes) {
        throw StateError(
          'Downloaded model has an unexpected size (${_formatBytes(size)}). '
          'Please try again on a stable connection.',
        );
      }

      if (await destination.exists()) await destination.delete();
      await partial.rename(destination.path);
      await _removeLegacyBaseModel();
      _states.add(
        TarteelModelStatus(
          installed: true,
          receivedBytes: size,
          totalBytes: size,
        ),
      );
      return destination.path;
    } catch (e) {
      if (await partial.exists()) await partial.delete();
      _states.add(
        TarteelModelStatus(installed: false, error: e.toString()),
      );
      rethrow;
    } finally {
      _downloading = false;
      client.close(force: true);
      _activeClient = null;
    }
  }

  Future<void> _removeLegacyBaseModel() async {
    final directory = await _modelDirectory();
    const oldNames = [
      'tarteel-whisper-base-ar-quran-q8_0.bin',
      'tarteel-ai-whisper-base-ar-quran-ggml-q8_0.bin',
    ];
    for (final name in oldNames) {
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> delete() async {
    cancelDownload();
    final destination = File(await modelPath());
    final partial = File('${destination.path}.part');
    if (await destination.exists()) await destination.delete();
    if (await partial.exists()) await partial.delete();
    _states.add(const TarteelModelStatus(installed: false));
  }

  void cancelDownload() {
    _activeClient?.close(force: true);
  }

  Future<void> dispose() async {
    cancelDownload();
    await _states.close();
  }

  static String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
}
