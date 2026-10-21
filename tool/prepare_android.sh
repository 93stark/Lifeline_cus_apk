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
# app name shown on the phone
s = re.sub(r'android:label="[^"]*"', 'android:label="Lifeline"', s, count=1)
open(p, "w", encoding="utf-8").write(s)
PY

rm -rf test
echo "Android project ready."
