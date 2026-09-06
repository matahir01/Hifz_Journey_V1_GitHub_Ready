# Deployment checklist

## GitHub
1. Create a GitHub repository and push this project.
2. Confirm **Flutter CI** passes on `main`.
3. Run **Android Release Build** manually for an installable APK/AAB, or push a `v*` tag.

## Before public Play Store release
- Replace debug release signing with a private release keystore or Play App Signing.
- Choose and lock your final `applicationId` if `com.hifzjourney.app` is not the final package name.
- Re-verify the bundled Qur’an text against the current Tanzil release and keep the attribution notice.
- Add a privacy policy describing the app's local-only V1 data handling.
- Test notifications and database migration on physical Android devices.
- If audio is added, verify each reciter/source redistribution license before bundling or downloading it.
