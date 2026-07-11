# Home Info Clock

Home Info Clock is now a Flutter-based Android kiosk app.

The current Flutter APK is a technical baseline, not an accepted final UI.
See [`docs/CURRENT_PRODUCT_DIRECTION.md`](docs/CURRENT_PRODUCT_DIRECTION.md)
before starting new product work.

## Project Layout

- `lib/` contains the Flutter application entrypoint, live app wiring, controllers, services, and widgets.
- `android/` contains the generated Flutter Android host configured with application id `com.homepanel.clock`.
- `legacy/native-android/` contains the archived native Android implementation kept for reference during the rebuild.
- `docs/FLUTTER_APP.md` contains the Flutter build and local secret instructions.
- `docs/CURRENT_PRODUCT_DIRECTION.md` contains the current requirements and
  supersedes conflicting requirements in the historical rebuild spec and plan.

## Getting Started

Run the standard Flutter workflow from the project root:

```powershell
D:\test\flutter\bin\flutter.bat pub get
D:\test\flutter\bin\flutter.bat analyze
D:\test\flutter\bin\flutter.bat test
D:\test\flutter\bin\flutter.bat build apk --debug
```

The old native Android reference code lives under `legacy/native-android/`.
