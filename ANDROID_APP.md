# Home Info Clock Android App

This project now uses a native Android interface instead of WebView.

## Build

Open this folder in Android Studio, let Gradle sync, then run the `app` configuration on the target device.

The command-line build used in this workspace is:

```powershell
$env:JAVA_HOME='D:\test\kiosk\.tools\jdk17\jdk-17.0.19+10'
$env:ANDROID_HOME='D:\test\kiosk\.tools\android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:Path="$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:Path"
.\.tools\gradle-8.9\bin\gradle.bat --no-daemon assembleDebug
```

The APK is generated at:

```text
app\build\outputs\apk\debug\app-debug.apk
```

## Runtime

- The UI is drawn by `HomePanelView`, with column widths, clock size, and text size calculated from the device screen.
- Location comes from Android `LocationManager`.
- Weather comes from UAPI realtime weather by default.
- City labels come from Android `Geocoder`, with coordinates as the fallback.
- Battery state comes from Android `ACTION_BATTERY_CHANGED`.
- QWeather is optional and used only as an enhancement path when UAPI is unavailable or when future forecast data is needed.
- Before taking device screenshots for visual QA, ask the user first. Screenshots are useful but expensive in token budget.

## UAPI Weather

The personal app uses UAPI as the primary weather source because it requires no account or key:

```text
https://uapis.cn/api/v1/misc/weather?city=...&forecast=true&indices=true
```

The app queries by district first, then city, based on Android `Geocoder` results. UAPI provides realtime weather, current temperature, humidity, wind, report time, up to 7 days of forecast data via `forecast=true`, and lifestyle indices via `indices=true`. Open-Meteo and QWeather remain fallback/enhancement paths only when UAPI is unavailable or missing forecast data.

## QWeather Configuration

QWeather remains supported as an optional complete forecast source. For formal QWeather projects, prefer JWT authentication. Create or update `local.properties` with your project id, credential key id, private key file, and API host:

```properties
QWEATHER_API_HOST=your_api_host.qweatherapi.com
QWEATHER_JWT_PROJECT_ID=your_project_id
QWEATHER_JWT_KEY_ID=your_credential_key_id
QWEATHER_JWT_PRIVATE_KEY_FILE=private/qweather-ed25519-private.pem
```

You can also provide the PEM content directly as `QWEATHER_JWT_PRIVATE_KEY`, but using a local file is easier to maintain. Keep the private key file outside Git.

The app generates an Ed25519 JWT locally and sends:

```text
Authorization: Bearer <jwt>
```

The token is cached and refreshed before expiry.

For temporary development, the legacy API key mode is still supported:

```properties
QWEATHER_API_KEY=your_api_key
QWEATHER_API_HOST=your_api_host.qweatherapi.com
```

`QWEATHER_API_HOST` is shown in QWeather Console settings. The legacy shared host `devapi.qweather.com` is used as a development fallback when this value is omitted, but QWeather recommends switching to your own API Host.

Security note: embedding a JWT private key in an APK is acceptable only for a trusted personal kiosk build. For a public or distributed app, issue short-lived JWTs from your own backend instead of shipping the private key in the client.

The app calls:

- `/v7/weather/now` for current weather.
- `/v7/weather/7d` for the 7-day forecast.
- `/v7/indices/3d` for clothing, sports, travel, and sun-protection suggestions.

When UAPI is unavailable and QWeather credentials are configured, the app can fall back to QWeather for full forecast data.
