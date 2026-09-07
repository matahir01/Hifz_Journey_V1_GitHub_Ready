# Hifz Journey V3 — Memorization Coach

Version 3 focuses on the feature that differentiates Hifz Journey from a normal Qur'an reader: **hide → recite → detect → grade → revise**.

## Implemented in 3.0.0 Alpha 3

- Microphone-based Arabic recitation test with the ayah hidden by default.
- Qur'an-specialized Tarteel Whisper recognizer running through `whisper.cpp`/GGML on-device.
- One-time ~77 MB model download into private app storage; model is not bundled in the APK.
- Live partial transcript while the learner recites.
- Qur'an-text normalization that ignores harakat and common orthographic differences before comparison.
- Word-sequence alignment with correct, changed and missed-word feedback.
- Automatic 0–100 memorization score and Strong / Partial / Needs revision classification.
- Recitation results feed the existing spaced-retention engine.
- Dedicated `recitation_attempts` SQLite history table.
- V3 backup/restore includes recitation attempts while remaining compatible with older backups.
- Provider-neutral recognition boundary remains available for future model replacement.
- Existing V2 systems remain: Al Quran Cloud audio streaming/download, repetition controls, ayah synchronization, weak ayahs, calendar/history, backup/restore, and Mushaf text-page mode.

## Model behavior

The model is downloaded only when the user enables the Recitation Coach. Once downloaded, inference stays on the device. The expected ayah is **not** injected as Whisper's initial prompt during a test, avoiding answer leakage/bias in the transcription.

## V3 next implementation targets

1. Advanced test modes: selected range, weak-only, random ayah, continue-next-ayah and start-from-middle.
2. Rich recitation analytics by Surah/Juz and recurring mistake patterns.
3. Improve live feedback stability and confidence handling on low-end Android devices.
4. Mushaf visual-layout upgrade. Current Mushaf mode preserves Qur'an page grouping but is rendered as text; a scan/image-like Madani layout requires a separately licensed page/position asset set.
5. Production release signing and Android toolchain modernization.

## Accuracy boundary

V3 Alpha assesses **memorization/text accuracy**. It does not claim to judge tajwid, makhraj, madd length, or teacher-level pronunciation correctness. Recognition quality depends on microphone quality, noise, device performance, and recitation style.
