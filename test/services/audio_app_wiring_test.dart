import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production creates one app-scoped background music controller', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final appSource = File('lib/app.dart').readAsStringSync();
    final homeSource = File(
      'lib/screens/home_clock_screen.dart',
    ).readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(mainSource, contains('AudioService.init<HomeAudioHandler>'));
    expect(mainSource, contains('AudioSessionConfiguration.music()'));
    expect(mainSource, contains('androidStopForegroundOnPause: false'));
    expect(mainSource, contains('AudioPlayerController('));
    expect(mainSource, contains('AudioLibraryService()'));
    expect(mainSource, contains('JustAudioBackend()'));
    expect(
      appSource,
      contains('final AudioPlayerController? audioController;'),
    );
    expect(appSource, contains('audioController: widget.audioController'));
    expect(
      homeSource,
      contains('final AudioPlayerController? audioController;'),
    );
    expect(homeSource, contains('audioController: audioController'));
    expect(pubspec, contains(RegExp(r'^  audio_session:', multiLine: true)));
  });
}
