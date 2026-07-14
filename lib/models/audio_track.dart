enum AudioPlaybackMode { repeatOne, sequential, repeatAll, shuffle }

extension AudioPlaybackModeBehavior on AudioPlaybackMode {
  AudioPlaybackMode get next => switch (this) {
    AudioPlaybackMode.repeatOne => AudioPlaybackMode.sequential,
    AudioPlaybackMode.sequential => AudioPlaybackMode.repeatAll,
    AudioPlaybackMode.repeatAll => AudioPlaybackMode.shuffle,
    AudioPlaybackMode.shuffle => AudioPlaybackMode.repeatOne,
  };

  String get label => switch (this) {
    AudioPlaybackMode.repeatOne => '\u5355\u66f2\u5faa\u73af',
    AudioPlaybackMode.sequential => '\u987a\u5e8f\u64ad\u653e',
    AudioPlaybackMode.repeatAll => '\u5217\u8868\u5faa\u73af',
    AudioPlaybackMode.shuffle => '\u968f\u673a\u64ad\u653e',
  };
}

class AudioTrack {
  const AudioTrack({
    required this.uri,
    required this.displayName,
    required this.title,
    required this.artist,
    required this.duration,
    required this.mimeType,
  });

  factory AudioTrack.fromMap(Map<Object?, Object?> values) {
    final durationMs = values['durationMs'];
    return AudioTrack(
      uri: values['uri'] as String,
      displayName: values['displayName'] as String,
      title: values['title'] as String,
      artist: values['artist'] as String,
      duration: Duration(
        milliseconds: durationMs is num ? durationMs.toInt() : 0,
      ),
      mimeType: values['mimeType'] as String,
    );
  }

  final String uri;
  final String displayName;
  final String title;
  final String artist;
  final Duration duration;
  final String mimeType;
}

List<AudioTrack> sortAudioTracksByDisplayName(Iterable<AudioTrack> tracks) {
  final sorted = tracks.toList()
    ..sort(
      (left, right) => _compareNatural(left.displayName, right.displayName),
    );
  return List<AudioTrack>.unmodifiable(sorted);
}

int _compareNatural(String left, String right) {
  final leftParts = RegExp(
    r'\d+|\D+',
  ).allMatches(left).map((m) => m[0]!).toList();
  final rightParts = RegExp(
    r'\d+|\D+',
  ).allMatches(right).map((m) => m[0]!).toList();
  final count = leftParts.length < rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < count; index += 1) {
    final leftPart = leftParts[index];
    final rightPart = rightParts[index];
    final leftNumber = int.tryParse(leftPart);
    final rightNumber = int.tryParse(rightPart);
    final comparison = leftNumber != null && rightNumber != null
        ? leftNumber.compareTo(rightNumber)
        : leftPart.toLowerCase().compareTo(rightPart.toLowerCase());
    if (comparison != 0) return comparison;
  }

  final lengthComparison = leftParts.length.compareTo(rightParts.length);
  if (lengthComparison != 0) return lengthComparison;
  final foldedComparison = left.toLowerCase().compareTo(right.toLowerCase());
  return foldedComparison != 0 ? foldedComparison : left.compareTo(right);
}
