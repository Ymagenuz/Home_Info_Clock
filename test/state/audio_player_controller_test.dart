import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/audio_track.dart';
import 'package:home_info_clock/services/audio_library_service.dart';
import 'package:home_info_clock/services/audio_playback_engine.dart';
import 'package:home_info_clock/state/audio_player_controller.dart';

void main() {
  test(
    'permission denial does not scan or replace the playback queue',
    () async {
      final library = _FakeAudioLibrary(
        access: const AudioLibraryAccess(audioGranted: false),
      );
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: library,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.refreshLibrary();

      expect(controller.libraryStatus, AudioLibraryStatus.permissionDenied);
      expect(library.scanCalls, 0);
      expect(engine.loadedQueues, isEmpty);
    },
  );

  test(
    'granted scan naturally sorts tracks before loading the queue',
    () async {
      final library = _FakeAudioLibrary(
        tracks: <AudioTrack>[
          _track('Song 10.mp3'),
          _track('song 2.mp3'),
          _track('Song 01.mp3'),
        ],
      );
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: library,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.refreshLibrary();

      expect(controller.libraryStatus, AudioLibraryStatus.ready);
      expect(controller.tracks.map((track) => track.displayName), <String>[
        'Song 01.mp3',
        'song 2.mp3',
        'Song 10.mp3',
      ]);
      expect(engine.loadedQueues.single, controller.tracks);
      expect(engine.lastInitialIndex, 0);
      expect(engine.lastInitialPosition, Duration.zero);
    },
  );

  test('empty folder clears playback and exposes the empty state', () async {
    final library = _FakeAudioLibrary();
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await controller.refreshLibrary();

    expect(controller.libraryStatus, AudioLibraryStatus.empty);
    expect(controller.tracks, isEmpty);
    expect(engine.clearQueueCalls, 1);
    expect(engine.loadedQueues, isEmpty);
  });

  test('unchanged rescan does not reload the active queue', () async {
    final library = _FakeAudioLibrary(
      tracks: <AudioTrack>[_track('A.mp3'), _track('B.mp3')],
    );
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await controller.refreshLibrary();
    await controller.refreshLibrary();

    expect(library.scanCalls, 2);
    expect(engine.loadedQueues, hasLength(1));
  });

  test(
    'metadata changes refresh a queue even when its URI is unchanged',
    () async {
      final library = _FakeAudioLibrary(tracks: <AudioTrack>[_track('A.mp3')]);
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: library,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.refreshLibrary();
      library.tracks = <AudioTrack>[_track('A.mp3', title: 'Updated title')];
      await controller.refreshLibrary();

      expect(engine.loadedQueues, hasLength(2));
      expect(controller.tracks.single.title, 'Updated title');
    },
  );

  test(
    'concurrent refresh requests share one permission and scan pass',
    () async {
      final access = Completer<AudioLibraryAccess>();
      final library = _FakeAudioLibrary(
        accessCompleter: access,
        tracks: <AudioTrack>[_track('A.mp3')],
      );
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: library,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      final first = controller.refreshLibrary();
      final second = controller.refreshLibrary();
      await Future<void>.delayed(Duration.zero);

      expect(library.accessCalls, 1);
      access.complete(const AudioLibraryAccess(audioGranted: true));
      await Future.wait(<Future<void>>[first, second]);
      expect(library.scanCalls, 1);
      expect(engine.loadedQueues, hasLength(1));
    },
  );

  test(
    'changed rescan preserves the current track position and play state',
    () async {
      final library = _FakeAudioLibrary(
        tracks: <AudioTrack>[_track('A.mp3'), _track('B.mp3')],
      );
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: library,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.refreshLibrary();
      engine.emit(
        const AudioPlaybackSnapshot(
          playing: true,
          processingState: AudioProcessingState.ready,
          currentIndex: 1,
          position: Duration(seconds: 17),
          duration: Duration(minutes: 1),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      library.tracks = <AudioTrack>[_track('B.mp3'), _track('C.mp3')];
      await controller.refreshLibrary();

      expect(engine.lastInitialIndex, 0);
      expect(engine.lastInitialPosition, const Duration(seconds: 17));
      expect(engine.playCalls, 1);
    },
  );

  test(
    'mode button advances the engine to the next playback behavior',
    () async {
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: _FakeAudioLibrary(),
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(controller.mode, AudioPlaybackMode.sequential);
      await controller.cycleMode();

      expect(controller.mode, AudioPlaybackMode.repeatAll);
      expect(engine.modes, <AudioPlaybackMode>[AudioPlaybackMode.repeatAll]);
    },
  );

  test('rapid mode taps share one in-flight transition', () async {
    final modeCompleter = Completer<void>();
    final engine = _FakeAudioPlaybackEngine()..setModeCompleter = modeCompleter;
    final controller = AudioPlayerController(
      library: _FakeAudioLibrary(),
      engine: engine,
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    final first = controller.cycleMode();
    final second = controller.cycleMode();
    await Future<void>.delayed(Duration.zero);

    expect(engine.modes, <AudioPlaybackMode>[AudioPlaybackMode.repeatAll]);
    modeCompleter.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(controller.mode, AudioPlaybackMode.repeatAll);
  });

  test('engine snapshots expose the active track and playing state', () async {
    final library = _FakeAudioLibrary(tracks: <AudioTrack>[_track('A.mp3')]);
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    engine.emit(
      const AudioPlaybackSnapshot(
        playing: true,
        processingState: AudioProcessingState.ready,
        currentIndex: 0,
        position: Duration(seconds: 8),
        duration: Duration(minutes: 1),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.isPlaying, isTrue);
    expect(controller.currentTrack?.displayName, 'A.mp3');
    expect(controller.position, const Duration(seconds: 8));
    expect(controller.duration, const Duration(minutes: 1));
  });

  test('play pause button follows the latest engine state', () async {
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(
      library: _FakeAudioLibrary(),
      engine: engine,
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await controller.playPause();
    engine.emit(const AudioPlaybackSnapshot(playing: true));
    await Future<void>.delayed(Duration.zero);
    await controller.playPause();

    expect(engine.playCalls, 1);
    expect(engine.pauseCalls, 1);
  });

  test('transport failures become a visible non-escaping error', () async {
    final engine = _FakeAudioPlaybackEngine()
      ..playError = StateError('decoder unavailable');
    final controller = AudioPlayerController(
      library: _FakeAudioLibrary(),
      engine: engine,
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await controller.playPause();

    expect(controller.errorMessage, contains('decoder unavailable'));
  });

  test('tapping a playlist row selects it and starts playback', () async {
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(
      library: _FakeAudioLibrary(
        tracks: <AudioTrack>[_track('A.mp3'), _track('B.mp3')],
      ),
      engine: engine,
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);
    await controller.refreshLibrary();

    await controller.playTrack(1);

    expect(engine.seekIndices, <int>[1]);
    expect(engine.playCalls, 1);
  });

  test(
    'seek and adjacent-track controls delegate to the playback engine',
    () async {
      final engine = _FakeAudioPlaybackEngine();
      final controller = AudioPlayerController(
        library: _FakeAudioLibrary(),
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.seek(const Duration(seconds: 23));
      await controller.skipPrevious();
      await controller.skipNext();

      expect(engine.seekPositions, <Duration>[const Duration(seconds: 23)]);
      expect(engine.previousCalls, 1);
      expect(engine.nextCalls, 1);
    },
  );

  test('open folder action delegates to the shared-storage gateway', () async {
    final library = _FakeAudioLibrary();
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    expect(await controller.openFolder(), isTrue);
    expect(library.openFolderCalls, 1);
  });

  test('scan failure becomes a visible controller error state', () async {
    final library = _FakeAudioLibrary(scanError: StateError('media failed'));
    final engine = _FakeAudioPlaybackEngine();
    final controller = AudioPlayerController(library: library, engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    await controller.refreshLibrary();

    expect(controller.libraryStatus, AudioLibraryStatus.error);
    expect(controller.errorMessage, contains('media failed'));
  });
}

AudioTrack _track(String displayName, {String? title}) {
  return AudioTrack(
    uri: 'content://media/$displayName',
    displayName: displayName,
    title: title ?? displayName,
    artist: '',
    duration: const Duration(minutes: 1),
    mimeType: 'audio/mpeg',
  );
}

class _FakeAudioLibrary implements AudioLibraryGateway {
  _FakeAudioLibrary({
    this.access = const AudioLibraryAccess(audioGranted: true),
    this.tracks = const <AudioTrack>[],
    this.scanError,
    this.accessCompleter,
  });

  AudioLibraryAccess access;
  List<AudioTrack> tracks;
  int scanCalls = 0;
  int accessCalls = 0;
  int openFolderCalls = 0;
  Object? scanError;
  final Completer<AudioLibraryAccess>? accessCompleter;

  @override
  Future<AudioLibraryAccess> requestAccess() async {
    accessCalls += 1;
    return accessCompleter?.future ?? access;
  }

  @override
  Future<List<AudioTrack>> scanTracks() async {
    scanCalls += 1;
    if (scanError case final error?) throw error;
    return tracks;
  }

  @override
  Future<bool> openFolder() async {
    openFolderCalls += 1;
    return true;
  }
}

class _FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final snapshots = StreamController<AudioPlaybackSnapshot>.broadcast();
  final loadedQueues = <List<AudioTrack>>[];
  AudioPlaybackSnapshot currentSnapshot = const AudioPlaybackSnapshot();
  int? lastInitialIndex;
  Duration? lastInitialPosition;
  int clearQueueCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  final modes = <AudioPlaybackMode>[];
  final seekIndices = <int>[];
  final seekPositions = <Duration>[];
  int previousCalls = 0;
  int nextCalls = 0;
  Object? playError;
  Completer<void>? setModeCompleter;

  @override
  AudioPlaybackSnapshot get snapshot => currentSnapshot;

  @override
  Stream<AudioPlaybackSnapshot> get snapshotStream => snapshots.stream;

  void emit(AudioPlaybackSnapshot snapshot) {
    currentSnapshot = snapshot;
    snapshots.add(snapshot);
  }

  @override
  Future<void> clearQueue() async {
    clearQueueCalls += 1;
  }

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    loadedQueues.add(List<AudioTrack>.of(tracks));
    lastInitialIndex = initialIndex;
    lastInitialPosition = initialPosition;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    if (playError case final error?) throw error;
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> seekToIndex(int index) async {
    seekIndices.add(index);
  }

  @override
  Future<void> setMode(AudioPlaybackMode mode) async {
    modes.add(mode);
    await setModeCompleter?.future;
  }

  @override
  Future<void> skipToNext() async {
    nextCalls += 1;
  }

  @override
  Future<void> skipToPrevious() async {
    previousCalls += 1;
  }

  Future<void> dispose() => snapshots.close();
}
