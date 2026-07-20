# MindPulse AI Mobile Build Environment

Flutter compile-time configuration should be provided through the build command. Do not place server credentials in mobile configuration.

## Compile-time variables

- `API_BASE_URL`

## Android emulator development

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api/v1
```

## Production Android App Bundle

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

## Firebase client configuration

`firebase_options.dart` is Flutter Firebase client configuration. It must not contain service-account private keys or server credentials.
Before release, configure Firebase API restrictions, Android package/signing certificates, Firestore/Storage rules, authorized domains and App Check.

## Build rules

- Production API endpoints must use HTTPS.
- Do not place database passwords or JWT secrets in `--dart-define`.
- Do not use localhost or emulator addresses in production release builds.
