# Android WebView App

This project wraps `clock.html` in a native Android WebView shell named Home Info Clock.

## Build

Open this folder in Android Studio, let Gradle sync, then run the `app` configuration on the target device.

The Gradle task `syncClockHtml` copies the root `clock.html` into the Android asset bundle before build, so the app always uses the current home panel page.

## Native Bridge

The WebView exposes `window.HomePanelNative` to JavaScript:

- `HomePanelNative.getLocation()` returns `{ ok, latitude, longitude, accuracy, provider, source }`.
- `HomePanelNative.getBattery()` returns `{ ok, level, charging }`.
- `HomePanelNative.openApp(packageName)` opens an installed app by package name.
- `HomePanelNative.openUrl(url)` opens a URL or deep link.
- `HomePanelNative.openIntent(intentUri)` opens an Android intent URI.
- `HomePanelNative.openLocationSettings()` opens Android location settings.

The page prefers the native bridge first, then Fully Kiosk, then browser geolocation.
