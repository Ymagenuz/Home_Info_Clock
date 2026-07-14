# Home Info Clock Current Product Direction

Updated: 2026-07-14

This document is the current product-requirements entry point. It supersedes
conflicting requirements in the original Flutter rebuild design and plan,
which remain in the repository as implementation history.

## Current Status

- The Flutter project is a working technical baseline: analysis and tests pass,
  a debug APK builds, and that APK has been installed and launched over ADB.
- The small manual-location iteration described below passed user acceptance on
  a Xiaomi Mi 10 on 2026-07-11 and is committed as `409baba`.
- The first UI optimization iteration relearned the central clock page and
  simple mode from the Java reference. It was tested, built, and visually
  checked on a calibrated MuMu emulator. The user did not give an explicit
  final acceptance verdict before ending that iteration.
- The dashboard side-panel/weather iteration is committed as `01a2461`. It
  compacts the left current-weather layout, keeps the location readable,
  rebalances the activity rings and battery spacing, refines the right-side
  pages, and adds one-hour periodic weather refresh.
- The Java-referenced timer visual and interaction port is implemented in the
  current branch: rotary adjustment and center-page gesture arbitration,
  circular track and unit controls, rotation guidance and value fades, three
  animated countdown rings, start/clear states, and the custom finished-bell
  motion. The clock hand and running seconds ring use a shared vsync frame
  clock. Analysis, all 132 tests, an APK build, MuMu checks, and Xiaomi Mi 10
  launch/interaction/90 Hz frame checks passed on 2026-07-14.
- Overall product acceptance has not passed. Other UI and interaction areas
  still differ substantially from the intended design and require optimization.
- Do not describe the Flutter rebuild as complete based only on green tests or
  a successful APK build.

## Next Product Objective

The next work session continues the remaining user-visible UI and interaction
optimization after the timer milestone. Treat the timer, clock/simple mode,
manual location, and committed side-panel/weather behavior as established
baselines unless focused device feedback calls for revision. Compare each next
area with the preserved native Java implementation under
`legacy/native-android/`, especially:

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

### Manual Location (Accepted 2026-07-11)

Automatic device positioning is no longer the desired product behavior. The
accepted manual-selection behavior is:

- Use one location entry at the place currently showing the waiting-for-location
  placeholder or the selected location name.
- Do not force a location dialog to open on first launch.
- In the location dialog, provide an offline China quick selector with three
  vertical wheels: province, city, and district.
- The China selector covers 34 province-level divisions, including Hong Kong,
  Macao, and Taiwan. It is a convenience path, not a restriction on supported
  locations.
- China wheel confirmation does not depend on the AI API. It resolves the
  selected administrative names through Open-Meteo geocoding, disambiguates
  matches with the selected province and city, and falls back to the selected
  city when a district match is unavailable.
- In the same dialog, provide a text field for arbitrary locations worldwide.
- Use the already configured AI API to parse free-form location text.
- Save the last confirmed location and use it directly on the next app launch.
- Discard legacy automatic-location weather cache when no confirmed manual
  location has been saved, so an in-place APK upgrade does not display the old
  location.
- Keep this feature proportionate. It does not require a separate SDD cycle or
  a large location subsystem.

### UI And Interaction

- The existing Flutter layout is not the accepted final design.
- Relearn panel proportions, information hierarchy, gestures, paging, timer
  behavior, simple mode, typography, spacing, and touch targets from the Java
  reference and the user's device feedback.
- Do not preserve a Flutter behavior merely because it is already tested when
  it conflicts with the intended interaction.
- The clock/simple-mode iteration removes the Flutter-only
  title, status text, and mode buttons; restores the Java clock hierarchy and
  full-surface tap behavior; and restores the Java simple-mode composition.
  Keep that behavior unless new visual feedback requires a revision.
- Preserve the committed side-panel/weather work in `01a2461`, including the
  compact left layout and one-hour weather refresh, unless later device feedback
  calls for a focused revision.
- The implemented timer baseline includes the Java visual hierarchy and effects
  as well as rotary value changes: circular track/ticks and selected-unit coloring,
  in-ring hour/minute/second controls, rotation guidance arrows and their
  fades, active tick/value feedback, three animated countdown rings, the
  state-specific start/clear pill, and the full-screen custom bell shake/pause
  finished state. Preserve this baseline unless later user feedback requests a
  focused revision.
- Keep the tested center PageView lock/unlock behavior during later timer
  refinement. Re-check Java's press/drag initiation and snap behavior rather
  than treating existing Flutter tests as the final interaction specification.

## Primary Visual Device

- Continue UI iteration on the locally installed MuMu emulator. The user has
  granted standing permission to operate it, install APKs, click/swipe, and take
  screenshots or screen recordings without asking each time.
- MuMu remains the primary repeatable visual device. Xiaomi Mi 10 validation is
  opportunistic and must not block future work unless the user explicitly
  connects and authorizes it.
- MuMu instance index: `1`; ADB serial: `127.0.0.1:16416`.
- Android SDK ADB:
  `C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe`.
- If the instance is not visible to ADB, run:
  `D:\Program Files\Netease\MuMu\nx_main\mumu-cli.exe adb -v 1 -c connect`.
- Physical emulator display: Android 12, `1080x2340`, 440 dpi, 60 Hz.
- Current reversible override: natural `1036x2250`, which becomes a
  `2250x1036` landscape application viewport. This exactly matches the Mi 10
  application geometry after removing its 90-pixel left cutout offset.
- Restore the physical emulator size only when needed with `wm size reset`;
  otherwise keep the calibrated override for UI work.
- Use `adb -s 127.0.0.1:16416 install -r ...`; do not uninstall or clear data.

## Working Constraints

- Keep secrets out of Git. UAPI and optional GPTsAPI values continue to use
  `--dart-define` or other local configuration.
- MuMu screenshots/recordings are pre-authorized. The 2026-07-14 Xiaomi Mi 10
  validation and recordings were explicitly authorized; ask again before any
  future physical-device capture.
- Preserve UAPI primary plus Open-Meteo fallback unless the user changes that
  requirement explicitly.
- Use a workflow proportional to the change. Do not introduce SDD, multiple
  review agents, or new planning documents for a small UI or interaction fix
  unless the user explicitly requests them.
- Before handing over an APK, run `flutter analyze`, `flutter test`, and
  `flutter build apk --debug`, then report the real results.

## Suggested Start For The Next Conversation

1. Confirm the branch, HEAD, and worktree status.
2. Read this document, `.superpowers/sdd/handoff.md`, and
   `.superpowers/sdd/progress.md`. Expect the branch history to include the
   accepted manual-location and completed clock/simple-mode iterations; preserve
   any later intentional worktree changes.
3. Reconnect MuMu instance 1 if needed and keep its `1036x2250` size override.
4. Select the next visible product gap from device feedback and compare the
   relevant Java and Flutter implementations side by side. Preserve the timer
   visual/effect language and rotary/page-lock logic unless focused feedback
   requires a revision. Do not restart the accepted manual-location work.
5. Rebuild, replace-install on MuMu without clearing app data, take emulator
   screenshots/recordings, and iterate from those visual results.
