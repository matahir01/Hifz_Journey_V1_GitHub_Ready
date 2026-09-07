# Changelog

## 3.0.0-alpha.3+10

- Replaced the generic Whisper Base download with the Qur'an-specialized Tarteel Whisper GGML q8_0 model.
- Added one-time ~77 MB model download manager with progress, private storage, validation, retry/error state, and model removal.
- Live recitation now uses `WhisperController.transcribeLive(modelPath: ...)` with the downloaded custom GGML model.
- Recognition remains fully on-device after the model download; no Hifz Journey speech server/API key is required.
- Removed expected-ayah prompt injection from testing to avoid biasing Whisper toward the answer.
- Updated Recitation Coach UI and documentation for the Tarteel model.
- Kept the V2.1.2 audio synchronization and responsive Settings fixes.

## 3.0.0-alpha.4+11
- GitHub Actions now accepts Android SDK licenses and installs NDK 29.0.13113456 required by whisper_ggml.
- Android app pins the same NDK version so app/plugin native builds use a consistent toolchain.
