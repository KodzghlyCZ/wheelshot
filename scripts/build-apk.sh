#!/usr/bin/env bash
# Build WheelShot on the real host (run in a normal terminal as your user).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export JAVA_HOME="${JAVA_HOME:-$HOME/jdks/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
# Cursor's sandbox points Gradle at an empty /tmp cache, so every build
# re-downloads the wrapper and the Flutter engine jars. Always use the
# real cache under the home directory.
export GRADLE_USER_HOME="${GRADLE_USER_HOME_REAL:-$HOME/.gradle}"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"
export PATH="$HOME/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true

if ! command -v flutter >/dev/null; then
  echo "Flutter not found. Expected ~/flutter on PATH."
  exit 1
fi

SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
# Flutter 3.47 + camera_android need platform 36 + NDK 28.2.13676358
NEED_PLATFORM=android-36
NEED_NDK=28.2.13676358

if [ ! -d "$ANDROID_HOME/platforms/$NEED_PLATFORM" ] || [ ! -d "$ANDROID_HOME/ndk/$NEED_NDK" ]; then
  echo "Installing Android SDK pieces (platform 36 + NDK $NEED_NDK)..."
  yes | "$SDKMANAGER" --install "platforms;$NEED_PLATFORM" "build-tools;36.0.0" "ndk;$NEED_NDK"
fi

# Do NOT set ndk.dir — let android.ndkVersion (Flutter default) pick the side-by-side NDK.
cat > android/local.properties <<EOF
flutter.sdk=$(dirname "$(dirname "$(command -v flutter)")")
sdk.dir=$ANDROID_HOME
EOF

flutter config --jdk-dir="$JAVA_HOME" --no-analytics >/dev/null
flutter pub get
flutter build apk --debug -v --android-skip-build-dependency-validation

APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
echo
echo "APK: $APK"
ls -lh "$APK"

if adb devices | grep -qE $'\tdevice$'; then
  echo "Installing on connected device..."
  adb install -r "$APK"
  adb shell am start -n com.wheelshot.app/.MainActivity || true
else
  echo "No adb device. Plug in Pixel 6a (USB debugging on), then:"
  echo "  adb install -r $APK"
fi
