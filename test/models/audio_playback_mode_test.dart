import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/audio_track.dart';

void main() {
  test('playback modes cycle through all four user-visible behaviors', () {
    expect(AudioPlaybackMode.sequential.next, AudioPlaybackMode.repeatAll);
    expect(AudioPlaybackMode.repeatAll.next, AudioPlaybackMode.shuffle);
    expect(AudioPlaybackMode.shuffle.next, AudioPlaybackMode.repeatOne);
    expect(AudioPlaybackMode.repeatOne.next, AudioPlaybackMode.sequential);
  });

  test('AudioTrack parses the MediaStore channel payload', () {
    final track = AudioTrack.fromMap(const <String, Object?>{
      'uri': 'content://media/external/audio/media/42',
      'displayName': '02 - Night Drive.m4a',
      'title': 'Night Drive',
      'artist': 'Clock Radio',
      'durationMs': 125000,
      'mimeType': 'audio/mp4',
    });

    expect(track.uri, 'content://media/external/audio/media/42');
    expect(track.displayName, '02 - Night Drive.m4a');
    expect(track.title, 'Night Drive');
    expect(track.artist, 'Clock Radio');
    expect(track.duration, const Duration(seconds: 125));
    expect(track.mimeType, 'audio/mp4');
  });

  test('audio tracks use case-insensitive natural filename order', () {
    final sorted = sortAudioTracksByDisplayName(<AudioTrack>[
      _track('Track 10.mp3'),
      _track('track 2.mp3'),
      _track('Track 01.mp3'),
    ]);

    expect(sorted.map((track) => track.displayName), <String>[
      'Track 01.mp3',
      'track 2.mp3',
      'Track 10.mp3',
    ]);
  });
}

AudioTrack _track(String name) {
  return AudioTrack(
    uri: 'content://media/$name',
    displayName: name,
    title: name,
    artist: '',
    duration: const Duration(minutes: 1),
    mimeType: 'audio/mpeg',
  );
}
