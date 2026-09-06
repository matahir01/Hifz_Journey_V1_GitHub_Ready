# Hifz Journey — V1 Foundation

Offline-first Flutter Qur’an reading and memorization companion.

## Included
- Local SQLite Qur’an database (6,236 ayahs) with surah, page and juz metadata.
- Reading continuation and bookmarks.
- Hifz progress model and adaptive revision engine.
- Daily 2–3 ayah default target (configurable).
- Local notification architecture.
- Local audio service interface ready for legitimately licensed/downloaded recitations.
- Polished starter UI: Home, Qur’an, Hifz, Progress, Settings.
- AI recitation service interface (provider-neutral; no cloud key required).

## Important content/licensing note
The Arabic Qur’an text in `assets/quran/quran.db` is a verbatim copy of the text found in the supplied Ayat archive. The archive identifies Tanzil as its source. Tanzil currently states that its Quran text may be used in applications under CC BY 3.0 provided the text is not changed, Tanzil is clearly credited, and the license notice/source link is included. Before publishing, re-verify the exact text against the current Tanzil release and retain the required attribution.

Official source: https://tanzil.net/docs/Text_License
Download/source: https://tanzil.net/download/

Translations and recitations are NOT bundled in this V1 package because their individual redistribution terms must be verified separately.

## Requirements
- Flutter 3.35+ / Dart 3.9+ recommended.
- Android SDK 35 recommended.

## Run
```bash
flutter pub get
flutter run
```

## Build Android
```bash
flutter build apk --release
```

The environment used to assemble this ZIP does not contain the Flutter SDK, so the generated project could not be compiled here. Run `flutter pub get`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test` on a machine with Flutter installed.

## Audio
Place legitimately licensed downloaded recitation files in the app's application support directory. Do not copy recitations from another app unless you have redistribution rights.
