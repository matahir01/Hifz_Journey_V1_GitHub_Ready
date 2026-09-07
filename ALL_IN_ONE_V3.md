# Hifz Journey V3 — consolidated offline release

This source package consolidates the requested V3 work without Firebase authentication.

## Qur’an & Mushaf
- 114 Surahs / 6,236 ayahs from the bundled Tanzil-derived database.
- Surah, Juz and 604-page navigation.
- Redesigned Mushaf reading surface with paper-like light/dark presentation, ornamental Surah headers, Bismillah treatment, ayah ornaments, Arabic page numbers, focus mode, page slider, page jump, swipe navigation and adjustable text size.
- Tap an ayah in Mushaf mode to open Ayah View, run an AI recitation test or bookmark it.
- Redesigned Ayah View with large Arabic reading surface, hide/reveal memorization mode, text sizing, Mushaf shortcut, bookmarking, offline audio download and direct AI test.

## Memorization & retention
- Daily new-ayah target and Today’s Hifz session.
- Forgot / Partial / Remembered grading.
- Spaced revision scheduling and strength tracking.
- Weak-ayah detection and direct retesting.
- Streak, progress, history and calendar analytics.
- Memorization Test Centre: random ayah, continue-the-recitation, start-from-the-middle, weak-only, revision-due and specific reference tests.

## AI recitation coach
- Qur’an-specialized Tarteel Whisper GGML model.
- One-time model download, then on-device recognition.
- Live partial Arabic transcription.
- Word-level expected/heard comparison, omissions/substitutions and score.
- Results feed the retention engine.
- Assessment is for memorized text accuracy, not authoritative tajwid/makhraj judgement.

## Audio
- Al Quran Cloud / Islamic Network verse audio.
- Reciter selection.
- Streaming plus optional offline downloads.
- Repeat 1× / 3× / 5× / 10× and speed control.
- Sequence playback waits for the active ayah to complete before advancing.

## Local-first tools
- Bookmarks and reading position.
- Search by Arabic text or reference.
- Backup / restore of Hifz data, history, settings and bookmarks.
- Local reminders.
- Light / dark / system appearance.
- No Firebase authentication or account requirement.

## Android / CI
- NDK 29.0.13113456 pinned for whisper_ggml.
- GitHub Actions installs the required NDK and accepts SDK licences.
- Core-library desugaring retained for notifications.
