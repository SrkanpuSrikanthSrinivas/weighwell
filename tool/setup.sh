#!/usr/bin/env bash
# One-time setup on your Mac: generates the iOS, Android and web project
# folders and adds the camera / Bluetooth permissions the app needs.
# Safe to run again.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed. Get it from https://docs.flutter.dev/get-started/install/macos"
  exit 1
fi

echo "==> Creating platform folders (keeps your lib/ code)"
flutter create . --project-name weighwell --org com.aiqeacademy --platforms=android,ios,web

# flutter create adds a sample widget test that does not match this app.
rm -f test/widget_test.dart

echo "==> Getting packages"
flutter pub get

# ---------------------------------------------------------------- iOS
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && [ -x /usr/libexec/PlistBuddy ]; then
  echo "==> Adding iOS permission messages"
  set_key() {
    /usr/libexec/PlistBuddy -c "Set :$1 $2" "$PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :$1 string $2" "$PLIST"
  }
  set_key NSCameraUsageDescription "WeighWell uses the camera to see your food and scan barcodes."
  set_key NSPhotoLibraryUsageDescription "WeighWell lets you pick a food photo from your library."
  set_key NSBluetoothAlwaysUsageDescription "WeighWell connects to your Bluetooth kitchen scale to read the weight."
  set_key CFBundleDisplayName "WeighWell"
fi

# The barcode scanner needs iOS 15.5 or newer.
if [ "$(uname)" = "Darwin" ]; then
  flutter build ios --config-only --no-codesign >/dev/null 2>&1 || true
  if [ -f ios/Podfile ]; then
    sed -i '' -E "s/^#? *platform :ios, '[0-9.]+'/platform :ios, '15.5'/" ios/Podfile
    grep -q "^platform :ios" ios/Podfile || sed -i '' "1s/^/platform :ios, '15.5'\n/" ios/Podfile
  fi
  if [ -f ios/Runner.xcodeproj/project.pbxproj ]; then
    sed -i '' -E 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 15.5;/g' ios/Runner.xcodeproj/project.pbxproj
  fi
fi

# ------------------------------------------------------------- Android
MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  echo "==> Adding Android permissions"
  python3 - "$MANIFEST" <<'PY'
import sys, re
path = sys.argv[1]
xml = open(path).read()
perms = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.CAMERA"/>',
    '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>',
    '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>',
    '<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>',
    '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>',
    '<uses-feature android:name="android.hardware.bluetooth_le" android:required="false"/>',
    '<uses-feature android:name="android.hardware.camera" android:required="false"/>',
]
missing = [p for p in perms if re.search(r'android:name="([^"]+)"', p).group(1) not in xml]
if missing:
    block = "\n    ".join(missing)
    xml = xml.replace("<application", "    " + block + "\n    <application", 1)
xml = re.sub(r'android:label="[^"]*"', 'android:label="WeighWell"', xml, count=1)
open(path, "w").write(xml)
PY
fi

# ----------------------------------------------------------------- Web
if [ -f web/index.html ]; then
  sed -i.bak -E 's#<title>.*</title>#<title>WeighWell</title>#' web/index.html && rm -f web/index.html.bak
fi

echo
echo "Done. Try it:"
echo "  flutter run -d chrome          # web"
echo "  flutter run                    # phone or simulator"
echo "  flutter test                   # unit tests"
