import 'dart:async';

import 'package:audio_service/audio_service.dart' as service;

import '../models/audio_track.dart';
import 'audio_playback_engine.dart';

enum AudioBackendLoopMode { off, one, all }

class AudioBackendSnapshot {
  const AudioBackendSnapshot({
    this.playing = false,
    this.processingState = AudioProcessingState.idle,
    this.currentIndex,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  final bool playing;
  final AudioProcessingState processingState;
  final int? currentIndex;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
}

abstract interface class AudioBackend {
  AudioBackendSnapshot get snapshot;
  Stream<AudioBackendSnapshot> get snapshotStream;
  bool get hasNext;

  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  });
  Future<void> clearQueue();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setLoopMode(AudioBackendLoopMode mode);
  Future<void> setShuffleEnabled(bool enabled);
  Future<void> shuffle({required bool keepCurrentFirst});
  Future<void> seekToFirstShuffled();
}

class HomeAudioHandler extends service.BaseAudioHandler
    implements AudioPlaybackEngine {
  HomeAudioHandler({required AudioBackend backend}) : _backend = backend {
    _snapshot = _toPlaybackSnapshot(backend.snapshot);
    _backendSubscription = backend.snapshotStream.listen(
      _handleBackendSnapshot,
    );
  }

  final AudioBackend _backend;
  late final StreamSubscription<AudioBackendSnapshot> _backendSubscription;
  final StreamController<AudioPlaybackSnapshot> _snapshotController =
      StreamController<AudioPlaybackSnapshot>.broadcast(sync: true);
  late AudioPlaybackSnapshot _snapshot;
  AudioPlaybackMode _mode = AudioPlaybackMode.sequential;
  AudioProcessingState _lastProcessingState = AudioProcessingState.idle;
  bool _restartingShuffle = false;
  bool _recoveringError = false;
  final Set<int> _failedTrackIndices = <int>{};
  List<AudioTrack> _tracks = const <AudioTrack>[];

  @override
  AudioPlaybackSnapshot get snapshot => _snapshot;

  @override
  Stream<AudioPlaybackSnapshot> get snapshotStream =>
      _snapshotController.stream;

  @override
  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  }) async {
    if (tracks.isEmpty) {
      await _backend.clearQueue();
      _tracks = const <AudioTrack>[];
      queue.add(const <service.MediaItem>[]);
      mediaItem.add(null);
      return;
    }
    final safeIndex = initialIndex.clamp(0, tracks.length - 1);
    await _backend.loadQueue(
      tracks,
      initialIndex: safeIndex,
      initialPosition: initialPosition,
    );
    _failedTrackIndices.clear();
    _tracks = List<AudioTrack>.unmodifiable(tracks);
    final mediaItems = _tracks.map(_toMediaItem).toList(growable: false);
    queue.add(mediaItems);
    mediaItem.add(mediaItems[safeIndex]);
  }

  service.MediaItem _toMediaItem(AudioTrack track) {
    return service.MediaItem(
      id: track.uri,
      album: 'HomeInfoClock',
      title: track.title,
      artist: track.artist.isEmpty ? null : track.artist,
      duration: track.duration,
      extras: <String, Object?>{
        'displayName': track.displayName,
        'mimeType': track.mimeType,
      },
    );
  }

  @override
  Future<void> setMode(AudioPlaybackMode mode) async {
    switch (mode) {
      case AudioPlaybackMode.repeatOne:
        await _backend.setShuffleEnabled(false);
        await _backend.setLoopMode(AudioBackendLoopMode.one);
      case AudioPlaybackMode.sequential:
        await _backend.setShuffleEnabled(false);
        await _backend.setLoopMode(AudioBackendLoopMode.off);
      case AudioPlaybackMode.repeatAll:
        await _backend.setShuffleEnabled(false);
        await _backend.setLoopMode(AudioBackendLoopMode.all);
      case AudioPlaybackMode.shuffle:
        await _backend.setLoopMode(AudioBackendLoopMode.off);
        await _backend.setShuffleEnabled(true);
        await _backend.shuffle(keepCurrentFirst: true);
    }
    _mode = mode;
  }

  @override
  Future<void> clearQueue() async {
    await _backend.clearQueue();
    _failedTrackIndices.clear();
    _tracks = const <AudioTrack>[];
    queue.add(const <service.MediaItem>[]);
    mediaItem.add(null);
  }

  @override
  Future<void> play() => _runTransportCommand(() async {
    _failedTrackIndices.clear();
    if (_snapshot.processingState == AudioProcessingState.completed) {
      await _backend.seek(Duration.zero);
    }
    await _backend.play();
  });

  @override
  Future<void> pause() => _runTransportCommand(_backend.pause);

  @override
  Future<void> seek(Duration position) =>
      _runTransportCommand(() => _backend.seek(position));

  @override
  Future<void> seekToIndex(int index) =>
      _runTransportCommand(() => _backend.seekToIndex(index));

  @override
  Future<void> skipToQueueItem(int index) => seekToIndex(index);

  @override
  Future<void> skipToPrevious() =>
      _runTransportCommand(_backend.skipToPrevious);

  @override
  Future<void> skipToNext() => _runTransportCommand(_backend.skipToNext);

  @override
  Future<void> stop() async {
    await _runTransportCommand(_backend.stop);
    await super.stop();
  }

  void _handleBackendSnapshot(AudioBackendSnapshot snapshot) {
    _snapshot = _toPlaybackSnapshot(snapshot);
    final currentIndex = snapshot.currentIndex;
    if (currentIndex != null &&
        currentIndex >= 0 &&
        currentIndex < queue.value.length) {
      mediaItem.add(queue.value[currentIndex]);
    }
    playbackState.add(
      playbackState.value.copyWith(
        controls: <service.MediaControl>[
          service.MediaControl.skipToPrevious,
          if (snapshot.playing)
            service.MediaControl.pause
          else
            service.MediaControl.play,
          service.MediaControl.skipToNext,
        ],
        systemActions: const <service.MediaAction>{service.MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _toServiceProcessingState(snapshot.processingState),
        playing: snapshot.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.position,
        speed: 1,
        queueIndex: snapshot.currentIndex,
        errorMessage: snapshot.errorMessage,
      ),
    );
    _snapshotController.add(_snapshot);
    final previousProcessingState = _lastProcessingState;
    final justCompleted =
        snapshot.processingState == AudioProcessingState.completed &&
        previousProcessingState != AudioProcessingState.completed;
    final justErrored =
        snapshot.processingState == AudioProcessingState.error &&
        previousProcessingState != AudioProcessingState.error;
    _lastProcessingState = snapshot.processingState;
    if (snapshot.processingState == AudioProcessingState.ready &&
        snapshot.position > Duration.zero) {
      _failedTrackIndices.clear();
    }
    if (justErrored) {
      final failedIndex = snapshot.currentIndex;
      final repeatedFailure =
          failedIndex == null || !_failedTrackIndices.add(failedIndex);
      final exhaustedQueue =
          repeatedFailure || _failedTrackIndices.length >= _tracks.length;
      if (_mode == AudioPlaybackMode.repeatOne ||
          _tracks.length <= 1 ||
          exhaustedQueue) {
        unawaited(_runTransportCommand(_backend.pause));
      } else {
        unawaited(_skipFailedTrack());
      }
    }
    if (_mode == AudioPlaybackMode.shuffle && justCompleted) {
      unawaited(_restartShuffledQueue());
    } else if (_mode == AudioPlaybackMode.sequential && justCompleted) {
      unawaited(_runTransportCommand(_backend.pause));
    }
  }

  Future<void> _skipFailedTrack() async {
    if (_recoveringError) return;
    _recoveringError = true;
    try {
      if (_mode == AudioPlaybackMode.sequential && !_backend.hasNext) {
        await _backend.pause();
        return;
      }
      if (_mode == AudioPlaybackMode.shuffle && !_backend.hasNext) {
        await _restartShuffledQueue();
        return;
      }
      await _backend.skipToNext();
      await _backend.play();
    } catch (error) {
      _publishCommandError(error);
    } finally {
      _recoveringError = false;
    }
  }

  AudioPlaybackSnapshot _toPlaybackSnapshot(AudioBackendSnapshot snapshot) {
    return AudioPlaybackSnapshot(
      playing: snapshot.playing,
      processingState: snapshot.processingState,
      currentIndex: snapshot.currentIndex,
      position: snapshot.position,
      duration: snapshot.duration,
      errorMessage: snapshot.errorMessage,
    );
  }

  service.AudioProcessingState _toServiceProcessingState(
    AudioProcessingState state,
  ) {
    return switch (state) {
      AudioProcessingState.idle => service.AudioProcessingState.idle,
      AudioProcessingState.loading => service.AudioProcessingState.loading,
      AudioProcessingState.ready => service.AudioProcessingState.ready,
      AudioProcessingState.completed => service.AudioProcessingState.completed,
      AudioProcessingState.error => service.AudioProcessingState.error,
    };
  }

  Future<void> _restartShuffledQueue() async {
    if (_restartingShuffle) return;
    _restartingShuffle = true;
    try {
      await _backend.shuffle(keepCurrentFirst: false);
      await _backend.seekToFirstShuffled();
      await _backend.play();
    } catch (error) {
      _publishCommandError(error);
    } finally {
      _restartingShuffle = false;
    }
  }

  Future<void> _runTransportCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (error) {
      _publishCommandError(error);
    }
  }

  void _publishCommandError(Object error) {
    final message = error.toString();
    _snapshot = AudioPlaybackSnapshot(
      playing: _snapshot.playing,
      processingState: AudioProcessingState.error,
      currentIndex: _snapshot.currentIndex,
      position: _snapshot.position,
      duration: _snapshot.duration,
      errorMessage: message,
    );
    playbackState.add(
      playbackState.value.copyWith(
        processingState: service.AudioProcessingState.error,
        errorMessage: message,
      ),
    );
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_snapshot);
    }
  }

  Future<void> dispose() async {
    await _backendSubscription.cancel();
    await _snapshotController.close();
  }
}
