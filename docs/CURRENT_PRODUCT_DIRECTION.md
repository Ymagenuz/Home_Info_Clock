# Home Info Clock Current Product Direction

Updated: 2026-07-11

This document is the current product-requirements entry point. It supersedes
conflicting requirements in the original Flutter rebuild design and plan,
which remain in the repository as implementation history.

## Current Status

- The Flutter project is a working technical baseline: analysis and tests pass,
  a debug APK builds, and that APK has been installed and launched over ADB.
- The current APK has not passed product acceptance. Its UI and interactions
  differ substantially from the intended design and are only barely usable.
- Do not describe the Flutter rebuild as complete based only on green tests or
  a successful APK build.

## Next Product Objective

The next work session starts a user-visible UI and interaction optimization
pass. Before changing each area, compare the Flutter implementation with the
preserved native Java implementation under `legacy/native-android/`, especially:

- `app/src/main/java/com/homepanel/clock/HomePanelView.java`
- `app/src/main/java/com/homepanel/clock/MainActivity.java`

The Java app is the behavioral and visual reference. Flutter should still use
idiomatic widgets and focused painters rather than copying the monolithic Java
implementation line by line.

Work in small, testable, device-visible iterations. A change is accepted only
after the user can install or ADB-run the APK and evaluate the actual behavior.

## Current Product Requirements

### Core App

- Android landscape information-clock/kiosk experience.
- Clock, weather, tomorrow advice, battery, timer, simple mode, paging, and the
  Bilibili shortcut remain product features.
- Production weather remains UAPI primary with Open-Meteo fallback.
- Historical QWeather files may remain, but QWeather is not a production
  weather path.

### Manual Location

Automatic device positioning is no longer the desired product behavior. The
location workflow should be a small manual-selection feature:

- Use one location entry at the place currently showing the waiting-for-location
  placeholder or the selected location name.
- Do not force a location dialog to open on first launch.
- In the location dialog, provide an offline China quick selector with three
  vertical wheels: province, city, and district.
- The China selector covers 34 province-level divisions, including Hong Kong,
  Macao, and Taiwan. It is a convenience path, not a restriction on supported
  locations.
- In the same dialog, provide a text field for arbitrary locations worldwide.
- Use the already configured AI API to parse free-form location text.
- Save the last confirmed location and use it directly on the next app launch.
- Keep this feature proportionate. It does not require a separate SDD cycle or
  a large location subsystem.

### UI And Interaction

- The existing Flutter layout is not the accepted final design.
- Relearn panel proportions, information hierarchy, gestures, paging, timer
  behavior, simple mode, typography, spacing, and touch targets from the Java
  reference and the user's device feedback.
- Do not preserve a Flutter behavior merely because it is already tested when
  it conflicts with the intended interaction.

## Working Constraints

- Keep secrets out of Git. UAPI and optional GPTsAPI values continue to use
  `--dart-define` or other local configuration.
- Ask the user before taking a screenshot from a connected device.
- Preserve UAPI primary plus Open-Meteo fallback unless the user changes that
  requirement explicitly.
- Use a workflow proportional to the change. Do not introduce SDD, multiple
  review agents, or new planning documents for a small UI or interaction fix
  unless the user explicitly requests them.
- Before handing over an APK, run `flutter analyze`, `flutter test`, and
  `flutter build apk --debug`, then report the real results.

## Suggested Start For The Next Conversation

1. Confirm the branch, HEAD, and worktree status.
2. Read this document and `.superpowers/sdd/handoff.md`.
3. Inspect the relevant Java and Flutter UI side by side.
4. Implement the manual location entry as a small change, or follow the user's
   newly chosen first optimization target.
5. Rebuild, replace-install over ADB without clearing app data, and iterate from
   the user's device feedback.
