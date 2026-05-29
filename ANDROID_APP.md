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
- Weather comes from Open-Meteo in native Java code.
- City labels come from Android `Geocoder`, with coordinates as the fallback.
- Battery state comes from Android `ACTION_BATTERY_CHANGED`.
