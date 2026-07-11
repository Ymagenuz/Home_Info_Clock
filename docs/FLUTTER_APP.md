# Home Info Clock Flutter App

## Current Direction

The APK currently builds and runs, but its UI and interactions have not passed
product acceptance. Read [`CURRENT_PRODUCT_DIRECTION.md`](CURRENT_PRODUCT_DIRECTION.md)
before changing product behavior. The native Java app under
`legacy/native-android/` is the visual and interaction reference for the next
optimization pass.

## Build

```powershell
D:\test\flutter\bin\flutter.bat pub get
D:\test\flutter\bin\flutter.bat analyze
D:\test\flutter\bin\flutter.bat test
D:\test\flutter\bin\flutter.bat build apk --debug
```

## Local Secrets

Pass secrets with `--dart-define`:

```powershell
D:\test\flutter\bin\flutter.bat run --dart-define=UAPI_TOKEN=your_token
```

Do not commit UAPI, GPTsAPI, or QWeather secrets.
