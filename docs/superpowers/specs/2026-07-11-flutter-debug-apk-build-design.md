# Flutter Debug APK Build Compatibility Design

**Date:** 2026-07-11
**Status:** Awaiting written-spec review
**Scope:** Build compatibility and debug APK verification only

## Goal

Produce a debug APK from the `codex/flutter-rebuild` branch that:

- is signed with the normal Android debug key;
- remains debuggable through ADB;
- can be installed or replaced with `adb install -r`;
- is suitable for user acceptance testing and follow-up iterations;
- does not change production weather behavior, timer behavior, or application features.

This work does not produce a release-signed or app-store-ready APK.

## Current blockers

Two independent environment and dependency issues were confirmed:

1. On Windows, Kotlin 2.3.20 fails when Flutter plugin sources are in the default C-drive Pub Cache while the project is on D. A Git-ignored Pub Cache on D removes the cross-volume path failures.
2. `geocoding_android 3.3.1` compiles against Android SDK 33, while its resolved AndroidX dependencies require SDK 34 or newer.

Network TLS failures against Flutter and Maven artifact hosts are intermittent. The build must retain the configured repositories and mirrors; it must not change mirrors merely to obtain a green result.

## Options considered

### 1. Upgrade `geocoding` to 4.x — selected

Upgrade only the direct `geocoding` dependency from `^3.0.0` to `^4.0.0`. Version 4.0.0 raises the Android CompileSDK to 35 and supports Flutter 3.29 or newer. The project uses Flutter 3.44.4. Its existing top-level geocoding API remains available, so no application code migration is expected.

This keeps the compatibility fix in the dependency graph instead of overriding third-party Gradle configuration.

Version 4.0.0 also raises the plugin's iOS minimum to 12, but this repository has no iOS target directory, so that platform change does not alter a supported project target.

### 2. Override plugin CompileSDK from the root Gradle build — rejected

A targeted or blanket subproject override could force `geocoding_android 3.3.1` to compile with SDK 34 or 36. This is a project-specific workaround that couples the root build to third-party module names and Android Gradle Plugin internals.

### 3. Upgrade `geocoding` to 5.x — deferred

Version 5.0.0 also resolves the old Android configuration but introduces a breaking API migration to the `Geocoding` class. That broader behavior and test change is unnecessary for producing the debug APK.

## Implementation boundary

The implementation may change only:

- `pubspec.yaml`, setting `geocoding: ^4.0.0`;
- `pubspec.lock`, through a constrained `flutter pub get` using the existing package source;
- generated and Git-ignored build/cache files.

No broad dependency upgrade is allowed. Application source code may change only if the 4.x package proves incompatible with the existing API during analysis or compilation; such a change requires a new review decision before editing.

The same-drive Pub Cache remains a local, Git-ignored build environment workaround. It is not committed and does not contain credentials.

## Verification

The controller will use the D-drive Pub Cache for all Flutter commands in the verification process and run:

1. `D:\test\flutter\bin\flutter.bat pub get`
2. `D:\test\flutter\bin\flutter.bat analyze`
3. `D:\test\flutter\bin\flutter.bat test`
4. `D:\test\flutter\bin\flutter.bat build apk --debug`

Success requires all of the following:

- analyze exits 0;
- the full test suite exits 0;
- the APK build exits 0;
- `build/app/outputs/flutter-apk/app-debug.apk` exists and is non-empty;
- Android build tools verify the APK signature;
- APK metadata confirms package `com.homepanel.clock` and a debuggable build;
- the exact `adb install -r <apk>` command is supplied for user installation;
- when an authorized device is available and the user wants controller-side installation, an ADB replace-install smoke test may be run.

If TLS or downloads fail again, the exact command, exit code, and original error are retained. A failed build is never reported as successful.

## Commit and handoff

The dependency compatibility change is reviewed and committed separately from the completed Task 9 commit. Coordination files under `.superpowers` and local caches are not committed. The durable handoff records the APK path, checksum, verification evidence, ADB command, and any remaining device-only acceptance steps.
