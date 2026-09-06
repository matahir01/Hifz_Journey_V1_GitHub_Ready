# Changelog

## 1.0.0
- Completed offline-first Qur’an reader and Hifz V1.
- Added Surah/Juz/Page navigation, search, bookmarks, and reading progress.
- Added adaptive Hifz planning, revision, recall tests, and progress metrics.
- Added persistent settings, theme mode, reminder scheduling, and notification permissions.
- Migrated Android project to Flutter Plugin DSL and a GitHub-ready build/release workflow.

## 1.0.1 - Android installer compatibility rebuild
- Rebuilt Android configuration around Flutter's Plugin DSL structure.
- Removed malformed adaptive launcher icon resources that had no intrinsic size.
- Added real PNG normal and round launcher icons across all Android densities.
- Preserved Java 17 and core library desugaring required by local notifications.
- Added APK archive, signature, package metadata and launcher-icon validation to GitHub Actions.
