import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/audio_track.dart';
import '../services/audio_library_service.dart';
import '../services/audio_playback_engine.dart';

enum AudioLibraryStatus { idle, loading, permissionDenied, empty, ready, error }

class AudioPlayerController extends ChangeNotifier {
  AudioPlayerController({required this.library, required this.engine})
    : _playback = engine.snapshot {
    _playbackSubscription = engine.snapshotStream.listen(_handlePlayback);
  }

  final AudioLibraryGateway library;
  final AudioPlaybackEngine engine;
  late final StreamSubscription<AudioPlaybackSnapshot> _playbackSubscription;

  AudioLibraryStatus _libraryStatus = AudioLibraryStatus.idle;
  List<AudioTrack> _tracks = const <AudioTrack>[];
  AudioPlaybackSnapshot _playback;
  AudioPlaybackMode _mode = AudioPlaybackMode.sequential;
  String? _errorMessage;
  bool _disposed = false;
  Future<void>? _refreshInFlight;
  Future<void>? _modeChangeInFlight;

  AudioLibraryStatus get libraryStatus => _libraryStatus;
  List<AudioTrack> get tracks => _tracks;
  AudioPlaybackSnapshot get playback => _playback;
  AudioPlaybackMode get mode => _mode;
  bool get isPlaying => _playback.playing;
  Duration get position => _playback.position;
  Duration get duration => _playback.duration;
  String? get errorMessage => _errorMessage ?? _playback.errorMessage;
  AudioTrack? get currentTrack {
    final index = _playback.currentIndex;
    if (index == null || index < 0 || index >= _tracks.length) return null;
    return _tracks[index];
  }

  Future<void> refreshLibrary() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final refresh = _refreshLibraryWithErrorHandling();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _refreshLibraryWithErrorHandling() async {
    try {
      await _refreshLibrary();
    } catch (error) {
      if (_disposed) return;
      _errorMessage = error.toString();
      _libraryStatus = AudioLibraryStatus.error;
      notifyListeners();
    }
  }

  Future<void> _refreshLibrary() async {
    final previousTrackUri = currentTrack?.uri;
    final previousPosition = _playback.position;
    final wasPlaying = _playback.playing;
    _errorMessage = null;
    final hasStableContent =
        _libraryStatus == AudioLibraryStatus.ready ||
        _libraryStatus == AudioLibraryStatus.empty;
    if (!hasStableContent) {
      _libraryStatus = AudioLibraryStatus.loading;
      notifyListeners();
    }

    final access = await library.requestAccess();
    if (_disposed) return;
    if (!access.audioGranted) {
      _libraryStatus = AudioLibraryStatus.permissionDenied;
      notifyListeners();
      return;
    }

    final tracks = sortAudioTracksByDisplayName(await library.scanTracks());
    if (_disposed) return;
    if (tracks.isEmpty) {
      await engine.clearQueue();
      if (_disposed) return;
      _tracks = const <AudioTrack>[];
      _libraryStatus = AudioLibraryStatus.empty;
      notifyListeners();
      return;
    }
    if (_hasSameQueue(tracks)) {
      _tracks = tracks;
      _libraryStatus = AudioLibraryStatus.ready;
      notifyListeners();
      return;
    }
    final preservedIndex = previousTrackUri == null
        ? -1
        : tracks.indexWhere((track) => track.uri == previousTrackUri);
    await engine.loadQueue(
      tracks,
      initialIndex: preservedIndex < 0 ? 0 : preservedIndex,
      initialPosition: preservedIndex < 0 ? Duration.zero : previousPosition,
    );
    if (_disposed) return;
    _tracks = tracks;
    _libraryStatus = AudioLibraryStatus.ready;
    if (wasPlaying) await engine.play();
    if (_disposed) return;
    notifyListeners();
  }

  Future<void> cycleMode() {
    final inFlight = _modeChangeInFlight;
    if (inFlight != null) return inFlight;

    final operation = _cycleMode();
    _modeChangeInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_modeChangeInFlight, operation)) {
        _modeChangeInFlight = null;
      }
    });
  }

  Future<void> _cycleMode() async {
    final nextMode = _mode.next;
    final succeeded = await _runPlaybackAction(() => engine.setMode(nextMode));
    if (!succeeded) return;
    if (_disposed) return;
    _mode = nextMode;
    notifyListeners();
  }

  Future<void> playPause() async {
    await _runPlaybackAction(isPlaying ? engine.pause : engine.play);
  }

  Future<void> playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _runPlaybackAction(() async {
      await engine.seekToIndex(index);
      await engine.play();
    });
  }

  Future<void> seek(Duration position) async {
    await _runPlaybackAction(() => engine.seek(position));
  }

  Future<void> skipPrevious() async {
    await _runPlaybackAction(engine.skipToPrevious);
  }

  Future<void> skipNext() async {
    await _runPlaybackAction(engine.skipToNext);
  }

  Future<bool> openFolder() async {
    try {
      return await library.openFolder();
    } catch (error) {
      _reportError(error);
      return false;
    }
  }

  Future<bool> _runPlaybackAction(Future<void> Function() action) async {
    try {
      await action();
      if (!_disposed && _errorMessage != null) {
        _errorMessage = null;
        notifyListeners();
      }
      return true;
    } catch (error) {
      _reportError(error);
      return false;
    }
  }

  void _reportError(Object error) {
    if (_disposed) return;
    _errorMessage = error.toString();
    notifyListeners();
  }

  bool _hasSameQueue(List<AudioTrack> tracks) {
    if (tracks.length != _tracks.length) return false;
    for (var index = 0; index < tracks.length; index += 1) {
      final next = tracks[index];
      final current = _tracks[index];
      if (next.uri != current.uri ||
          next.displayName != current.displayName ||
          next.title != current.title ||
          next.artist != current.artist ||
          next.duration != current.duration ||
          next.mimeType != current.mimeType) {
        return false;
      }
    }
    return true;
  }

  void _handlePlayback(AudioPlaybackSnapshot snapshot) {
    if (_disposed) return;
    _playback = snapshot;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_playbackSubscription.cancel());
    super.dispose();
  }
}
