#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/android/gradle/wrapper/gradle-wrapper.jar" && -f "$ROOT/android/gradlew" ]]; then
  exit 0
fi
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
flutter create --platforms=android --project-name hifz_journey --org com.hifzjourney "$TMP/bootstrap" >/dev/null
mkdir -p "$ROOT/android/gradle/wrapper"
cp "$TMP/bootstrap/android/gradlew" "$ROOT/android/gradlew"
cp "$TMP/bootstrap/android/gradlew.bat" "$ROOT/android/gradlew.bat"
cp "$TMP/bootstrap/android/gradle/wrapper/gradle-wrapper.jar" "$ROOT/android/gradle/wrapper/gradle-wrapper.jar"
cat > "$ROOT/android/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
EOF
chmod +x "$ROOT/android/gradlew"
