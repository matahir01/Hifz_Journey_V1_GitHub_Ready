# Hifz Journey

**Read. Memorize. Revise. Retain.**

Hifz Journey is an offline-first Flutter Qur’an reading and memorization app. V1 needs no account, no cloud backend, and no API key.

## Included in V1

- Complete local Qur’an database: 114 surahs / 6,236 ayahs.
- Surah, Juz, and page browsing.
- Full-screen swipe reader with saved reading position.
- Arabic-text and `surah:ayah` search.
- Local bookmarks.
- Daily memorization target.
- Adaptive retention-first revision intervals.
- Recall test mode.
- Progress dashboard with introduced / learning / stable / mastered states.
- Persistent settings, theme mode, and local daily reminders.
- Local audio service boundary for future licensed recitation downloads.
- Provider-neutral recitation-assessment interface for a future AI feature.
- GitHub Actions for analyze/test and Android APK/AAB release builds.

## GitHub deployment

Push this repository to GitHub. Every push/PR to `main` runs `flutter analyze` and `flutter test`.

To create Android release artifacts, either run the **Android Release Build** workflow manually or push a tag such as:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds both an APK and an Android App Bundle. Tagged builds are also attached to the GitHub Release.

## Local Android build

A Gradle wrapper binary is generated from the installed Flutter SDK so the repository does not need a hand-authored binary wrapper file.

Windows PowerShell:

```powershell
flutter pub get
.\tool\bootstrap_android_wrapper.ps1
flutter build apk --release
```

macOS/Linux:

```bash
flutter pub get
bash tool/bootstrap_android_wrapper.sh
flutter build apk --release
```

## Release signing

The included Android release configuration uses debug signing so GitHub can produce installable test builds immediately. Before publishing to Google Play, replace it with your own release keystore / Play App Signing configuration and keep secrets outside the repository.

## Qur’an text attribution

The bundled Arabic Qur’an text was derived from the supplied Ayat archive, which identifies the Tanzil Project as its text source. Tanzil permits application use under CC BY 3.0 with attribution and requires the Qur’an text to remain verbatim. Re-verify the bundled text against the current Tanzil release before public store publication and retain the required source/license notice.

- Tanzil Project: https://tanzil.net/
- Text license: https://tanzil.net/docs/Text_License

Translations and recitation audio are not redistributed in this repository because their licensing must be verified separately.


## GitHub Actions

Every push to `main` or `master` performs a real Android release APK build and uploads `Hifz-Journey.apk` as a workflow artifact.
