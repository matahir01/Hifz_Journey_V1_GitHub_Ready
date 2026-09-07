# Hifz Journey V3

**Read. Memorize. Revise. Retain.**

Offline-first Flutter Qur'an memorization companion with Qur'an reading, Hifz planning, spaced revision, Al Quran Cloud ayah audio, streaming/offline downloads, repetition controls, weak-ayah tracking, history/calendar analytics, backup/restore, Mushaf page grouping, and the V3 Recitation Coach.

## V3 Recitation Coach — Tarteel Whisper

Open **Home → Recitation coach**. Hifz Journey hides the ayah, listens to the learner's recitation, shows a live Arabic transcript, aligns it against the expected Qur'an text, marks likely correct/changed/missed words, calculates a memorization score, and feeds that result into the retention schedule.

V3.0 Alpha 3 uses the Qur'an-specialized **Tarteel Whisper Base Arabic Qur'an** model through a GGML q8_0 conversion compatible with `whisper.cpp`. The model is not bundled in the APK. The learner downloads it once from the model screen (~77 MB), after which recognition runs on-device and can work offline.

The app intentionally does **not** provide the expected ayah as Whisper's initial prompt, because doing so could bias transcription toward the answer and make memorization grading less trustworthy.

The Recitation Coach assesses **text/memorization accuracy**. It does not claim teacher-level tajwid, makhraj, or madd judgement.

## Audio

Online recitation audio uses Al Quran Cloud / Islamic Network ayah-level audio. Streaming and explicit offline downloads use the same player. Hifz Journey does not require a Quran Foundation OAuth backend.

## Build on GitHub

The included GitHub Actions workflow builds the Android release APK. Push this repository to GitHub and open **Actions** to obtain the generated APK artifact.

See `V3_SCOPE.md` for the V3 roadmap and `V2_AUDIO_ARCHITECTURE.md` for the audio design.


### GitHub Android native toolchain
The APK workflow installs and accepts the license for Android NDK 29.0.13113456, which is required by the on-device whisper_ggml/whisper.cpp recognizer.
