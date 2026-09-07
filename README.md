# Hifz Journey V2.1.1

Hifz Journey is an offline-first Flutter Qur’an reading, memorization, revision and retention companion.

## Al Quran Cloud audio

V2.1.1 uses **Al Quran Cloud / Islamic Network CDN as the single online audio provider**.

- Stream recitation verse-by-verse without intentionally saving a permanent copy.
- Download a Surah for offline playback inside the app’s private storage.
- Automatically prefer a downloaded ayah when it is available.
- Ayah-synchronized playback: the active verse is highlighted and Reader mode advances with the recitation.
- Repetition controls: ×1, ×3, ×5, ×10.
- Playback speed: 0.75×, 1.0×, 1.25×.
- Selectable reciters backed by documented Al Quran Cloud audio edition identifiers.
- Optional local audio-pack import remains as a fallback for files the user already has permission to use.
- No Quran Foundation credentials, OAuth client secret, or Hifz Journey backend is required for this audio path.

The CDN pattern used by the provider is:

`https://cdn.islamic.network/quran/audio/{bitrate}/{edition}/{globalAyahNumber}.mp3`

Hifz Journey’s bundled Qur’an database uses global ayah IDs 1–6236, so the same ID can be used directly for Al Quran Cloud’s ayah audio numbering.

No Qur’an MP3 files are bundled in this repository. Before public/commercial distribution, verify the provider’s current usage and redistribution terms for offline downloads.

## Qur’an text

Arabic Qur’an text is sourced from the Tanzil Project and must remain verbatim. Preserve the required Tanzil attribution and link in distributed versions.

## Other V2 systems

- First-run Hifz plan and configurable starting point.
- Adaptive revision and weak-ayah detection.
- Three-level recall grading: Forgot / Partial / Remembered.
- Enhanced Hifz session.
- Mushaf/page mode.
- History, calendar and retention analytics.
- Local backup and restore. Audio downloads themselves are intentionally excluded from backups and can be downloaded again.
- Local reminders.

## Build

GitHub Actions is configured to run tests/analyze and build a release APK. The Android project includes Internet permission for streaming/downloads and the desugaring setup required by local notifications.
