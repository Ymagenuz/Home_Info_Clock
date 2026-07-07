# Home Info Clock Flutter Rebuild Design

Date: 2026-07-07

## Goal

Rebuild Home Info Clock as a Flutter application inside the existing repository at `D:\test\Home_Info_Clock`, using the Flutter SDK at `D:\test\flutter\bin\flutter.bat`.

The Flutter version should preserve the current Android kiosk experience: landscape full screen, always-on display, three-column information layout, local weather, battery state, analog clock, tomorrow advice, swipeable panels, timer, simple mode, and the Bilibili shortcut.

## Current Context

The existing app is a native Android project:

- `app/src/main/java/com/homepanel/clock/MainActivity.java` handles permissions, location, battery, weather requests, cached weather, QWeather JWT, GPTsAPI advice, and app launching.
- `app/src/main/java/com/homepanel/clock/HomePanelView.java` is a large custom `View` that owns rendering, touch handling, animations, timer state, weather paging, simple mode, and custom weather/clock drawing.
- `web/` contains an older browser version and remains useful as visual reference only.
- The current repository root has Android Gradle files (`build.gradle`, `settings.gradle`) and an `app/` module. A Flutter project will instead use `pubspec.yaml`, `lib/`, and `android/app/`.

The rebuild should avoid a line-by-line port of `HomePanelView.java`. The main value of moving to Flutter is to separate platform services, app state, widgets, and custom painters.

## Recommended Approach

Use a full Flutter rebuild with structured feature parity.

The native Android implementation will be preserved as migration reference under `legacy/native-android/` before creating the Flutter structure. The resulting repo should be recognizable as a Flutter project at the root, while old Java sources remain available for comparison.

### Why This Approach

- It keeps the user's confirmed target: one Flutter app in the current repository.
- It prevents the old root Android Gradle project from competing with the Flutter Android project.
- It keeps behavior stable by porting features deliberately rather than rewriting the visual system from memory.
- It creates smaller files and clearer boundaries than the current monolithic custom view.

## Alternatives Considered

### Minimal Flutter Shell

Create a Flutter app that only reproduces the main clock and weather screen, then port remaining features later.

Trade-off: fastest first APK, but high chance of losing current useful kiosk behavior such as timer, pull-to-refresh, simple mode, and cached weather.

### Hybrid Flutter With Native Java Reuse

Embed the existing Java `HomePanelView` or platform code behind Flutter.

Trade-off: lower short-term rewrite cost, but it keeps the hardest-to-maintain part of the current app and weakens the reason to move to Flutter.

### Full Rebuild With Feature Parity

Rebuild the app in Flutter, reuse the Java code as behavior reference, and keep platform-only concerns behind Flutter services or method channels.

Trade-off: more implementation work up front, but produces the cleanest long-term codebase. This is the recommended approach.

## Architecture

The Flutter app will use a lightweight layered structure:

```text
lib/
  main.dart
  app.dart
  models/
    weather.dart
    battery_status.dart
    timer_state.dart
  services/
    weather_service.dart
    uapi_weather_source.dart
    open_meteo_weather_source.dart
    qweather_weather_source.dart
    ai_advice_service.dart
    platform_service.dart
    cache_service.dart
  state/
    home_controller.dart
    timer_controller.dart
  screens/
    home_clock_screen.dart
  widgets/
    weather_panel.dart
    clock_panel.dart
    tomorrow_panel.dart
    timer_panel.dart
    quick_actions_panel.dart
    simple_mode_view.dart
  painters/
    analog_clock_painter.dart
    weather_icon_painter.dart
    timer_painter.dart
```

`HomeController` coordinates location, weather refresh, battery updates, current time ticks, simple mode, and panel pages. `TimerController` owns timer persistence and countdown behavior.

The UI will prefer normal Flutter widgets for layout and text, with `CustomPainter` used for the analog clock, colored weather icons, metric rings, and timer rings.

## Flutter Project Layout

The repository root will become the Flutter app root. The implementation plan should:

1. Preserve the existing native Android implementation under `legacy/native-android/`.
2. Create a Flutter project at `D:\test\Home_Info_Clock`.
3. Keep `docs/`, `README.md`, and existing screenshots unless they need targeted updates.
4. Use Flutter's generated `android/` folder as the active Android host project.

Expected active Flutter files include:

- `pubspec.yaml`
- `lib/`
- `test/`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/.../MainActivity.kt` or Java equivalent when a method channel is needed.

## Platform Behavior

The app targets Android kiosk use first.

Required platform behavior:

- Force landscape orientation.
- Enter immersive sticky full-screen mode.
- Keep screen awake.
- Request fine and coarse location permissions.
- Read current location and reverse geocode when available.
- Read battery level and charging state.
- Open Bilibili by package name or deep link.
- Store local settings and cached weather.

Use Flutter plugins where they are stable and simple. Use an Android method channel for behavior that is easier or more reliable in native code, especially opening Bilibili and precise immersive mode handling.

## Configuration

The Flutter version should continue to support local secrets without committing them.

Configuration values:

- `UAPI_TOKEN`
- `GPTSAPI_API_KEY`
- `GPTSAPI_BASE_URL`, default `https://api.gptsapi.net/v1`
- `GPTSAPI_MODEL`, default `gpt-5.4-nano`
- `QWEATHER_API_HOST`
- `QWEATHER_API_KEY`
- `QWEATHER_JWT_PROJECT_ID`
- `QWEATHER_JWT_KEY_ID`
- `QWEATHER_JWT_PRIVATE_KEY` or local private key file support

For Flutter, these values should be read through `--dart-define` or an ignored local configuration file generated for development. Secrets must remain out of Git.

## Data Flow

Startup flow:

1. Start the Flutter app in landscape immersive mode.
2. Restore cached weather and timer state.
3. Subscribe to battery changes.
4. Request location permission if needed.
5. Resolve the best available location.
6. Fetch weather if cache is stale or missing.
7. Update UI state and persist successful weather results.

Weather flow:

1. Try UAPI by city/district label.
2. If UAPI lacks usable forecast data, enhance or fall back to Open-Meteo.
3. If UAPI/Open-Meteo are unavailable and QWeather is configured, use QWeather.
4. Generate local fallback tips for clothing, umbrella, and travel.
5. If GPTsAPI is configured, attempt to rewrite the three tomorrow tips.
6. On AI failure, keep the weather-source or local fallback tips.

Timer flow:

1. Restore saved timer values and running end time.
2. Allow the user to set hours, minutes, and seconds.
3. Persist changes immediately.
4. When running, calculate remaining time from wall-clock end time.
5. When complete, show the finished overlay until dismissed.

## UI Design

The full mode remains a dense, landscape-first dashboard:

- Left panel: location, update status, current weather, today's trend, battery state, refresh gesture.
- Center panel: analog clock, digital time, date, and a second page for timer.
- Right panel: tomorrow weather metrics, lifestyle tips, Bilibili shortcut page, and a reserved page.

Simple mode remains a cleaner two-column view:

- Large clock and date.
- Compact tomorrow weather and tips.

Visual language:

- Dark full-screen background.
- Thin separators between columns.
- Rounded controls at 8 px radius or less.
- Teal and warm yellow accents retained from the current app.
- Text sizes scale from layout constraints, not viewport-width formulas.
- No marketing landing page and no instructional overlay as the first screen.

## Interactions

The Flutter app should preserve the current interaction model:

- Horizontal swipe left panel between current weather and trend.
- Vertical scroll or drag on the weather trend page when needed.
- Pull down on weather panels to refresh.
- Horizontal swipe center panel between clock and timer.
- Horizontal swipe right panel between tomorrow, quick actions, and reserved page.
- Tap or double-tap center clock area to toggle simple mode, matching current behavior as closely as practical.
- Timer setting interaction can be rebuilt with Flutter gestures but should preserve the same intent: fast touch adjustment of hour, minute, and second values.

## Error Handling

The app should remain useful when services fail:

- No location permission: show a clear waiting or permission-missing state instead of a blank panel.
- No weather cache and no network: show weather unavailable status.
- Stale weather cache: render cached weather and mark update status.
- UAPI failure: attempt Open-Meteo, then QWeather if configured.
- QWeather credential missing: do not show a credential error unless QWeather is the only available path.
- GPTsAPI failure: keep non-AI tips and omit the AI source label.
- Battery unavailable: show battery unknown without crashing.
- Bilibili unavailable: show a short toast or snack message.

## Testing And Verification

The implementation should include:

- Dart unit tests for weather parsing, source fallback decisions, AI advice cleanup, and timer countdown math.
- Widget tests for key panels rendering loading, cached, success, and error states.
- `flutter analyze`.
- `flutter test`.
- Android debug build with `flutter build apk --debug`.

Visual verification should include at least one desktop-sized Flutter widget or emulator/screenshot check after implementation. Device screenshots may be useful, but the existing project notes say to ask the user before taking screenshots from the connected phone.

## Migration Scope

In scope:

- Flutter app scaffold in current repository.
- Feature-parity UI for the current kiosk screen.
- Weather, battery, location, cache, timer, Bilibili shortcut, immersive landscape mode.
- README and Android build documentation updates.

Out of scope for this rebuild:

- Public backend for secrets.
- New calendar, Home Assistant, camera, or NAS integrations.
- Publishing pipeline or store release setup.
- Redesigning the product into a general mobile app.

## Acceptance Criteria

The rebuild is complete when:

- The repository root is a working Flutter app using `D:\test\flutter\bin\flutter.bat`.
- The Android debug APK builds.
- The app opens directly into the landscape information clock.
- The main panels, simple mode, timer, and tomorrow advice render without overlap on landscape phone/tablet sizes.
- Location, battery, weather cache, weather refresh, and Bilibili shortcut have working Flutter implementations or clearly documented platform fallbacks.
- Tests and analysis pass, or any remaining environment-specific blocker is documented with exact command output.
