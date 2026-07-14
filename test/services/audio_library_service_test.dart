import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/audio_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_info_clock/audio_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'requestAccess parses audio and notification permission results',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'requestAudioAccess');
            return <String, Object?>{
              'audioGranted': true,
              'notificationGranted': false,
            };
          });
      const service = AudioLibraryService(channel: channel);

      final access = await service.requestAccess();

      expect(access.audioGranted, isTrue);
      expect(access.notificationGranted, isFalse);
    },
  );

  test(
    'scanTracks converts every MediaStore result into an AudioTrack',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'scanAudioFolder');
            return <Object?>[
              <String, Object?>{
                'uri': 'content://media/external/audio/media/7',
                'displayName': 'seven.flac',
                'title': 'Seven',
                'artist': 'Home Clock',
                'durationMs': 7000,
                'mimeType': 'audio/flac',
              },
            ];
          });
      const service = AudioLibraryService(channel: channel);

      final tracks = await service.scanTracks();

      expect(tracks, hasLength(1));
      expect(tracks.single.title, 'Seven');
      expect(tracks.single.duration, const Duration(seconds: 7));
    },
  );

  test('openFolder reports whether Android opened the exact folder', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openAudioFolder');
          return true;
        });
    const service = AudioLibraryService(channel: channel);

    expect(await service.openFolder(), isTrue);
  });
}
