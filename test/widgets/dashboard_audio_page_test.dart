import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/audio_track.dart';
import 'package:home_info_clock/services/audio_library_service.dart';
import 'package:home_info_clock/services/audio_playback_engine.dart';
import 'package:home_info_clock/state/audio_player_controller.dart';
import 'package:home_info_clock/widgets/dashboard_right_panel.dart';

void main() {
  testWidgets('audio refresh waits for the right page scroll to settle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final library = _DashboardAudioLibrary();
    final engine = _DashboardAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardRightPanel(
            weather: null,
            onRefresh: () async {},
            audioController: controller,
          ),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('home-right-page-view'));
    final gesture = await tester.startGesture(tester.getCenter(pages));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-280, 0));
    await tester.pump();

    expect(library.scanCalls, 0);

    await gesture.up();
    await _pumpPageUntilSettled(tester, pages);

    expect(library.scanCalls, 1);
  });

  testWidgets('idle audio page has a stable loading surface during entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final library = _DashboardAudioLibrary();
    final engine = _DashboardAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardRightPanel(
            weather: null,
            onRefresh: () async {},
            audioController: controller,
          ),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('home-right-page-view'));
    final gesture = await tester.startGesture(tester.getCenter(pages));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();

    expect(library.scanCalls, 0);
    expect(find.byKey(const ValueKey('audio-loading-state')), findsOneWidget);

    await gesture.up();
    await _pumpPageUntilSettled(tester, pages);
  });

  testWidgets('second right page is the audio player and scans on entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final library = _DashboardAudioLibrary();
    final engine = _DashboardAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardRightPanel(
            weather: null,
            onRefresh: () async {},
            audioController: controller,
          ),
        ),
      ),
    );

    final pages = find.byKey(const ValueKey('home-right-page-view'));
    await tester.drag(pages, const Offset(-300, 0));
    await _pumpPageUntilSettled(tester, pages);

    expect(find.text('\u97f3\u9891\u64ad\u653e\u5668'), findsOneWidget);
    expect(find.byKey(const ValueKey('audio-empty-state')), findsOneWidget);
    expect(library.scanCalls, 1);
  });

  testWidgets('right pages remain selected beyond the old reset timeout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final library = _DashboardAudioLibrary();
    final engine = _DashboardAudioEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardRightPanel(
            weather: null,
            onRefresh: () async {},
            audioController: controller,
          ),
        ),
      ),
    );
    final pages = find.byKey(const ValueKey('home-right-page-view'));
    await tester.drag(pages, const Offset(-300, 0));
    await _pumpPageUntilSettled(tester, pages);
    expect(find.text('\u97f3\u9891\u64ad\u653e\u5668'), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('\u97f3\u9891\u64ad\u653e\u5668'), findsOneWidget);
  });
}

class _DashboardAudioLibrary implements AudioLibraryGateway {
  int scanCalls = 0;

  @override
  Future<bool> openFolder() async => true;

  @override
  Future<AudioLibraryAccess> requestAccess() async {
    return const AudioLibraryAccess(audioGranted: true);
  }

  @override
  Future<List<AudioTrack>> scanTracks() async {
    scanCalls += 1;
    return const <AudioTrack>[];
  }
}

class _DashboardAudioEngine implements AudioPlaybackEngine {
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

Future<void> _pumpPageUntilSettled(WidgetTester tester, Finder pageView) async {
  final scrollable = find.descendant(
    of: pageView,
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.left ||
              widget.axisDirection == AxisDirection.right),
    ),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  var previousPixels = position.pixels;
  var stableFrames = 0;
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    final pixels = position.pixels;
    final stable =
        (pixels - previousPixels).abs() < 0.01 &&
        !position.isScrollingNotifier.value;
    stableFrames = stable ? stableFrames + 1 : 0;
    if (stableFrames >= 2) return;
    previousPixels = pixels;
  }
  fail('PageView did not settle');
}
