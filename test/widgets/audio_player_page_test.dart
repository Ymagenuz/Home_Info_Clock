import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/audio_track.dart';
import 'package:home_info_clock/services/audio_library_service.dart';
import 'package:home_info_clock/services/audio_playback_engine.dart';
import 'package:home_info_clock/state/audio_player_controller.dart';
import 'package:home_info_clock/widgets/audio_player_page.dart';

void main() {
  testWidgets('empty player shows the exact phone folder and both actions', (
    tester,
  ) async {
    final library = _WidgetAudioLibrary();
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('audio-empty-state')), findsOneWidget);
    expect(find.text(audioFolderPath), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audio-open-folder-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('audio-rescan-button')), findsOneWidget);
  });

  testWidgets('ready player shows now playing controls and the playlist', (
    tester,
  ) async {
    final library = _WidgetAudioLibrary(
      tracks: <AudioTrack>[
        _track('First Song', 'first.mp3', 'Test Artist'),
        _track('Second Song', 'second.mp3', ''),
      ],
    );
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );
    engine.emit(
      const AudioPlaybackSnapshot(
        processingState: AudioProcessingState.ready,
        currentIndex: 0,
        position: Duration(seconds: 30),
        duration: Duration(minutes: 2),
      ),
    );
    await tester.pump();

    expect(find.text('First Song'), findsWidgets);
    expect(find.text('Test Artist'), findsOneWidget);
    expect(find.text('\u987a\u5e8f\u64ad\u653e'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-seek-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-previous-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audio-play-pause-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('audio-next-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-playlist-row-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-playlist-row-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playback error stays nonblocking above the ready controls', (
    tester,
  ) async {
    final library = _WidgetAudioLibrary(
      tracks: <AudioTrack>[_track('Broken Song', 'broken.mp3', '')],
    );
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );
    engine.emit(
      const AudioPlaybackSnapshot(
        processingState: AudioProcessingState.error,
        currentIndex: 0,
        errorMessage: 'unsupported codec',
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('audio-ready-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-playback-error')), findsOneWidget);
    expect(find.textContaining('unsupported codec'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-playlist')), findsOneWidget);
  });

  testWidgets('permission denial keeps grant and folder recovery actions', (
    tester,
  ) async {
    final library = _WidgetAudioLibrary(audioGranted: false);
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('audio-permission-state')),
      findsOneWidget,
    );
    expect(find.text('\u6388\u4e88\u97f3\u9891\u6743\u9650'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audio-open-folder-button')),
      findsOneWidget,
    );
    expect(find.text(audioFolderPath), findsOneWidget);
  });

  testWidgets('scan error stays recoverable without replacing the page', (
    tester,
  ) async {
    final library = _WidgetAudioLibrary(scanError: StateError('broken file'));
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('audio-error-state')), findsOneWidget);
    expect(find.textContaining('broken file'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-rescan-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('audio-open-folder-button')),
      findsOneWidget,
    );
  });

  testWidgets('permission and MediaStore work show a compact loading state', (
    tester,
  ) async {
    final access = Completer<AudioLibraryAccess>();
    final library = _WidgetAudioLibrary(accessCompleter: access);
    final engine = _WidgetAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    unawaited(controller.refreshLibrary());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AudioPlayerPage(controller: controller),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('audio-loading-state')), findsOneWidget);
    expect(find.text('\u6b63\u5728\u626b\u63cf\u97f3\u9891'), findsOneWidget);

    access.complete(const AudioLibraryAccess(audioGranted: true));
    await tester.pump();
  });
}

AudioTrack _track(String title, String displayName, String artist) {
  return AudioTrack(
    uri: 'content://media/$displayName',
    displayName: displayName,
    title: title,
    artist: artist,
    duration: const Duration(minutes: 2),
    mimeType: 'audio/mpeg',
  );
}

class _WidgetAudioLibrary implements AudioLibraryGateway {
  _WidgetAudioLibrary({
    this.tracks = const <AudioTrack>[],
    this.audioGranted = true,
    this.scanError,
    this.accessCompleter,
  });

  final List<AudioTrack> tracks;
  final bool audioGranted;
  final Object? scanError;
  final Completer<AudioLibraryAccess>? accessCompleter;

  @override
  Future<bool> openFolder() async => true;

  @override
  Future<AudioLibraryAccess> requestAccess() async {
    final completer = accessCompleter;
    if (completer != null) return completer.future;
    return AudioLibraryAccess(audioGranted: audioGranted);
  }

  @override
  Future<List<AudioTrack>> scanTracks() async {
    if (scanError case final error?) throw error;
    return tracks;
  }
}

class _WidgetAudioEngine implements AudioPlaybackEngine {
  final _snapshots = StreamController<AudioPlaybackSnapshot>.broadcast();
  AudioPlaybackSnapshot _snapshot = const AudioPlaybackSnapshot();

  @override
  AudioPlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<AudioPlaybackSnapshot> get snapshotStream => _snapshots.stream;

  void emit(AudioPlaybackSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  Future<void> clearQueue() async {}

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekToIndex(int index) async {}

  @override
  Future<void> setMode(AudioPlaybackMode mode) async {}

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  Future<void> dispose() => _snapshots.close();
}
