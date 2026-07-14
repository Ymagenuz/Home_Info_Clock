import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest declares scoped audio media permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.READ_MEDIA_AUDIO'));
    expect(manifest, contains('android.permission.READ_EXTERNAL_STORAGE'));
    expect(manifest, contains('android:maxSdkVersion="32"'));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, isNot(contains('android.permission.QUERY_ALL_PACKAGES')));
  });

  test('Android host declares the background media service contract', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
    );
    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(
      manifest,
      contains('com.ryanheise.audioservice.MediaButtonReceiver'),
    );
    expect(activity, contains('AudioServiceActivity'));
    expect(activity, contains('class MainActivity : AudioServiceActivity()'));
  });

  test(
    'MainActivity queries and opens the exact HomeInfoClock music folder',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/homepanel/clock/MainActivity.kt',
      ).readAsStringSync();

      expect(source, contains('requestAudioAccess'));
      expect(source, contains('scanAudioFolder'));
      expect(source, contains('openAudioFolder'));
      expect(source, contains('MediaStore.Audio.Media'));
      expect(source, contains('MediaStore.Audio.Media.RELATIVE_PATH'));
      expect(source, contains('Music/HomeInfoClock/'));
      expect(source, contains('DocumentsContract'));
      expect(source, contains('Executors.newSingleThreadExecutor()'));
      expect(source, contains('mainHandler.post'));
      expect(source, contains('legacyFolderPath'));
      expect(source, contains('parentFile?.absolutePath'));
      expect(source, contains('folderReady'));
    },
  );
}
