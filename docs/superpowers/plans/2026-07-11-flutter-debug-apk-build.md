# Flutter Debug APK Build Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the stale Android geocoding plugin, produce a signed debuggable APK, and verify that it installs and launches on the connected USB Android device.

**Architecture:** Keep application behavior unchanged and resolve the Android SDK mismatch through the supported `geocoding 4.x` dependency graph. Run all Flutter commands with the existing Git-ignored D-drive Pub Cache so Kotlin plugin sources and the D-drive project share a filesystem root. The implementation change receives implementer, spec-compliance, and code-quality review before controller-owned build, signature, and ADB verification.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, Android SDK/build-tools 36.0.0, PowerShell, ADB.

## Global Constraints

- Implement the approved design in `docs/superpowers/specs/2026-07-11-flutter-debug-apk-build-design.md`.
- Change only `pubspec.yaml`, `pubspec.lock`, generated Git-ignored files, and the documentation/coordination files required by the SDD workflow.
- Set the direct dependency to exactly `geocoding: ^4.0.0`; do not upgrade to geocoding 5.x.
- Do not run a broad `flutter pub upgrade` and do not change unrelated dependency constraints.
- Do not change Maven, Flutter, or Pub mirrors to manufacture a successful build.
- Use `D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild` as `PUB_CACHE` for every Flutter command in this plan.
- Keep production weather on UAPI primary plus Open-Meteo fallback; do not resume QWeather work.
- Do not commit `.superpowers`, local caches, build products, secrets, or device identifiers.
- The debug APK is for ADB/manual installation and iterative acceptance; it is not a release-signed store artifact.
- Do not uninstall the existing app or clear its data during ADB verification. Use replace-install only.

---

### Task 1: Upgrade geocoding Android compatibility

**Files:**
- Modify: `pubspec.yaml:34`
- Modify: `pubspec.lock:155`
- Test: `lib/services/platform_service.dart:137` through analyzer compilation

**Interfaces:**
- Consumes: the existing top-level `placemarkFromCoordinates(double, double)` call in `PlatformService`.
- Produces: a lockfile resolving `geocoding 4.0.0` and a `geocoding_android 4.x` implementation with Android CompileSDK 35.

- [ ] **Step 1: Confirm the focused red build condition**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat pub get --offline
Push-Location android
.\gradlew.bat :geocoding_android:checkDebugAarMetadata
$redExit = $LASTEXITCODE
Pop-Location
exit $redExit
```

Expected before the upgrade: exit 1 with `geocoding_android is currently compiled against android-33` and AndroidX requiring SDK 34 or newer. If intermittent TLS masks that task, retain its exact error and run this deterministic metadata check:

```powershell
Select-String -LiteralPath 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild\hosted\pub.flutter-io.cn\geocoding_android-3.3.1\android\build.gradle' -Pattern '^\s*compileSdk\s+33$'
```

Expected: one match for `compileSdk 33`.

- [ ] **Step 2: Apply the minimal dependency edit**

Change only this line in `pubspec.yaml`:

```yaml
  geocoding: ^4.0.0
```

- [ ] **Step 3: Resolve the constrained dependency graph**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat pub get
D:\test\flutter\bin\flutter.bat pub deps --style=compact
```

Expected: exit 0; `geocoding 4.0.0` and `geocoding_android 4.x` are present; `geocoding 5.x` is absent. `pubspec.lock` changes only as required by the geocoding federated package graph.

- [ ] **Step 4: Verify the existing application API still compiles**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\dart.bat analyze lib\services\platform_service.dart
```

Expected: exit 0 with `No issues found!`; no application source edit is needed.

- [ ] **Step 5: Verify the focused Android metadata task turns green**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
Push-Location android
.\gradlew.bat :geocoding_android:checkDebugAarMetadata
$greenExit = $LASTEXITCODE
Pop-Location
exit $greenExit
```

Expected: exit 0. Gradle may install Android SDK Platform 35 because the upgraded plugin compiles against SDK 35; retain the original installer output and do not redirect it to another mirror.

- [ ] **Step 6: Run the full analyzer**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat analyze
```

Expected: exit 0 with `No issues found!`.

- [ ] **Step 7: Run the full Flutter test suite**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat test
```

Expected: exit 0 and all 79 tests pass.

- [ ] **Step 8: Perform implementer self-review and write the durable report**

```powershell
git diff --check
git status --short
```

Expected: `git diff --check` is empty and only `pubspec.yaml` plus `pubspec.lock` are modified. The implementer writes a durable report under `.superpowers/sdd` with commands, exit codes, diff scope, and self-review findings.

- [ ] **Step 9: Commit the dependency compatibility fix**

```powershell
git add -- pubspec.yaml pubspec.lock
git diff --cached --check
git commit -m "build: update geocoding Android SDK support"
```

Expected: one commit containing exactly the two dependency files. Do not include `.superpowers`, `.dart_tool`, `build`, or the D-drive Pub Cache.

### Task 2: Review, build, sign, install, and launch the debug APK

**Files:**
- Verify: `pubspec.yaml`
- Verify: `pubspec.lock`
- Generate: `build/app/outputs/flutter-apk/app-debug.apk` (Git-ignored)
- Report: `.superpowers/sdd/handoff.md` and `.superpowers/sdd/progress.md` (never commit)

**Interfaces:**
- Consumes: the reviewed Task 1 commit and the authorized USB Android device selected by `adb -d`.
- Produces: a verified debug-signed APK, its SHA-256 checksum, an installed package `com.homepanel.clock`, and a running `com.homepanel.clock/.MainActivity` process.

- [ ] **Step 1: Complete the two review gates in order**

Dispatch a fresh spec-compliance reviewer against the approved design, implementation plan, Task 1 commit, and durable implementer report. Fix every Critical or Important finding and repeat spec review until approved. Then dispatch a fresh code-quality reviewer, fix every Critical or Important finding, and repeat quality review until approved.

Expected: both final reviewer reports state approved with no remaining Critical or Important findings.

- [ ] **Step 2: Run controller-owned dependency resolution**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat pub get
```

Expected: exit 0 with `Got dependencies!`.

- [ ] **Step 3: Run the controller-owned full analyzer**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat analyze
```

Expected: exit 0 with `No issues found!`.

- [ ] **Step 4: Run the controller-owned full test suite**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat test
```

Expected: exit 0 and all 79 tests pass.

- [ ] **Step 5: Run the controller-owned debug APK build**

```powershell
$env:PUB_CACHE = 'D:\test\Home_Info_Clock\.worktrees\.pub-cache-flutter-rebuild'
D:\test\flutter\bin\flutter.bat build apk --debug
```

Expected: exit 0 and Flutter reports the generated APK path. If TLS/download failure recurs, retain the exact command, exit code, and original error, probe the exact failed URL with the Gradle JDK, and never claim APK success until the original build command exits 0.

- [ ] **Step 6: Verify artifact presence, checksum, signature, package, and debug flag**

```powershell
$apk = (Resolve-Path 'build\app\outputs\flutter-apk\app-debug.apk').Path
$buildTools = 'C:\Users\10146\AppData\Local\Android\Sdk\build-tools\36.0.0'
Get-Item -LiteralPath $apk | Select-Object FullName, Length, LastWriteTime
Get-FileHash -LiteralPath $apk -Algorithm SHA256
& (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apk
$badging = & (Join-Path $buildTools 'aapt.exe') dump badging $apk
$badging | Select-String -Pattern "^package: name='com\.homepanel\.clock'|^application-debuggable"
```

Expected: the APK exists and is non-empty; SHA-256 is printed; `apksigner` exits 0 and prints a signer certificate; `aapt` prints package `com.homepanel.clock` and `application-debuggable`.

- [ ] **Step 7: Confirm the sole USB device remains authorized**

```powershell
$adb = 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb devices -l
```

Expected: exactly one USB entry in state `device`. Do not record its serial number in committed files.

- [ ] **Step 8: Replace-install without deleting app data**

```powershell
$adb = 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$apk = (Resolve-Path 'build\app\outputs\flutter-apk\app-debug.apk').Path
& $adb -d install -r $apk
```

Expected: exit 0 and `Success`. Do not run `adb uninstall`, `pm clear`, or an install command that drops existing app data.

- [ ] **Step 9: Launch and verify the process plus installed debug flag**

```powershell
$adb = 'C:\Users\10146\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb -d shell am force-stop com.homepanel.clock
& $adb -d shell am start -W -n com.homepanel.clock/.MainActivity
& $adb -d shell pidof com.homepanel.clock
$packageDump = & $adb -d shell dumpsys package com.homepanel.clock
$packageDump | Select-String -Pattern 'versionCode=|flags=|pkgFlags='
```

Expected: activity start reports `Status: ok`, `pidof` returns a PID, and the installed package flags include `DEBUGGABLE`.

- [ ] **Step 10: Preserve final evidence and clean Git state**

Record the exact Flutter commands and exit codes, test count, APK absolute path, byte size, SHA-256, `apksigner` result, ADB install result, launch result, and any remaining user-visible acceptance checks in `.superpowers/sdd/handoff.md` and `.superpowers/sdd/progress.md`.

```powershell
git status --short
git log -3 --oneline
```

Expected: Git status is empty; coordination files and caches remain uncommitted; the dependency compatibility commit is present after the design and plan commits.
