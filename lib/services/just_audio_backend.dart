import 'dart:async';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

import '../models/audio_track.dart';
import 'audio_playback_engine.dart';
import 'home_audio_handler.dart';

/// A shuffle order that can start a new pass away from the item that just
/// finished, while still keeping the current item first when shuffle is first
/// enabled during playback.
class PassShuffleOrder extends ShuffleOrder {
  PassShuffleOrder({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  final List<int> indices = <int>[];

  bool keepCurrentFirst = true;

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));
    if (indices.length <= 1) return;
    indices.shuffle(_random);
    if (initialIndex == null) return;

    final currentPosition = indices.indexOf(initialIndex);
    final targetPosition = keepCurrentFirst
        ? 0
        : 1 + _random.nextInt(indices.length - 1);
    final targetIndex = indices[targetPosition];
    indices[targetPosition] = initialIndex;
    indices[currentPosition] = targetIndex;
  }

  @override
  void insert(int index, int count) {
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) indices[i] += count;
    }
    for (var offset = 0; offset < count; offset++) {
      final insertionIndex = _random.nextInt(indices.length + 1);
      indices.insert(insertionIndex, index + offset);
    }
  }

  @override
  void removeRange(int start, int end) {
    final count = end - start;
    final removed = List<int>.generate(
      count,
      (offset) => start + offset,
    ).toSet();
    indices.removeWhere(removed.contains);
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= end) indices[i] -= count;
    }
  }

  @override
  void clear() => indices.clear();
}

class JustAudioBackend implements AudioBackend {
  JustAudioBackend({AudioPlayer? player})
    : _player = player ?? AudioPlayer(maxSkipsOnError: 0) {
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.playerStateStream.listen((state) {
        _playing = state.playing;
        _processingState = _mapProcessingState(state.processingState);
        if (state.processingState == ProcessingState.ready) {
          _errorMessage = null;
        }
        _emit();
      }),
      _player.currentIndexStream.listen((index) {
        _currentIndex = index;
        _emit();
      }),
      _player.positionStream.listen((position) {
        _position = position;
        _emit();
      }),
      _player.durationStream.listen((duration) {
        _duration = duration ?? Duration.zero;
        _emit();
      }),
      _player.errorStream.listen((error) {
        _errorMessage = error.message ?? error.toString();
        _processingState = AudioProcessingState.error;
        _emit();
      }),
    ]);
  }

  final AudioPlayer _player;
  final PassShuffleOrder _shuffleOrder = PassShuffleOrder();
  final StreamController<AudioBackendSnapshot> _snapshotController =
      StreamController<AudioBackendSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  bool _playing = false;
  AudioProcessingState _processingState = AudioProcessingState.idle;
  int? _currentIndex;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _errorMessage;

  @override
  AudioBackendSnapshot get snapshot => AudioBackendSnapshot(
    playing: _playing,
    processingState: _processingState,
    currentIndex: _currentIndex,
    position: _position,
    duration: _duration,
    errorMessage: _errorMessage,
  );

  @override
  Stream<AudioBackendSnapshot> get snapshotStream => _snapshotController.stream;

  @override
  bool get hasNext => _player.hasNext;

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    _errorMessage = null;
    await _player.pause();
    final sources = tracks
        .map((track) => AudioSource.uri(Uri.parse(track.uri)))
        .toList(growable: false);
    await _player.setAudioSources(
      sources,
      preload: false,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
      shuffleOrder: _shuffleOrder,
    );
  }

  @override
  Future<void> clearQueue() async {
    await _player.stop();
    await _player.clearAudioSources();
    _currentIndex = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    _emit();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> seekToIndex(int index) {
    return _player.seek(Duration.zero, index: index);
  }

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> setLoopMode(AudioBackendLoopMode mode) {
    return _player.setLoopMode(switch (mode) {
      AudioBackendLoopMode.off => LoopMode.off,
      AudioBackendLoopMode.one => LoopMode.one,
      AudioBackendLoopMode.all => LoopMode.all,
    });
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) {
    return _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> shuffle({required bool keepCurrentFirst}) async {
    _shuffleOrder.keepCurrentFirst = keepCurrentFirst;
    await _player.shuffle();
  }

  @override
  Future<void> seekToFirstShuffled() async {
    if (_player.effectiveIndices.isEmpty) return;
    await _player.seek(Duration.zero, index: _player.effectiveIndices.first);
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => AudioProcessingState.loading,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  void _emit() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _snapshotController.close();
  }
}
