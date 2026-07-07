# Flutter Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Home Info Clock as a Flutter-first Android kiosk app in `D:\test\Home_Info_Clock`.

**Architecture:** The repository root becomes the Flutter app root. The old native Android implementation is preserved under `legacy/native-android/`. Flutter widgets own layout, paging, text, and animation; focused `CustomPainter` classes draw only the analog clock, weather icons, metric rings, and timer rings.

**Tech Stack:** Flutter SDK at `D:\test\flutter\bin\flutter.bat`, Dart, Android Kotlin host, `ChangeNotifier` controllers, `PageView`, `CustomPainter`, `shared_preferences`, `http`, `geolocator`, `geocoding`, `permission_handler`, `wakelock_plus`, `battery_plus`, `flutter_test`.

## Global Constraints

- Work in `D:\test\Home_Info_Clock`.
- Use `D:\test\flutter\bin\flutter.bat` for Flutter commands.
- Android package/application id is `com.homepanel.clock`.
- Preserve native Android reference code under `legacy/native-android/`.
- Use Flutter widgets and layout primitives for panels, paging, text, controls, and overlays.
- Use `CustomPainter` only for focused drawing components: analog clock, weather icons, metric rings, and timer rings.
- Keep secrets out of Git; support `--dart-define` for `UAPI_TOKEN`, `GPTSAPI_API_KEY`, `GPTSAPI_BASE_URL`, `GPTSAPI_MODEL`, `QWEATHER_API_HOST`, `QWEATHER_API_KEY`, `QWEATHER_JWT_PROJECT_ID`, `QWEATHER_JWT_KEY_ID`, and `QWEATHER_JWT_PRIVATE_KEY`.
- Ask the user before taking screenshots from the connected phone.
- Do not use device-only verification as the only proof; run `flutter analyze`, `flutter test`, and `flutter build apk --debug`.

---

## File Structure

Create or modify these files during implementation:

```text
legacy/native-android/
  app/
  build.gradle
  settings.gradle
  ANDROID_APP.md

pubspec.yaml
analysis_options.yaml
.gitignore
README.md
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt

lib/
  main.dart
  app.dart
  models/
    app_config.dart
    battery_status.dart
    timer_state.dart
    weather.dart
  services/
    ai_advice_service.dart
    cache_service.dart
    http_json_client.dart
    open_meteo_weather_source.dart
    platform_service.dart
    qweather_weather_source.dart
    uapi_weather_source.dart
    weather_service.dart
    weather_source.dart
  state/
    home_controller.dart
    timer_controller.dart
  screens/
    home_clock_screen.dart
  widgets/
    clock_panel.dart
    metric_cell.dart
    quick_actions_panel.dart
    simple_mode_view.dart
    timer_panel.dart
    tomorrow_panel.dart
    weather_panel.dart
  painters/
    analog_clock_painter.dart
    timer_painter.dart
    weather_icon_painter.dart

test/
  models/
    app_config_test.dart
    timer_state_test.dart
    weather_test.dart
  services/
    ai_advice_service_test.dart
    cache_service_test.dart
    open_meteo_weather_source_test.dart
    uapi_weather_source_test.dart
    weather_service_test.dart
  state/
    home_controller_test.dart
    timer_controller_test.dart
  widgets/
    home_clock_screen_test.dart
    timer_panel_test.dart
```

---

### Task 1: Flutter Project Scaffold And Legacy Archive

**Files:**
- Move: `app/` to `legacy/native-android/app/`
- Move: `build.gradle` to `legacy/native-android/build.gradle`
- Move: `settings.gradle` to `legacy/native-android/settings.gradle`
- Move: `ANDROID_APP.md` to `legacy/native-android/ANDROID_APP.md`
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`
- Modify: `test/widget_test.dart`
- Modify: `.gitignore`
- Modify: `README.md`
- Generated: `android/`

**Interfaces:**
- Produces: root Flutter package named `home_info_clock`
- Produces: Android application id `com.homepanel.clock`
- Produces: `HomeInfoClockApp` widget in `lib/app.dart`

- [ ] **Step 1: Verify clean starting state**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock status --short
```

Expected: no output.

- [ ] **Step 2: Archive the existing Android project**

Run this PowerShell from `D:\test\Home_Info_Clock`:

```powershell
$root = (Resolve-Path .).Path
$legacy = Join-Path $root 'legacy\native-android'
$items = @('app', 'build.gradle', 'settings.gradle', 'ANDROID_APP.md')
New-Item -ItemType Directory -Force $legacy
foreach ($item in $items) {
  $source = Join-Path $root $item
  if (Test-Path -LiteralPath $source) {
    $resolvedSource = (Resolve-Path -LiteralPath $source).Path
    if (-not $resolvedSource.StartsWith($root)) { throw "Refusing to move outside workspace: $resolvedSource" }
    Move-Item -LiteralPath $resolvedSource -Destination (Join-Path $legacy $item)
  }
}
```

Expected: `legacy/native-android/app/src/main/java/com/homepanel/clock/HomePanelView.java` exists.

- [ ] **Step 3: Create the Flutter project shell**

Run:

```powershell
D:\test\flutter\bin\flutter.bat create --project-name home_info_clock --org com.homepanel --android-language kotlin --platforms android --no-pub .
```

Expected: `pubspec.yaml`, `lib/main.dart`, and `android/app/src/main/kotlin/com/homepanel/home_info_clock/MainActivity.kt` are created.

- [ ] **Step 4: Rename Android host package path to `com.homepanel.clock`**

Move generated Kotlin host file:

```powershell
New-Item -ItemType Directory -Force android\app\src\main\kotlin\com\homepanel\clock
Move-Item -LiteralPath android\app\src\main\kotlin\com\homepanel\home_info_clock\MainActivity.kt -Destination android\app\src\main\kotlin\com\homepanel\clock\MainActivity.kt
```

Then edit `android/app/build.gradle.kts` so `namespace` and `applicationId` are:

```kotlin
namespace = "com.homepanel.clock"

defaultConfig {
    applicationId = "com.homepanel.clock"
}
```

Edit `android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt`:

```kotlin
package com.homepanel.clock

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
```

- [ ] **Step 5: Replace app entry with a stable smoke-testable app**

Set `lib/main.dart`:

```dart
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  runApp(const HomeInfoClockApp());
}
```

Set `lib/app.dart`:

```dart
import 'package:flutter/material.dart';

class HomeInfoClockApp extends StatelessWidget {
  const HomeInfoClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Info Clock',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: const Scaffold(
        backgroundColor: Color(0xFF061016),
        body: Center(child: Text('Home Info Clock')),
      ),
    );
  }
}
```

- [ ] **Step 6: Replace generated smoke test**

Set `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/app.dart';

void main() {
  testWidgets('HomeInfoClockApp renders smoke title', (tester) async {
    await tester.pumpWidget(const HomeInfoClockApp());

    expect(find.text('Home Info Clock'), findsOneWidget);
  });
}
```

- [ ] **Step 7: Configure dependencies**

Set the dependency portion of `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  battery_plus: ^6.0.3
  geocoding: ^3.0.0
  geolocator: ^13.0.2
  http: ^1.2.2
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
  wakelock_plus: ^1.2.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

- [ ] **Step 8: Fetch dependencies**

Run:

```powershell
D:\test\flutter\bin\flutter.bat pub get
```

Expected: `Resolving dependencies...` followed by `Got dependencies!`.

- [ ] **Step 9: Verify scaffold**

Run:

```powershell
D:\test\flutter\bin\flutter.bat analyze
D:\test\flutter\bin\flutter.bat test
```

Expected: analyze has no issues; test reports all generated tests passing or reports no tests only if Flutter generated none.

- [ ] **Step 10: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add .
git -c safe.directory=D:/test/Home_Info_Clock commit -m "chore: scaffold Flutter app"
```

---

### Task 2: Domain Models And Configuration

**Files:**
- Create: `lib/models/app_config.dart`
- Create: `lib/models/battery_status.dart`
- Create: `lib/models/timer_state.dart`
- Create: `lib/models/weather.dart`
- Create: `test/models/app_config_test.dart`
- Create: `test/models/timer_state_test.dart`
- Create: `test/models/weather_test.dart`

**Interfaces:**
- Produces: `AppConfig.fromEnvironment()`
- Produces: `BatteryStatus`
- Produces: `TimerState`
- Produces: `WeatherSnapshot`, `WeatherDay`, `WeatherRequest`

- [ ] **Step 1: Write model tests**

Create `test/models/app_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/app_config.dart';

void main() {
  test('AppConfig supplies documented defaults', () {
    const config = AppConfig();

    expect(config.gptsApiBaseUrl, 'https://api.gptsapi.net/v1');
    expect(config.gptsApiModel, 'gpt-5.4-nano');
    expect(config.hasUapiToken, isFalse);
    expect(config.hasGptsApiKey, isFalse);
  });
}
```

Create `test/models/timer_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';

void main() {
  test('TimerState converts selected units to seconds', () {
    const state = TimerState(hours: 1, minutes: 2, seconds: 3);

    expect(state.totalSeconds, 3723);
  });

  test('TimerState derives remaining time from an end timestamp', () {
    final now = DateTime(2026, 7, 7, 9, 0);
    final state = TimerState.runningUntil(now.add(const Duration(seconds: 65)));

    expect(state.remainingAt(now), const Duration(seconds: 65));
    expect(state.unitsAt(now), const TimerUnits(hours: 0, minutes: 1, seconds: 5));
  });
}
```

Create `test/models/weather_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';

void main() {
  test('WeatherSnapshot exposes today and tomorrow safely', () {
    final snapshot = WeatherSnapshot(
      locationLabel: '上海 浦东',
      updatedAt: DateTime(2026, 7, 7, 9, 0),
      currentTemp: 31,
      apparentTemp: 34,
      humidity: 72,
      windKmh: 12,
      currentCode: 2,
      currentDescription: '多云',
      sourceLabel: 'UAPI预报',
      reportTimeLabel: '09:00',
      days: const [
        WeatherDay(date: '2026-07-07', code: 2, description: '多云', high: 33, low: 27),
        WeatherDay(date: '2026-07-08', code: 61, description: '小雨', high: 31, low: 26),
      ],
    );

    expect(snapshot.today?.description, '多云');
    expect(snapshot.tomorrow?.description, '小雨');
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\models
```

Expected: failures mentioning missing model files or missing classes.

- [ ] **Step 3: Implement models**

Create `lib/models/app_config.dart`:

```dart
class AppConfig {
  const AppConfig({
    this.uapiToken = '',
    this.gptsApiKey = '',
    this.gptsApiBaseUrl = 'https://api.gptsapi.net/v1',
    this.gptsApiModel = 'gpt-5.4-nano',
    this.qweatherApiHost = 'devapi.qweather.com',
    this.qweatherApiKey = '',
    this.qweatherJwtProjectId = '',
    this.qweatherJwtKeyId = '',
    this.qweatherJwtPrivateKey = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        uapiToken: String.fromEnvironment('UAPI_TOKEN'),
        gptsApiKey: String.fromEnvironment('GPTSAPI_API_KEY'),
        gptsApiBaseUrl: String.fromEnvironment(
          'GPTSAPI_BASE_URL',
          defaultValue: 'https://api.gptsapi.net/v1',
        ),
        gptsApiModel: String.fromEnvironment(
          'GPTSAPI_MODEL',
          defaultValue: 'gpt-5.4-nano',
        ),
        qweatherApiHost: String.fromEnvironment(
          'QWEATHER_API_HOST',
          defaultValue: 'devapi.qweather.com',
        ),
        qweatherApiKey: String.fromEnvironment('QWEATHER_API_KEY'),
        qweatherJwtProjectId: String.fromEnvironment('QWEATHER_JWT_PROJECT_ID'),
        qweatherJwtKeyId: String.fromEnvironment('QWEATHER_JWT_KEY_ID'),
        qweatherJwtPrivateKey: String.fromEnvironment('QWEATHER_JWT_PRIVATE_KEY'),
      );

  final String uapiToken;
  final String gptsApiKey;
  final String gptsApiBaseUrl;
  final String gptsApiModel;
  final String qweatherApiHost;
  final String qweatherApiKey;
  final String qweatherJwtProjectId;
  final String qweatherJwtKeyId;
  final String qweatherJwtPrivateKey;

  bool get hasUapiToken => uapiToken.trim().isNotEmpty;
  bool get hasGptsApiKey => gptsApiKey.trim().isNotEmpty;
  bool get hasQWeatherApiKey => qweatherApiKey.trim().isNotEmpty;
  bool get hasQWeatherJwtConfig =>
      qweatherJwtProjectId.trim().isNotEmpty &&
      qweatherJwtKeyId.trim().isNotEmpty &&
      qweatherJwtPrivateKey.trim().isNotEmpty;
}
```

Create `lib/models/battery_status.dart`:

```dart
class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.isCharging,
    this.isAvailable = true,
  });

  const BatteryStatus.unavailable()
      : level = -1,
        isCharging = false,
        isAvailable = false;

  final int level;
  final bool isCharging;
  final bool isAvailable;

  bool get isLow => isAvailable && !isCharging && level <= 20;
}
```

Create `lib/models/timer_state.dart`:

```dart
class TimerUnits {
  const TimerUnits({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int hours;
  final int minutes;
  final int seconds;

  @override
  bool operator ==(Object other) =>
      other is TimerUnits &&
      other.hours == hours &&
      other.minutes == minutes &&
      other.seconds == seconds;

  @override
  int get hashCode => Object.hash(hours, minutes, seconds);
}

class TimerState {
  const TimerState({
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
    this.isRunning = false,
    this.endsAt,
    this.isFinished = false,
  });

  factory TimerState.runningUntil(DateTime endsAt) {
    return TimerState(isRunning: true, endsAt: endsAt);
  }

  final int hours;
  final int minutes;
  final int seconds;
  final bool isRunning;
  final DateTime? endsAt;
  final bool isFinished;

  int get totalSeconds => hours * 3600 + minutes * 60 + seconds;

  Duration remainingAt(DateTime now) {
    final end = endsAt;
    if (!isRunning || end == null) return Duration(seconds: totalSeconds);
    final remaining = end.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  TimerUnits unitsAt(DateTime now) {
    final total = remainingAt(now).inSeconds;
    return TimerUnits(
      hours: total ~/ 3600,
      minutes: (total ~/ 60) % 60,
      seconds: total % 60,
    );
  }

  TimerState copyWith({
    int? hours,
    int? minutes,
    int? seconds,
    bool? isRunning,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? isFinished,
  }) {
    return TimerState(
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      isRunning: isRunning ?? this.isRunning,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
```

Create `lib/models/weather.dart`:

```dart
class WeatherRequest {
  const WeatherRequest({
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
  });

  final double latitude;
  final double longitude;
  final String locationLabel;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationLabel,
    required this.updatedAt,
    required this.currentTemp,
    required this.apparentTemp,
    required this.humidity,
    required this.windKmh,
    required this.currentCode,
    required this.currentDescription,
    required this.sourceLabel,
    required this.reportTimeLabel,
    this.forecastAvailable = true,
    this.days = const [],
  });

  final String locationLabel;
  final DateTime updatedAt;
  final int currentTemp;
  final int apparentTemp;
  final int humidity;
  final int windKmh;
  final int currentCode;
  final String currentDescription;
  final String sourceLabel;
  final String reportTimeLabel;
  final bool forecastAvailable;
  final List<WeatherDay> days;

  WeatherDay? get today => days.isEmpty ? null : days.first;
  WeatherDay? get tomorrow => days.length < 2 ? null : days[1];
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.code,
    required this.description,
    required this.high,
    required this.low,
    this.icon = '',
    this.precipitation = 0,
    this.uv = 0,
    this.windKmh = 0,
    this.windDirection,
    this.clothingTip,
    this.umbrellaTip,
    this.sportTip,
    this.travelTip,
    this.sunProtectionTip,
  });

  final String date;
  final int code;
  final String description;
  final String icon;
  final int high;
  final int low;
  final int precipitation;
  final int uv;
  final int windKmh;
  final String? windDirection;
  final String? clothingTip;
  final String? umbrellaTip;
  final String? sportTip;
  final String? travelTip;
  final String? sunProtectionTip;

  int get temperatureRange => (high - low).abs();
}
```

- [ ] **Step 4: Run tests**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\models
```

Expected: all model tests pass.

- [ ] **Step 5: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib/models test/models
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: add Flutter domain models"
```

---

### Task 3: Weather Sources, Parsing, And AI Advice

**Files:**
- Create: `lib/services/http_json_client.dart`
- Create: `lib/services/weather_source.dart`
- Create: `lib/services/weather_service.dart`
- Create: `lib/services/uapi_weather_source.dart`
- Create: `lib/services/open_meteo_weather_source.dart`
- Create: `lib/services/qweather_weather_source.dart`
- Create: `lib/services/ai_advice_service.dart`
- Create: `test/services/weather_service_test.dart`
- Create: `test/services/uapi_weather_source_test.dart`
- Create: `test/services/open_meteo_weather_source_test.dart`
- Create: `test/services/ai_advice_service_test.dart`

**Interfaces:**
- Consumes: `AppConfig`, `WeatherRequest`, `WeatherSnapshot`, `WeatherDay`
- Produces: `JsonHttpClient.getJson(Uri uri, {Map<String, String> headers = const {}})`
- Produces: `JsonHttpClient.postJson(Uri uri, Map<String, Object?> body, {Map<String, String> headers = const {}})`
- Produces: `abstract class WeatherSource`
- Produces: `WeatherService.fetchWeather(WeatherRequest request)`
- Produces: `AiAdviceService.applyAdvice(WeatherSnapshot snapshot)`

- [ ] **Step 1: Write fallback and parser tests**

Create `test/services/weather_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/weather_service.dart';
import 'package:home_info_clock/services/weather_source.dart';

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource(this.name, this.result);

  final String name;
  final Object result;
  bool called = false;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    called = true;
    if (result is Exception) throw result as Exception;
    return result as WeatherSnapshot;
  }
}

WeatherSnapshot snapshot(String source, {bool forecast = true, int dayCount = 2}) {
  return WeatherSnapshot(
    locationLabel: '上海',
    updatedAt: DateTime(2026, 7, 7, 9, 0),
    currentTemp: 30,
    apparentTemp: 32,
    humidity: 70,
    windKmh: 12,
    currentCode: 2,
    currentDescription: '多云',
    sourceLabel: source,
    reportTimeLabel: '09:00',
    forecastAvailable: forecast,
    days: List.generate(
      dayCount,
      (index) => WeatherDay(
        date: '2026-07-0${index + 7}',
        code: 2,
        description: '多云',
        high: 32,
        low: 26,
      ),
    ),
  );
}

void main() {
  const request = WeatherRequest(latitude: 31.2, longitude: 121.5, locationLabel: '上海');

  test('WeatherService uses UAPI when it has forecast data', () async {
    final uapi = FakeWeatherSource('uapi', snapshot('UAPI预报'));
    final openMeteo = FakeWeatherSource('open', snapshot('Open-Meteo'));
    final service = WeatherService(primary: uapi, fallback: openMeteo);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'UAPI预报');
    expect(openMeteo.called, isFalse);
  });

  test('WeatherService falls back when UAPI lacks forecast data', () async {
    final uapi = FakeWeatherSource('uapi', snapshot('UAPI实时', forecast: false, dayCount: 1));
    final openMeteo = FakeWeatherSource('open', snapshot('Open-Meteo'));
    final service = WeatherService(primary: uapi, fallback: openMeteo);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'Open-Meteo');
    expect(openMeteo.called, isTrue);
  });
}
```

Create `test/services/ai_advice_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/ai_advice_service.dart';

void main() {
  test('cleanAdvice trims newlines and caps length', () {
    final cleaned = AiAdviceService.cleanAdvice('  带轻便雨伞\n注意路滑  ');

    expect(cleaned, '带轻便雨伞 注意路滑。');
  });

  test('cleanAdvice returns null for empty text', () {
    expect(AiAdviceService.cleanAdvice('   '), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\services
```

Expected: failures mentioning missing service files or classes.

- [ ] **Step 3: Implement service interfaces**

Create `lib/services/weather_source.dart`:

```dart
import '../models/weather.dart';

abstract class WeatherSource {
  Future<WeatherSnapshot> fetch(WeatherRequest request);
}
```

Create `lib/services/weather_service.dart`:

```dart
import '../models/weather.dart';
import 'weather_source.dart';

class WeatherService {
  const WeatherService({
    required this.primary,
    required this.fallback,
    this.secondaryFallback,
  });

  final WeatherSource primary;
  final WeatherSource fallback;
  final WeatherSource? secondaryFallback;

  Future<WeatherSnapshot> fetchWeather(WeatherRequest request) async {
    try {
      final snapshot = await primary.fetch(request);
      if (snapshot.forecastAvailable && snapshot.days.length > 1) {
        return snapshot;
      }
    } catch (_) {
      // Fall through to the next source.
    }

    try {
      final snapshot = await fallback.fetch(request);
      if (snapshot.days.isNotEmpty) return snapshot;
    } catch (_) {
      // Fall through to optional source.
    }

    final last = secondaryFallback;
    if (last != null) return last.fetch(request);
    return fallback.fetch(request);
  }
}
```

Create `lib/services/http_json_client.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

class JsonHttpClient {
  const JsonHttpClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final client = _client ?? http.Client();
    final response = await client.get(uri, headers: {'Accept': 'application/json', ...headers});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GET ${uri.host}${uri.path} failed: HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const {},
  }) async {
    final client = _client ?? http.Client();
    final response = await client.post(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        ...headers,
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('POST ${uri.host}${uri.path} failed: HTTP ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
```

- [ ] **Step 4: Implement source parsers**

Create source classes with these constructors and methods:

```dart
class UapiWeatherSource implements WeatherSource {
  const UapiWeatherSource({required JsonHttpClient client, required AppConfig config});
  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request);
}

class OpenMeteoWeatherSource implements WeatherSource {
  const OpenMeteoWeatherSource({required JsonHttpClient client});
  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request);
}

class QWeatherWeatherSource implements WeatherSource {
  const QWeatherWeatherSource({required JsonHttpClient client, required AppConfig config});
  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request);
}
```

Use the native Java implementation under `legacy/native-android/app/src/main/java/com/homepanel/clock/MainActivity.java` as the behavior reference for:

- UAPI city candidate order.
- Weather code normalization.
- Open-Meteo daily field names.
- QWeather icon normalization.
- Local clothing, umbrella, and travel fallback advice.

- [ ] **Step 5: Implement AI advice cleanup and GPTsAPI request**

First add these copy helpers to `lib/models/weather.dart`.

For `WeatherSnapshot`:

```dart
WeatherSnapshot copyWith({
  String? locationLabel,
  DateTime? updatedAt,
  int? currentTemp,
  int? apparentTemp,
  int? humidity,
  int? windKmh,
  int? currentCode,
  String? currentDescription,
  String? sourceLabel,
  String? reportTimeLabel,
  bool? forecastAvailable,
  List<WeatherDay>? days,
}) {
  return WeatherSnapshot(
    locationLabel: locationLabel ?? this.locationLabel,
    updatedAt: updatedAt ?? this.updatedAt,
    currentTemp: currentTemp ?? this.currentTemp,
    apparentTemp: apparentTemp ?? this.apparentTemp,
    humidity: humidity ?? this.humidity,
    windKmh: windKmh ?? this.windKmh,
    currentCode: currentCode ?? this.currentCode,
    currentDescription: currentDescription ?? this.currentDescription,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    reportTimeLabel: reportTimeLabel ?? this.reportTimeLabel,
    forecastAvailable: forecastAvailable ?? this.forecastAvailable,
    days: days ?? this.days,
  );
}
```

For `WeatherDay`:

```dart
WeatherDay copyWith({
  String? date,
  int? code,
  String? description,
  String? icon,
  int? high,
  int? low,
  int? precipitation,
  int? uv,
  int? windKmh,
  String? windDirection,
  String? clothingTip,
  String? umbrellaTip,
  String? sportTip,
  String? travelTip,
  String? sunProtectionTip,
}) {
  return WeatherDay(
    date: date ?? this.date,
    code: code ?? this.code,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    high: high ?? this.high,
    low: low ?? this.low,
    precipitation: precipitation ?? this.precipitation,
    uv: uv ?? this.uv,
    windKmh: windKmh ?? this.windKmh,
    windDirection: windDirection ?? this.windDirection,
    clothingTip: clothingTip ?? this.clothingTip,
    umbrellaTip: umbrellaTip ?? this.umbrellaTip,
    sportTip: sportTip ?? this.sportTip,
    travelTip: travelTip ?? this.travelTip,
    sunProtectionTip: sunProtectionTip ?? this.sunProtectionTip,
  );
}
```

Then create `lib/services/ai_advice_service.dart`:

```dart
import 'dart:convert';

import '../models/app_config.dart';
import '../models/weather.dart';
import 'http_json_client.dart';

class AiAdviceService {
  const AiAdviceService({required this.client, required this.config});

  final JsonHttpClient client;
  final AppConfig config;

  Uri get chatUri {
    var baseUrl = config.gptsApiBaseUrl.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return Uri.parse('$baseUrl/chat/completions');
  }

  static String? cleanAdvice(String? value) {
    final cleaned = value?.trim().replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (cleaned == null || cleaned.isEmpty) return null;
    final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    final capped = compact.length > 24 ? compact.substring(0, 24) : compact;
    return capped.endsWith('。') ? capped : '$capped。';
  }

  Future<WeatherSnapshot> applyAdvice(WeatherSnapshot snapshot) async {
    if (!config.hasGptsApiKey || snapshot.tomorrow == null) return snapshot;
    final tomorrow = snapshot.tomorrow!;
    final weather = <String, Object?>{
      'location': snapshot.locationLabel,
      'date': tomorrow.date,
      'condition': tomorrow.description,
      'high_celsius': tomorrow.high,
      'low_celsius': tomorrow.low,
      'precipitation_probability_percent': tomorrow.precipitation,
      'uv_index': tomorrow.uv,
      'wind_kmh': tomorrow.windKmh,
      'wind_direction': tomorrow.windDirection ?? '',
    };

    try {
      final response = await client.postJson(
        chatUri,
        <String, Object?>{
          'model': config.gptsApiModel,
          'messages': [
            {
              'role': 'system',
              'content': '你是家庭信息屏的天气生活建议助手。只输出严格 JSON，不要 Markdown。字段必须是 clothing、umbrella、travel。每条最多 8 个汉字，只写一句具体建议，不要解释。',
            },
            {
              'role': 'user',
              'content': '请基于明日天气给出穿衣、带伞、出行三条建议。天气数据：${jsonEncode(weather)}',
            },
          ],
          'max_tokens': 120,
        },
        headers: {'Authorization': 'Bearer ${config.gptsApiKey.trim()}'},
      );

      final choices = response['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return snapshot;
      final message = (choices.first as Map<String, dynamic>)['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String? ?? '';
      final advice = jsonDecode(_extractJsonObject(content)) as Map<String, dynamic>;

      final clothing = cleanAdvice(advice['clothing'] as String?);
      final umbrella = cleanAdvice(advice['umbrella'] as String?);
      final travel = cleanAdvice(advice['travel'] as String?);
      var updatedTomorrow = tomorrow;
      var applied = false;

      if (clothing != null) {
        updatedTomorrow = updatedTomorrow.copyWith(clothingTip: clothing);
        applied = true;
      }
      if (umbrella != null) {
        updatedTomorrow = updatedTomorrow.copyWith(umbrellaTip: umbrella);
        applied = true;
      }
      if (travel != null) {
        updatedTomorrow = updatedTomorrow.copyWith(travelTip: travel);
        applied = true;
      }

      if (!applied) return snapshot;
      final days = [...snapshot.days];
      days[1] = updatedTomorrow;
      return snapshot.copyWith(days: days, sourceLabel: _appendSource(snapshot.sourceLabel, 'AI建议'));
    } catch (_) {
      return snapshot;
    }
  }

  static String _extractJsonObject(String content) {
    final value = content.trim();
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return value.substring(start, end + 1);
    }
    return value;
  }

  static String _appendSource(String current, String addition) {
    if (current.trim().isEmpty) return addition;
    if (current.contains(addition)) return current;
    return '$current+$addition';
  }
}
```

- [ ] **Step 6: Run tests**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\services
```

Expected: all service tests pass.

- [ ] **Step 7: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib/services test/services
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: add weather service layer"
```

---

### Task 4: Cache Service And Android Platform Service

**Files:**
- Create: `lib/services/cache_service.dart`
- Create: `lib/services/platform_service.dart`
- Create: `test/services/cache_service_test.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt`

**Interfaces:**
- Produces: `CacheService.saveWeather(WeatherSnapshot snapshot)`
- Produces: `CacheService.loadWeather()`
- Produces: `CacheService.saveTimer(TimerState state)`
- Produces: `CacheService.loadTimer()`
- Produces: `PlatformService.enterKioskMode()`
- Produces: `PlatformService.openBilibili()`

- [ ] **Step 1: Write cache tests**

Create `test/services/cache_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CacheService round trips timer state', () async {
    final cache = CacheService(await SharedPreferences.getInstance());
    final state = TimerState.runningUntil(DateTime(2026, 7, 7, 9, 5));

    await cache.saveTimer(state);
    final restored = cache.loadTimer();

    expect(restored.isRunning, isTrue);
    expect(restored.endsAt, DateTime(2026, 7, 7, 9, 5));
  });

  test('CacheService round trips weather snapshot', () async {
    final cache = CacheService(await SharedPreferences.getInstance());
    final snapshot = WeatherSnapshot(
      locationLabel: '上海',
      updatedAt: DateTime(2026, 7, 7, 9, 0),
      currentTemp: 30,
      apparentTemp: 33,
      humidity: 70,
      windKmh: 12,
      currentCode: 2,
      currentDescription: '多云',
      sourceLabel: 'UAPI预报',
      reportTimeLabel: '09:00',
      days: const [
        WeatherDay(date: '2026-07-07', code: 2, description: '多云', high: 33, low: 27),
      ],
    );

    await cache.saveWeather(snapshot);
    final restored = cache.loadWeather();

    expect(restored?.locationLabel, '上海');
    expect(restored?.today?.high, 33);
  });
}
```

- [ ] **Step 2: Run cache test to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\services\cache_service_test.dart
```

Expected: failure mentioning missing `CacheService`.

- [ ] **Step 3: Implement JSON helpers and cache service**

Add `toJson` and `fromJson` methods to `TimerState`, `WeatherSnapshot`, and `WeatherDay`. Then create `lib/services/cache_service.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/timer_state.dart';
import '../models/weather.dart';

class CacheService {
  const CacheService(this.preferences);

  static const _weatherKey = 'weather_json';
  static const _timerKey = 'timer_json';

  final SharedPreferences preferences;

  Future<void> saveWeather(WeatherSnapshot snapshot) {
    return preferences.setString(_weatherKey, jsonEncode(snapshot.toJson()));
  }

  WeatherSnapshot? loadWeather() {
    final raw = preferences.getString(_weatherKey);
    if (raw == null || raw.isEmpty) return null;
    return WeatherSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTimer(TimerState state) {
    return preferences.setString(_timerKey, jsonEncode(state.toJson()));
  }

  TimerState loadTimer() {
    final raw = preferences.getString(_timerKey);
    if (raw == null || raw.isEmpty) return const TimerState();
    return TimerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
```

- [ ] **Step 4: Implement Flutter platform wrapper**

Create `lib/services/platform_service.dart`:

```dart
import 'package:flutter/services.dart';

class PlatformService {
  const PlatformService({MethodChannel channel = const MethodChannel('home_info_clock/platform')})
      : _channel = channel;

  final MethodChannel _channel;

  Future<void> enterKioskMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _channel.invokeMethod<void>('enterKioskMode');
  }

  Future<bool> openBilibili() async {
    return await _channel.invokeMethod<bool>('openBilibili') ?? false;
  }
}
```

- [ ] **Step 5: Add Android permissions**

Edit `android/app/src/main/AndroidManifest.xml` to include:

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />
```

Set the activity attributes:

```xml
android:configChanges="keyboardHidden|orientation|screenSize"
android:exported="true"
android:launchMode="singleTask"
android:screenOrientation="landscape"
```

- [ ] **Step 6: Add Android method channel**

Replace `android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt` with:

```kotlin
package com.homepanel.clock

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "home_info_clock/platform"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        enterKioskMode()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterKioskMode" -> {
                    enterKioskMode()
                    result.success(null)
                }
                "openBilibili" -> result.success(openBilibili())
                else -> result.notImplemented()
            }
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterKioskMode()
    }

    private fun enterKioskMode() {
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    private fun openBilibili(): Boolean {
        val packages = arrayOf("tv.danmaku.bili", "com.bilibili.app.in", "com.bilibili.app.blue")
        for (packageName in packages) {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                return true
            }
        }
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("bilibili://home")))
            true
        } catch (_: Exception) {
            false
        }
    }
}
```

- [ ] **Step 7: Run tests and build compile check**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\services\cache_service_test.dart
D:\test\flutter\bin\flutter.bat analyze
```

Expected: tests pass; analyze has no issues.

- [ ] **Step 8: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib/services/cache_service.dart lib/services/platform_service.dart lib/models test/services android/app
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: add cache and platform services"
```

---

### Task 5: Home And Timer Controllers

**Files:**
- Create: `lib/state/home_controller.dart`
- Create: `lib/state/timer_controller.dart`
- Create: `test/state/home_controller_test.dart`
- Create: `test/state/timer_controller_test.dart`

**Interfaces:**
- Consumes: `WeatherService`, `AiAdviceService`, `CacheService`, `PlatformService`
- Produces: `HomeController.initialize()`
- Produces: `HomeController.refreshWeather({bool force = false})`
- Produces: `HomeController.toggleSimpleMode()`
- Produces: `TimerController.setUnit(TimerUnit unit, int value)`
- Produces: `TimerController.startOrClear(DateTime now)`
- Produces: `TimerController.dismissFinished()`

- [ ] **Step 1: Write controller tests**

Create `test/state/timer_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/state/timer_controller.dart';

void main() {
  test('TimerController starts and finishes from wall clock', () {
    final controller = TimerController(initial: const TimerState(minutes: 1));
    final now = DateTime(2026, 7, 7, 9, 0);

    controller.startOrClear(now);

    expect(controller.state.isRunning, isTrue);
    expect(controller.state.endsAt, now.add(const Duration(minutes: 1)));

    controller.sync(now.add(const Duration(minutes: 2)));

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.isFinished, isTrue);
  });
}
```

Create `test/state/home_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/state/home_controller.dart';

void main() {
  test('HomeController toggles simple mode', () {
    final controller = HomeController.preview();

    expect(controller.isSimpleMode, isFalse);
    controller.toggleSimpleMode();
    expect(controller.isSimpleMode, isTrue);
  });
}
```

- [ ] **Step 2: Run controller tests to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\state
```

Expected: failures mentioning missing controller files or classes.

- [ ] **Step 3: Implement timer controller**

Create `lib/state/timer_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/timer_state.dart';

enum TimerUnit { hours, minutes, seconds }

class TimerController extends ChangeNotifier {
  TimerController({TimerState initial = const TimerState()}) : _state = initial;

  TimerState _state;

  TimerState get state => _state;

  void setUnit(TimerUnit unit, int value) {
    final clamped = switch (unit) {
      TimerUnit.hours => value.clamp(0, 11),
      TimerUnit.minutes => value.clamp(0, 59),
      TimerUnit.seconds => value.clamp(0, 59),
    };
    _state = switch (unit) {
      TimerUnit.hours => _state.copyWith(hours: clamped),
      TimerUnit.minutes => _state.copyWith(minutes: clamped),
      TimerUnit.seconds => _state.copyWith(seconds: clamped),
    };
    notifyListeners();
  }

  void startOrClear(DateTime now) {
    if (_state.isRunning) {
      _state = const TimerState();
    } else if (_state.totalSeconds > 0) {
      _state = TimerState.runningUntil(now.add(Duration(seconds: _state.totalSeconds)));
    }
    notifyListeners();
  }

  void sync(DateTime now) {
    if (!_state.isRunning) return;
    if (_state.remainingAt(now) == Duration.zero) {
      _state = const TimerState(isFinished: true);
      notifyListeners();
    }
  }

  void dismissFinished() {
    _state = _state.copyWith(isFinished: false);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Implement home controller preview state**

Create `lib/state/home_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    WeatherSnapshot? initialWeather,
    BatteryStatus initialBattery = const BatteryStatus.unavailable(),
  })  : _weather = initialWeather,
        _battery = initialBattery;

  factory HomeController.preview() => HomeController(
        initialWeather: WeatherSnapshot(
          locationLabel: '上海 浦东',
          updatedAt: DateTime(2026, 7, 7, 9, 0),
          currentTemp: 31,
          apparentTemp: 34,
          humidity: 72,
          windKmh: 12,
          currentCode: 2,
          currentDescription: '多云',
          sourceLabel: '预览',
          reportTimeLabel: '09:00',
          days: const [
            WeatherDay(date: '2026-07-07', code: 2, description: '多云', high: 33, low: 27),
            WeatherDay(
              date: '2026-07-08',
              code: 61,
              description: '小雨',
              high: 31,
              low: 26,
              precipitation: 65,
              uv: 6,
              windKmh: 18,
              clothingTip: '轻薄短袖即可。',
              umbrellaTip: '出门带伞更稳。',
              travelTip: '错峰出行更好。',
            ),
          ],
        ),
        initialBattery: const BatteryStatus(level: 86, isCharging: true),
      );

  WeatherSnapshot? _weather;
  BatteryStatus _battery;
  bool _isSimpleMode = false;

  WeatherSnapshot? get weather => _weather;
  BatteryStatus get battery => _battery;
  bool get isSimpleMode => _isSimpleMode;

  void toggleSimpleMode() {
    _isSimpleMode = !_isSimpleMode;
    notifyListeners();
  }

  void setWeather(WeatherSnapshot snapshot) {
    _weather = snapshot;
    notifyListeners();
  }

  void setBattery(BatteryStatus status) {
    _battery = status;
    notifyListeners();
  }
}
```

- [ ] **Step 5: Run tests**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\state
```

Expected: all controller tests pass.

- [ ] **Step 6: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib/state test/state
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: add app state controllers"
```

---

### Task 6: Flutter-First Dashboard Widgets

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Create: `lib/screens/home_clock_screen.dart`
- Create: `lib/widgets/weather_panel.dart`
- Create: `lib/widgets/clock_panel.dart`
- Create: `lib/widgets/tomorrow_panel.dart`
- Create: `lib/widgets/timer_panel.dart`
- Create: `lib/widgets/quick_actions_panel.dart`
- Create: `lib/widgets/simple_mode_view.dart`
- Create: `lib/widgets/metric_cell.dart`
- Create: `test/widgets/home_clock_screen_test.dart`

**Interfaces:**
- Consumes: `HomeController`, `TimerController`
- Produces: `HomeClockScreen`
- Produces: `WeatherPanel`, `ClockPanel`, `TomorrowPanel`, `TimerPanel`, `QuickActionsPanel`, `SimpleModeView`

- [ ] **Step 1: Write widget smoke tests**

Create `test/widgets/home_clock_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';

void main() {
  testWidgets('HomeClockScreen renders the three dashboard regions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    expect(find.text('上海 浦东'), findsOneWidget);
    expect(find.text('Bilibili'), findsOneWidget);
    expect(find.textContaining('小雨'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run widget test to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\widgets\home_clock_screen_test.dart
```

Expected: failure mentioning missing `HomeClockScreen`.

- [ ] **Step 3: Implement layout shell**

Create `lib/screens/home_clock_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../state/home_controller.dart';
import '../state/timer_controller.dart';
import '../widgets/clock_panel.dart';
import '../widgets/quick_actions_panel.dart';
import '../widgets/simple_mode_view.dart';
import '../widgets/timer_panel.dart';
import '../widgets/tomorrow_panel.dart';
import '../widgets/weather_panel.dart';

class HomeClockScreen extends StatelessWidget {
  const HomeClockScreen({
    super.key,
    required this.homeController,
    required this.timerController,
  });

  final HomeController homeController;
  final TimerController timerController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([homeController, timerController]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF061016),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: homeController.isSimpleMode
                  ? SimpleModeView(
                      key: const ValueKey('simple'),
                      weather: homeController.weather,
                      onToggleMode: homeController.toggleSimpleMode,
                    )
                  : _FullDashboard(
                      key: const ValueKey('full'),
                      homeController: homeController,
                      timerController: timerController,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _FullDashboard extends StatelessWidget {
  const _FullDashboard({
    super.key,
    required this.homeController,
    required this.timerController,
  });

  final HomeController homeController;
  final TimerController timerController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = width.clamp(900, 1600) * 0.27;
        final right = width.clamp(900, 1600) * 0.31;
        return Row(
          children: [
            SizedBox(
              width: left.clamp(220, 360),
              child: WeatherPanel(weather: homeController.weather, battery: homeController.battery),
            ),
            const _Separator(),
            Expanded(
              child: PageView(
                children: [
                  ClockPanel(onToggleMode: homeController.toggleSimpleMode),
                  TimerPanel(controller: timerController),
                ],
              ),
            ),
            const _Separator(),
            SizedBox(
              width: right.clamp(250, 410),
              child: PageView(
                children: [
                  TomorrowPanel(weather: homeController.weather),
                  const QuickActionsPanel(),
                  const Center(child: Text('预留页')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: Colors.white.withOpacity(0.13));
  }
}
```

- [ ] **Step 4: Implement reusable panels with Flutter layout primitives**

Create the widget files with small stateless widgets. Use `Padding`, `Column`, `Row`, `Expanded`, `AspectRatio`, `FittedBox`, and `PageView`. Do not use absolute coordinates for panel layout.

Minimum text required by tests:

```dart
Text(weather?.locationLabel ?? '等待定位')
Text(weather?.currentDescription ?? '等待天气')
Text('Bilibili')
Text(weather?.tomorrow?.description ?? '等待天气数据')
```

- [ ] **Step 5: Wire app entry to controllers**

Update `lib/app.dart` so `home` is:

```dart
HomeClockScreen(
  homeController: HomeController.preview(),
  timerController: TimerController(),
)
```

Keep the preview controller only until Task 8 wires live services.

- [ ] **Step 6: Run widget test and analyze**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\widgets\home_clock_screen_test.dart
D:\test\flutter\bin\flutter.bat analyze
```

Expected: widget test passes; analyze has no issues.

- [ ] **Step 7: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib test/widgets
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: compose Flutter dashboard layout"
```

---

### Task 7: Focused Painters, Timer UI, And Panel Interactions

**Files:**
- Create: `lib/painters/analog_clock_painter.dart`
- Create: `lib/painters/weather_icon_painter.dart`
- Create: `lib/painters/timer_painter.dart`
- Modify: `lib/widgets/clock_panel.dart`
- Modify: `lib/widgets/weather_panel.dart`
- Modify: `lib/widgets/timer_panel.dart`
- Modify: `lib/widgets/tomorrow_panel.dart`
- Create: `test/widgets/timer_panel_test.dart`

**Interfaces:**
- Produces: `AnalogClockPainter(DateTime time)`
- Produces: `WeatherIconPainter(int code, Color accent)`
- Produces: `TimerPainter(TimerState state, DateTime now)`
- Produces: timer controls that call `TimerController.setUnit` and `TimerController.startOrClear`

- [ ] **Step 1: Write timer panel test**

Create `test/widgets/timer_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/timer_panel.dart';

void main() {
  testWidgets('TimerPanel changes minute value and starts', (tester) async {
    final controller = TimerController();

    await tester.pumpWidget(MaterialApp(home: TimerPanel(controller: controller)));

    await tester.tap(find.byKey(const ValueKey('timer-minute-plus')));
    await tester.pump();
    expect(controller.state.minutes, 1);

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();
    expect(controller.state.isRunning, isTrue);
  });
}
```

- [ ] **Step 2: Run timer panel test to verify failure**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\widgets\timer_panel_test.dart
```

Expected: failure until `TimerPanel` exposes the expected keys.

- [ ] **Step 3: Implement analog clock painter**

Create `lib/painters/analog_clock_painter.dart` with this public API:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnalogClockPainter extends CustomPainter {
  const AnalogClockPainter(this.time);

  final DateTime time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()..isAntiAlias = true;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..color = const Color(0xFFE8F1EC);
    canvas.drawCircle(center, radius * 0.92, paint);

    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + i * math.pi / 6;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.72;
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.82;
      paint.strokeWidth = i % 3 == 0 ? radius * 0.018 : radius * 0.01;
      canvas.drawLine(start, end, paint);
    }

    _hand(canvas, center, radius * 0.48, ((time.hour % 12) + time.minute / 60) * 30, radius * 0.035, Colors.white);
    _hand(canvas, center, radius * 0.66, (time.minute + time.second / 60) * 6, radius * 0.022, const Color(0xFF64DCCD));
    _hand(canvas, center, radius * 0.72, time.second * 6, radius * 0.009, const Color(0xFFFFCD5E));
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFCD5E);
    canvas.drawCircle(center, radius * 0.045, paint);
  }

  void _hand(Canvas canvas, Offset center, double length, double degrees, double stroke, Color color) {
    final angle = -math.pi / 2 + degrees * math.pi / 180;
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawLine(center, center + Offset(math.cos(angle), math.sin(angle)) * length, paint);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) => oldDelegate.time.second != time.second;
}
```

- [ ] **Step 4: Implement timer panel controls**

In `lib/widgets/timer_panel.dart`, expose buttons with keys:

```dart
const ValueKey('timer-hour-plus')
const ValueKey('timer-minute-plus')
const ValueKey('timer-second-plus')
const ValueKey('timer-start')
```

Each button calls the matching `TimerController` method. Use `AnimatedBuilder` around the controller.

- [ ] **Step 5: Implement weather and timer painters**

Create `WeatherIconPainter` and `TimerPainter` with the APIs in this task. Keep each painter under 200 lines. Use them inside widgets through `CustomPaint` with stable `AspectRatio` containers.

- [ ] **Step 6: Run interaction tests**

Run:

```powershell
D:\test\flutter\bin\flutter.bat test test\widgets
D:\test\flutter\bin\flutter.bat analyze
```

Expected: all widget tests pass; analyze has no issues.

- [ ] **Step 7: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib/painters lib/widgets test/widgets
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: add focused painters and timer interactions"
```

---

### Task 8: Live App Wiring, Documentation, And Verification

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Modify: `lib/state/home_controller.dart`
- Modify: `lib/services/platform_service.dart`
- Modify: `README.md`
- Create: `docs/FLUTTER_APP.md`

**Interfaces:**
- Consumes: all prior services and controllers
- Produces: startup flow that enters kiosk mode, restores cache, reads battery, requests location, fetches weather, and renders cached state while refreshing

- [ ] **Step 1: Wire live app services**

Update `lib/main.dart` to initialize Flutter bindings, enter kiosk mode, create shared preferences, and pass services into the app:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'models/app_config.dart';
import 'services/cache_service.dart';
import 'services/http_json_client.dart';
import 'services/platform_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const platform = PlatformService();
  await platform.enterKioskMode();
  final preferences = await SharedPreferences.getInstance();

  runApp(
    HomeInfoClockApp(
      config: AppConfig.fromEnvironment(),
      cache: CacheService(preferences),
      httpClient: const JsonHttpClient(),
      platform: platform,
    ),
  );
}
```

Adjust `HomeInfoClockApp` constructor to receive these dependencies and create `HomeController` from them.

- [ ] **Step 2: Complete live controller behavior**

Extend `HomeController` with:

```dart
Future<void> initialize()
Future<void> refreshWeather({bool force = false})
Future<void> openBilibili()
```

`initialize()` must:

1. Load cached weather and timer state.
2. Start battery subscription.
3. Request location permission.
4. Resolve location label.
5. Fetch weather when cache is missing or older than 30 minutes.

- [ ] **Step 3: Update docs**

Create `docs/FLUTTER_APP.md` with:

````markdown
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
````

Update `README.md` so it states the app is now Flutter-based and points old native Android reference code to `legacy/native-android/`.

- [ ] **Step 4: Run full verification**

Run:

```powershell
D:\test\flutter\bin\flutter.bat pub get
D:\test\flutter\bin\flutter.bat analyze
D:\test\flutter\bin\flutter.bat test
D:\test\flutter\bin\flutter.bat build apk --debug
```

Expected:

- `flutter pub get`: `Got dependencies!`
- `flutter analyze`: `No issues found!`
- `flutter test`: all tests pass
- `flutter build apk --debug`: writes `build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 5: Commit**

Run:

```powershell
git -c safe.directory=D:/test/Home_Info_Clock add lib README.md docs/FLUTTER_APP.md pubspec.yaml pubspec.lock android test
git -c safe.directory=D:/test/Home_Info_Clock commit -m "feat: wire Flutter clock app"
```
