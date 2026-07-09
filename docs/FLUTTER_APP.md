# Home Info Clock Flutter App

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
