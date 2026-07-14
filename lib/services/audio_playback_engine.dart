import '../models/audio_track.dart';

enum AudioProcessingState { idle, loading, ready, completed, error }

class AudioPlaybackSnapshot {
  const AudioPlaybackSnapshot({
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

abstract interface class AudioPlaybackEngine {
  AudioPlaybackSnapshot get snapshot;
  Stream<AudioPlaybackSnapshot> get snapshotStream;

  Future<void> loadQueue(
    List<AudioTrack> tracks, {
    required int initialIndex,
    required Duration initialPosition,
  });
  Future<void> clearQueue();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> seekToIndex(int index);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> setMode(AudioPlaybackMode mode);
}
