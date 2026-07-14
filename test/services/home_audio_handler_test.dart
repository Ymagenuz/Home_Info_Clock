import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/audio_track.dart';
import 'package:home_info_clock/services/audio_playback_engine.dart';
import 'package:home_info_clock/services/home_audio_handler.dart';
import 'package:home_info_clock/services/just_audio_backend.dart';

void main() {
  test(
    'production backend uses just_audio native queue and loop primitives',
    () {
      final source = File(
        'lib/services/just_audio_backend.dart',
      ).readAsStringSync();

      expect(source, contains('AudioPlayer(maxSkipsOnError: 0)'));
      expect(source, contains('setAudioSources('));
      expect(source, contains('AudioSource.uri(Uri.parse(track.uri))'));
      expect(source, contains('await _player.pause()'));
      expect(source, contains('preload: false'));
      expect(source, contains('LoopMode.one'));
      expect(source, contains('effectiveIndices.first'));
    },
  );

  test('a new shuffle pass does not immediately repeat its last track', () {
    final order = PassShuffleOrder(random: Random(7))..insert(0, 5);

    order.keepCurrentFirst = false;
    order.shuffle(initialIndex: 2);

    expect(order.indices, hasLength(5));
    expect(order.indices.toSet(), <int>{0, 1, 2, 3, 4});
    expect(order.indices.first, isNot(2));
  });

  test('single track repeat uses the backend native loop-one mode', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);

    await handler.setMode(AudioPlaybackMode.repeatOne);

    expect(backend.loopModes, <AudioBackendLoopMode>[AudioBackendLoopMode.one]);
    expect(backend.shuffleEnabled, <bool>[false]);
    expect(backend.seekToFirstShuffledCalls, 0);
  });

  test('sequential mode disables looping and shuffle', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);

    await handler.setMode(AudioPlaybackMode.sequential);

    expect(backend.loopModes, <AudioBackendLoopMode>[AudioBackendLoopMode.off]);
    expect(backend.shuffleEnabled, <bool>[false]);
  });

  test('playlist repeat uses native loop-all without shuffle', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);

    await handler.setMode(AudioPlaybackMode.repeatAll);

    expect(backend.loopModes, <AudioBackendLoopMode>[AudioBackendLoopMode.all]);
    expect(backend.shuffleEnabled, <bool>[false]);
  });

  test(
    'shuffle mode randomizes one finite pass with looping disabled',
    () async {
      final backend = _FakeAudioBackend();
      final handler = HomeAudioHandler(backend: backend);
      addTearDown(handler.dispose);
      addTearDown(backend.dispose);

      await handler.setMode(AudioPlaybackMode.shuffle);

      expect(backend.loopModes, <AudioBackendLoopMode>[
        AudioBackendLoopMode.off,
      ]);
      expect(backend.shuffleEnabled, <bool>[true]);
      expect(backend.shuffleCalls, 1);
      expect(backend.shuffleKeepCurrentFirst, <bool>[true]);
    },
  );

  test(
    'completed shuffle pass reshuffles and continues from its new first item',
    () async {
      final backend = _FakeAudioBackend();
      final handler = HomeAudioHandler(backend: backend);
      addTearDown(handler.dispose);
      addTearDown(backend.dispose);
      await handler.setMode(AudioPlaybackMode.shuffle);

      backend.emit(
        const AudioBackendSnapshot(
          processingState: AudioProcessingState.completed,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(backend.shuffleCalls, 2);
      expect(backend.shuffleKeepCurrentFirst, <bool>[true, false]);
      expect(backend.seekToFirstShuffledCalls, 1);
      expect(backend.playCalls, 1);
    },
  );

  test('sequential completion clears the lingering play intent', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.setMode(AudioPlaybackMode.sequential);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.completed,
        currentIndex: 1,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.pauseCalls, 1);
    expect(backend.playCalls, 0);
  });

  test(
    'play after completion restarts the current track from its beginning',
    () async {
      final backend = _FakeAudioBackend();
      final handler = HomeAudioHandler(backend: backend);
      addTearDown(handler.dispose);
      addTearDown(backend.dispose);
      backend.emit(
        const AudioBackendSnapshot(
          processingState: AudioProcessingState.completed,
          currentIndex: 1,
          position: Duration(minutes: 2),
          duration: Duration(minutes: 2),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await handler.play();

      expect(backend.seekPositions, <Duration>[Duration.zero]);
      expect(backend.playCalls, 1);
    },
  );

  test('loading a queue publishes matching notification metadata', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    final tracks = <AudioTrack>[
      _track('First', 'first.mp3'),
      _track('Second', 'second.flac'),
    ];

    await handler.loadQueue(
      tracks,
      initialIndex: 1,
      initialPosition: const Duration(seconds: 9),
    );

    expect(backend.loadedQueues.single, tracks);
    expect(backend.initialIndices.single, 1);
    expect(backend.initialPositions.single, const Duration(seconds: 9));
    expect(handler.queue.value.map((item) => item.title), <String>[
      'First',
      'Second',
    ]);
    expect(handler.mediaItem.value?.title, 'Second');
  });

  test('backend snapshots drive UI state and notification controls', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('First', 'first.mp3'),
        _track('Second', 'second.mp3'),
      ],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    final nextSnapshot = handler.snapshotStream.firstWhere(
      (snapshot) => snapshot.playing,
    );

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.ready,
        currentIndex: 1,
        position: Duration(seconds: 12),
        duration: Duration(minutes: 2),
      ),
    );
    final snapshot = await nextSnapshot;

    expect(snapshot.currentIndex, 1);
    expect(snapshot.position, const Duration(seconds: 12));
    expect(handler.mediaItem.value?.title, 'Second');
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.queueIndex, 1);
  });

  test(
    'UI and media-session transport actions share the same backend',
    () async {
      final backend = _FakeAudioBackend();
      final handler = HomeAudioHandler(backend: backend);
      addTearDown(handler.dispose);
      addTearDown(backend.dispose);

      await handler.play();
      await handler.pause();
      await handler.seek(const Duration(seconds: 21));
      await handler.seekToIndex(2);
      await handler.skipToPrevious();
      await handler.skipToNext();
      await handler.clearQueue();

      expect(backend.playCalls, 1);
      expect(backend.pauseCalls, 1);
      expect(backend.seekPositions, <Duration>[const Duration(seconds: 21)]);
      expect(backend.seekIndices, <int>[2]);
      expect(backend.previousCalls, 1);
      expect(backend.nextCalls, 1);
      expect(backend.clearQueueCalls, 1);
      expect(handler.queue.value, isEmpty);
    },
  );

  test('transport failures become observable playback errors', () async {
    final backend = _FakeAudioBackend()
      ..playError = StateError('decoder unavailable');
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);

    await handler.play();

    expect(handler.snapshot.processingState, AudioProcessingState.error);
    expect(handler.snapshot.errorMessage, contains('decoder unavailable'));
  });

  test('single repeat pauses instead of retrying a corrupt track', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[_track('Broken', 'broken.mp3')],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    await handler.setMode(AudioPlaybackMode.repeatOne);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 0,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.pauseCalls, 1);
    expect(backend.nextCalls, 0);
  });

  test('multi-track mode skips a corrupt item and keeps playing', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('Broken', 'broken.mp3'),
        _track('Playable', 'playable.flac'),
      ],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    await handler.setMode(AudioPlaybackMode.sequential);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 0,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.nextCalls, 1);
    expect(backend.playCalls, 1);
    expect(backend.pauseCalls, 0);
  });

  test('failed-track recovery reports backend command errors', () async {
    final backend = _FakeAudioBackend()
      ..nextError = StateError('cannot advance');
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('Broken', 'broken.mp3'),
        _track('Playable', 'playable.mp3'),
      ],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 0,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(handler.snapshot.errorMessage, contains('cannot advance'));
  });

  test('sequential mode stops when the last track is corrupt', () async {
    final backend = _FakeAudioBackend()..hasNextValue = false;
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('First', 'first.mp3'),
        _track('Broken Last', 'broken.mp3'),
      ],
      initialIndex: 1,
      initialPosition: Duration.zero,
    );
    await handler.setMode(AudioPlaybackMode.sequential);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 1,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.pauseCalls, 1);
    expect(backend.nextCalls, 0);
    expect(backend.playCalls, 0);
  });

  test('playlist repeat stops after every track fails once', () async {
    final backend = _FakeAudioBackend();
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('Broken One', 'broken-1.mp3'),
        _track('Broken Two', 'broken-2.mp3'),
      ],
      initialIndex: 0,
      initialPosition: Duration.zero,
    );
    await handler.setMode(AudioPlaybackMode.repeatAll);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 0,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.ready,
        currentIndex: 1,
      ),
    );
    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 1,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.nextCalls, 1);
    expect(backend.playCalls, 1);
    expect(backend.pauseCalls, 1);
  });

  test(
    'a corrupt track may be skipped again after another track makes progress',
    () async {
      final backend = _FakeAudioBackend();
      final handler = HomeAudioHandler(backend: backend);
      addTearDown(handler.dispose);
      addTearDown(backend.dispose);
      await handler.loadQueue(
        <AudioTrack>[
          _track('Broken', 'broken.mp3'),
          _track('Playable', 'playable.mp3'),
        ],
        initialIndex: 0,
        initialPosition: Duration.zero,
      );
      await handler.setMode(AudioPlaybackMode.repeatAll);

      backend.emit(
        const AudioBackendSnapshot(
          playing: true,
          processingState: AudioProcessingState.error,
          currentIndex: 0,
          errorMessage: 'unsupported',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      backend.emit(
        const AudioBackendSnapshot(
          playing: true,
          processingState: AudioProcessingState.ready,
          currentIndex: 1,
          position: Duration(seconds: 1),
        ),
      );
      backend.emit(
        const AudioBackendSnapshot(
          playing: true,
          processingState: AudioProcessingState.error,
          currentIndex: 0,
          errorMessage: 'unsupported',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(backend.nextCalls, 2);
      expect(backend.playCalls, 2);
      expect(backend.pauseCalls, 0);
    },
  );

  test('shuffle mode reshuffles when a failed track ends its pass', () async {
    final backend = _FakeAudioBackend()..hasNextValue = false;
    final handler = HomeAudioHandler(backend: backend);
    addTearDown(handler.dispose);
    addTearDown(backend.dispose);
    await handler.loadQueue(
      <AudioTrack>[
        _track('First', 'first.mp3'),
        _track('Second', 'second.mp3'),
        _track('Broken Last', 'broken-last.mp3'),
      ],
      initialIndex: 2,
      initialPosition: Duration.zero,
    );
    await handler.setMode(AudioPlaybackMode.shuffle);

    backend.emit(
      const AudioBackendSnapshot(
        playing: true,
        processingState: AudioProcessingState.error,
        currentIndex: 2,
        errorMessage: 'unsupported',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.shuffleCalls, 2);
    expect(backend.seekToFirstShuffledCalls, 1);
    expect(backend.playCalls, 1);
    expect(backend.nextCalls, 0);
  });
}

AudioTrack _track(String title, String displayName) {
  return AudioTrack(
    uri: 'content://media/$displayName',
    displayName: displayName,
    title: title,
    artist: 'Artist',
    duration: const Duration(minutes: 2),
    mimeType: 'audio/mpeg',
  );
}

class _FakeAudioBackend implements AudioBackend {
  final snapshots = StreamController<AudioBackendSnapshot>.broadcast();
  AudioBackendSnapshot currentSnapshot = const AudioBackendSnapshot();
  final loopModes = <AudioBackendLoopMode>[];
  final shuffleEnabled = <bool>[];
  int seekToFirstShuffledCalls = 0;
  int shuffleCalls = 0;
  final shuffleKeepCurrentFirst = <bool>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int previousCalls = 0;
  int nextCalls = 0;
  int clearQueueCalls = 0;
  final seekPositions = <Duration>[];
  final seekIndices = <int>[];
  bool hasNextValue = true;
  Object? playError;
  Object? nextError;

  @override
  bool get hasNext => hasNextValue;
  final loadedQueues = <List<AudioTrack>>[];
  final initialIndices = <int>[];
  final initialPositions = <Duration>[];

  @override
  AudioBackendSnapshot get snapshot => currentSnapshot;

  @override
  Stream<AudioBackendSnapshot> get snapshotStream => snapshots.stream;

  void emit(AudioBackendSnapshot snapshot) {
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
    initialIndices.add(initialIndex);
    initialPositions.add(initialPosition);
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
  Future<void> seekToFirstShuffled() async {
    seekToFirstShuffledCalls += 1;
  }

  @override
  Future<void> seekToIndex(int index) async {
    seekIndices.add(index);
  }

  @override
  Future<void> setLoopMode(AudioBackendLoopMode mode) async {
    loopModes.add(mode);
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    shuffleEnabled.add(enabled);
  }

  @override
  Future<void> shuffle({required bool keepCurrentFirst}) async {
    shuffleCalls += 1;
    shuffleKeepCurrentFirst.add(keepCurrentFirst);
  }

  @override
  Future<void> skipToNext() async {
    nextCalls += 1;
    if (nextError case final error?) throw error;
  }

  @override
  Future<void> skipToPrevious() async {
    previousCalls += 1;
  }

  @override
  Future<void> stop() async {}

  Future<void> dispose() => snapshots.close();
}
