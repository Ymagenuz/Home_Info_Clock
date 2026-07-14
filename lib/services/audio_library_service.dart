import 'package:flutter/services.dart';

import '../models/audio_track.dart';

const audioFolderPath = '/storage/emulated/0/Music/HomeInfoClock/';

class AudioLibraryAccess {
  const AudioLibraryAccess({
    required this.audioGranted,
    this.notificationGranted = true,
  });

  final bool audioGranted;
  final bool notificationGranted;
}

abstract interface class AudioLibraryGateway {
  Future<AudioLibraryAccess> requestAccess();
  Future<List<AudioTrack>> scanTracks();
  Future<bool> openFolder();
}

class AudioLibraryService implements AudioLibraryGateway {
  const AudioLibraryService({
    this.channel = const MethodChannel('home_info_clock/platform'),
  });

  final MethodChannel channel;

  @override
  Future<AudioLibraryAccess> requestAccess() async {
    final result =
        await channel.invokeMethod<Map<Object?, Object?>>(
          'requestAudioAccess',
        ) ??
        const <Object?, Object?>{};
    return AudioLibraryAccess(
      audioGranted: result['audioGranted'] == true,
      notificationGranted: result['notificationGranted'] != false,
    );
  }

  @override
  Future<List<AudioTrack>> scanTracks() async {
    final results =
        await channel.invokeListMethod<Object?>('scanAudioFolder') ??
        const <Object?>[];
    return List<AudioTrack>.unmodifiable(
      results.whereType<Map>().map(
        (values) => AudioTrack.fromMap(Map<Object?, Object?>.from(values)),
      ),
    );
  }

  @override
  Future<bool> openFolder() async {
    return await channel.invokeMethod<bool>('openAudioFolder') ?? false;
  }
}
