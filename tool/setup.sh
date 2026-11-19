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
  set_key NSHealthShareUsageDescription "WeighWell reads your steps, walking distance, active calories and weight to show calories in and out."
  set_key NSHealthUpdateUsageDescription "WeighWell does not write to Apple Health."
fi

# HealthKit entitlement (Apple Health). The App Store profile must also
# have HealthKit turned on — see docs/CODEMAGIC.md.
if [ -d ios/Runner ]; then
  cat > ios/Runner/Runner.entitlements <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
</dict>
</plist>
XML
  python3 - ios/Runner.xcodeproj/project.pbxproj <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()
if "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" not in src:
    # Runner target configs are the ones whose bundle id has no ".RunnerTests".
    src = re.sub(r"(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = ([A-Za-z0-9.\-]+);)",
                 lambda m: m.group(1) if m.group(3).endswith("RunnerTests")
                 else "\n" + m.group(2) + "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;" + m.group(1),
                 src)
    open(path, "w").write(src)
PY
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
    '<uses-permission android:name="android.permission.health.READ_STEPS"/>',
    '<uses-permission android:name="android.permission.health.READ_DISTANCE"/>',
    '<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>',
    '<uses-permission android:name="android.permission.health.READ_WEIGHT"/>',
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

# Health Connect (Android): permission rationale screens, package query,
# FlutterFragmentActivity and minSdk 26.
if [ -f "$MANIFEST" ]; then
  python3 - "$MANIFEST" <<'PY'
import sys
path = sys.argv[1]
xml = open(path).read()
if "ACTION_SHOW_PERMISSIONS_RATIONALE" not in xml:
    rationale = (
        '            <intent-filter>\n'
        '                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        '            </intent-filter>\n'
    )
    i = xml.find("</activity>")
    xml = xml[:i] + rationale + "        " + xml[i:]
    alias = (
        '        <activity-alias\n'
        '            android:name="ViewPermissionUsageActivity"\n'
        '            android:exported="true"\n'
        '            android:targetActivity=".MainActivity"\n'
        '            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>\n'
        '                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>\n'
        '            </intent-filter>\n'
        '        </activity-alias>\n'
    )
    i = xml.find("</application>")
    xml = xml[:i] + alias + "    " + xml[i:]
if "com.google.android.apps.healthdata" not in xml:
    q = (
        '        <package android:name="com.google.android.apps.healthdata"/>\n'
        '        <intent>\n'
        '            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE"/>\n'
        '        </intent>\n'
    )
    if "<queries>" in xml:
        xml = xml.replace("<queries>", "<queries>\n" + q.rstrip("\n"), 1)
    else:
        xml = xml.replace("</manifest>", "    <queries>\n" + q + "    </queries>\n</manifest>", 1)
open(path, "w").write(xml)
PY
fi

for ACT in $(find android/app/src/main -name "MainActivity.kt" -o -name "MainActivity.java" 2>/dev/null); do
  python3 - "$ACT" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
s = s.replace(": FlutterActivity()", ": FlutterFragmentActivity()").replace("extends FlutterActivity", "extends FlutterFragmentActivity")
open(p, "w").write(s)
PY
done

for GRADLE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE" ]; then
    python3 - "$GRADLE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", s)
s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", s)
s = re.sub(r"minSdk\s*=\s*(2[0-5]|1\d)\b", "minSdk = 26", s)
open(p, "w").write(s)
PY
  fi
done

# Skip the release "lint vital" check: it can crash on plugin code and
# is not needed to produce a working APK.
for GRADLE in android/app/build.gradle.kts android/app/build.gradle; do
  if [ -f "$GRADLE" ] && ! grep -q "checkReleaseBuilds" "$GRADLE"; then
    python3 - "$GRADLE" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
kts = path.endswith(".kts")
block = "    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }\n" if kts \
    else "    lint {\n        checkReleaseBuilds false\n        abortOnError false\n    }\n"
i = src.find("android {")
if i >= 0:
    j = src.find("\n", i) + 1
    src = src[:j] + block + src[j:]
    open(path, "w").write(src)
PY
  fi
done

# ----------------------------------------------------------------- Web
if [ -f web/index.html ]; then
  sed -i.bak -E 's#<title>.*</title>#<title>WeighWell</title>#' web/index.html && rm -f web/index.html.bak
fi

echo
echo "Done. Try it:"
echo "  flutter run -d chrome          # web"
echo "  flutter run                    # phone or simulator"
echo "  flutter test                   # unit tests"
