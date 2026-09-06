# Hifz Journey Android deployment

The GitHub Actions workflow builds an installable release APK and validates its ZIP structure, Android package metadata, launcher icon entry, and APK signature before uploading it as an artifact.

## Test release signing

The current CI/test release intentionally uses Android's debug signing configuration so the APK can be installed for testing without requiring GitHub secrets. This is not the final Play Store signing configuration.

Before Play Store distribution, create a private upload key and configure it through GitHub Secrets. Do not commit a production keystore or its passwords to the repository.

## Launcher icon compatibility fix

The Android application uses real PNG launcher icons for all density buckets and no adaptive-icon XML. This avoids the zero-size adaptive foreground drawable that caused the Android Package Installer crash on the previously generated APK.
