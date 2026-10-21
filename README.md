# Lifeline Customer (Android / Flutter)

Customer app for the Lifeline service-booking platform. Uses the live backend
at `https://purulia.lifelineapp.in` (same accounts as the website).

**Screens:** Login / Create account (mobile + 4-digit PIN) → Book (service, qty, budget, date/time, GPS address) →
Current bookings (quotes, accept, mark completed, cancel) → History → Feedback → Profile.

## Build on Codemagic
1. Connect this repo in Codemagic and pick the `codemagic.yaml` workflow `android-release`.
2. The build runs `tool/prepare_android.sh` (creates the `android/` folder, adds Internet / Location permissions), then builds an **APK** and an **AAB**.
3. APK = install on phone to test. AAB = upload to Play Store.
4. For Play Store, add an Android keystore in Codemagic (reference name `lifeline_keystore`) and uncomment `android_signing` in `codemagic.yaml`.

## Run locally
```
bash tool/prepare_android.sh
flutter pub get
flutter run
```
Backend URL is the `kBaseUrl` constant in `lib/api.dart`.
