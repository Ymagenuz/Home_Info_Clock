# Home Info Clock

Home Info Clock is now a Flutter-based Android kiosk app.

## Project Layout

- `lib/` contains the Flutter application entrypoint, live app wiring, controllers, services, and widgets.
- `android/` contains the generated Flutter Android host configured with application id `com.homepanel.clock`.
- `legacy/native-android/` contains the archived native Android implementation kept for reference during the rebuild.
- `docs/FLUTTER_APP.md` contains the Flutter build and local secret instructions.

## Getting Started

Run the standard Flutter workflow from the project root:

```powershell
D:\test\flutter\bin\flutter.bat pub get
D:\test\flutter\bin\flutter.bat analyze
D:\test\flutter\bin\flutter.bat test
D:\test\flutter\bin\flutter.bat build apk --debug
```

The old native Android reference code lives under `legacy/native-android/`.
