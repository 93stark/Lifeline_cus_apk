#!/usr/bin/env bash
# Generates the Android platform folder and applies the settings this app needs.
# Run from the repo root (Codemagic does this automatically).
set -euo pipefail

flutter create --platforms=android --org in.lifelineapp --project-name lifeline_customer .

MANIFEST=android/app/src/main/AndroidManifest.xml

python3 - "$MANIFEST" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding="utf-8").read()

perms = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n'
)
queries = (
    '    <queries>\n'
    '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n'
    '        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n'
    '    </queries>\n'
)
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', perms + '    <application', 1)
if '<queries>' not in s:
    s = s.replace('</manifest>', queries + '</manifest>', 1)
# Some phones (Redmi/Xiaomi) show a blank white screen with Impeller; use the stable Skia renderer.
if 'EnableImpeller' not in s:
    s = s.replace('<application', '<application', 1)
    s = re.sub(r'(<application[^>]*>)', r'\1\n        <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"/>', s, count=1)
# app name shown on the phone
s = re.sub(r'android:label="[^"]*"', 'android:label="Lifeline"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
PY

rm -rf test

# App icon (Lifeline logo)
RES=android/app/src/main/res
for d in tool/icons/mipmap-*; do
  n=$(basename "$d")
  mkdir -p "$RES/$n"
  cp "$d/ic_launcher.png" "$RES/$n/ic_launcher.png"
done
rm -rf "$RES"/mipmap-anydpi* 2>/dev/null || true

# Dark-blue launch screen instead of a white flash
mkdir -p "$RES/drawable"
cat > "$RES/drawable/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="#FF0B2A4A"/>
</layer-list>
XML
echo "Android project ready."
