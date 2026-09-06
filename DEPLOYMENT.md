# GitHub APK Build

This repository is configured to build the Android APK automatically with GitHub Actions.

## Automatic build

Every push to `main` or `master` runs `.github/workflows/android_build.yml` and performs a real Flutter release APK build:

```bash
flutter build apk --release
```

When the build succeeds, GitHub uploads this installable APK as the workflow artifact:

`Hifz-Journey-APK` → `Hifz-Journey.apk`

The artifact is retained for 30 days.

## Tagged releases

Pushing a tag such as `v1.0.0` also builds the APK and attaches `Hifz-Journey.apk` to the GitHub Release.

## Android signing

The current V1 release configuration uses the Android debug signing key for the release build so GitHub can produce an installable APK without repository secrets. Before Google Play publication, replace it with a private release keystore and GitHub Actions secrets.
