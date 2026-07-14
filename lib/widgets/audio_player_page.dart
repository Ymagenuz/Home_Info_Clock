import 'dart:async';

import 'package:flutter/material.dart';

import '../models/audio_track.dart';
import '../services/audio_library_service.dart';
import '../state/audio_player_controller.dart';

class AudioPlayerPage extends StatelessWidget {
  const AudioPlayerPage({super.key, required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.libraryStatus == AudioLibraryStatus.empty) {
          return _AudioEmptyState(controller: controller);
        }
        if (controller.libraryStatus == AudioLibraryStatus.ready) {
          return _AudioReadyView(controller: controller);
        }
        if (controller.libraryStatus == AudioLibraryStatus.permissionDenied) {
          return _AudioPermissionState(controller: controller);
        }
        if (controller.libraryStatus == AudioLibraryStatus.error) {
          return _AudioErrorState(controller: controller);
        }
        if (controller.libraryStatus == AudioLibraryStatus.loading) {
          return const _AudioLoadingState();
        }
        return const SizedBox.expand();
      },
    );
  }
}

class _AudioLoadingState extends StatelessWidget {
  const _AudioLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: ValueKey('audio-loading-state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF64DCCC),
            ),
          ),
          SizedBox(height: 12),
          Text(
            '\u6b63\u5728\u626b\u63cf\u97f3\u9891',
            style: TextStyle(color: Color(0xBFE0F2EB), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AudioErrorState extends StatelessWidget {
  const _AudioErrorState({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('audio-error-state'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFFF885E),
            ),
            const SizedBox(height: 12),
            const Text(
              '\u65e0\u6cd5\u8bfb\u53d6\u97f3\u9891',
              style: TextStyle(
                color: Color(0xFFEEFAF6),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              controller.errorMessage ?? '\u8bf7\u91cd\u8bd5',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xAFFFFFFF), fontSize: 11),
            ),
            const SizedBox(height: 16),
            _AudioFolderActions(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _AudioPermissionState extends StatelessWidget {
  const _AudioPermissionState({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('audio-permission-state'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_open_rounded,
              size: 40,
              color: Color(0xFFFFCD5E),
            ),
            const SizedBox(height: 12),
            const Text(
              '\u9700\u8981\u8bfb\u53d6\u97f3\u9891\u6587\u4ef6',
              style: TextStyle(
                color: Color(0xFFEEFAF6),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              audioFolderPath,
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xAFFFFFFF), fontSize: 11),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('audio-grant-permission-button'),
                  onPressed: () => unawaited(controller.refreshLibrary()),
                  icon: const Icon(Icons.library_music_rounded, size: 17),
                  label: const Text('\u6388\u4e88\u97f3\u9891\u6743\u9650'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF64DCCC),
                    foregroundColor: const Color(0xFF061016),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('audio-open-folder-button'),
                  onPressed: () => unawaited(controller.openFolder()),
                  icon: const Icon(Icons.folder_open_rounded, size: 17),
                  label: const Text('\u6253\u5f00\u6587\u4ef6\u5939'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioReadyView extends StatelessWidget {
  const _AudioReadyView({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final track = controller.currentTrack ?? controller.tracks.first;
    final durationMs = controller.duration.inMilliseconds > 0
        ? controller.duration.inMilliseconds
        : track.duration.inMilliseconds;
    final maximum = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final position = controller.position.inMilliseconds
        .clamp(0, maximum.toInt())
        .toDouble();
    final playbackError = controller.errorMessage;

    return Padding(
      key: const ValueKey('audio-ready-state'),
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFEEFAF6),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                key: const ValueKey('audio-mode-button'),
                onPressed: () => unawaited(controller.cycleMode()),
                icon: Icon(_modeIcon(controller.mode), size: 16),
                label: Text(controller.mode.label),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64DCCC),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            track.artist.isEmpty ? track.displayName : track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xAFFFFFFF), fontSize: 12),
          ),
          if (playbackError != null) ...[
            const SizedBox(height: 5),
            Container(
              key: const ValueKey('audio-playback-error'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x24FF885E),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: Color(0xFFFFA47F),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      playbackError,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xDFFFF4EF),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 5),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF64DCCC),
              inactiveTrackColor: const Color(0x28FFFFFF),
              thumbColor: const Color(0xFFEEFAF6),
              overlayColor: const Color(0x2864DCCC),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              key: const ValueKey('audio-seek-slider'),
              min: 0,
              max: maximum,
              value: position,
              onChanged: (value) => unawaited(
                controller.seek(Duration(milliseconds: value.round())),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(controller.position),
                  style: const TextStyle(
                    color: Color(0x9FFFFFFF),
                    fontSize: 10,
                  ),
                ),
                Text(
                  _formatDuration(Duration(milliseconds: durationMs)),
                  style: const TextStyle(
                    color: Color(0x9FFFFFFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('audio-previous-button'),
                  tooltip: '\u4e0a\u4e00\u9996',
                  onPressed: () => unawaited(controller.skipPrevious()),
                  icon: const Icon(Icons.skip_previous_rounded),
                  color: const Color(0xDFFFFFFF),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('audio-play-pause-button'),
                  tooltip: controller.isPlaying
                      ? '\u6682\u505c'
                      : '\u64ad\u653e',
                  onPressed: () => unawaited(controller.playPause()),
                  icon: Icon(
                    controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF64DCCC),
                    foregroundColor: const Color(0xFF061016),
                    fixedSize: const Size(44, 44),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('audio-next-button'),
                  tooltip: '\u4e0b\u4e00\u9996',
                  onPressed: () => unawaited(controller.skipNext()),
                  icon: const Icon(Icons.skip_next_rounded),
                  color: const Color(0xDFFFFFFF),
                ),
              ],
            ),
          ),
          _AudioFolderActions(controller: controller),
          const SizedBox(height: 9),
          Row(
            children: [
              const Text(
                '\u64ad\u653e\u5217\u8868',
                style: TextStyle(
                  color: Color(0xCFFFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(controller.playback.currentIndex ?? 0) + 1}/${controller.tracks.length}',
                style: const TextStyle(color: Color(0x8FFFFFFF), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('audio-playlist'),
              padding: EdgeInsets.zero,
              itemCount: controller.tracks.length,
              itemExtent: 43,
              itemBuilder: (context, index) {
                final item = controller.tracks[index];
                final selected = index == controller.playback.currentIndex;
                return InkWell(
                  key: ValueKey('audio-playlist-row-$index'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => unawaited(controller.playTrack(index)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0x2264DCCC)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: selected
                              ? const Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 16,
                                  color: Color(0xFF64DCCC),
                                )
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Color(0x7FFFFFFF),
                                    fontSize: 10,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFFEEFAF6)
                                      : const Color(0xCFFFFFFF),
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              Text(
                                item.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0x7FFFFFFF),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

IconData _modeIcon(AudioPlaybackMode mode) => switch (mode) {
  AudioPlaybackMode.repeatOne => Icons.repeat_one_rounded,
  AudioPlaybackMode.sequential => Icons.format_list_numbered_rounded,
  AudioPlaybackMode.repeatAll => Icons.repeat_rounded,
  AudioPlaybackMode.shuffle => Icons.shuffle_rounded,
};

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 359999);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class _AudioEmptyState extends StatelessWidget {
  const _AudioEmptyState({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('audio-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.library_music_outlined,
              size: 42,
              color: Color(0xFF64DCCC),
            ),
            const SizedBox(height: 12),
            const Text(
              '\u6587\u4ef6\u5939\u4e2d\u8fd8\u6ca1\u6709\u97f3\u9891',
              style: TextStyle(
                color: Color(0xFFEEFAF6),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              audioFolderPath,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xBFE0F2EB),
                fontSize: 11,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            _AudioFolderActions(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _AudioFolderActions extends StatelessWidget {
  const _AudioFolderActions({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('audio-open-folder-button'),
          onPressed: () => unawaited(controller.openFolder()),
          icon: const Icon(Icons.folder_open_rounded, size: 17),
          label: const Text('\u6253\u5f00\u6587\u4ef6\u5939'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('audio-rescan-button'),
          onPressed: () => unawaited(controller.refreshLibrary()),
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('\u91cd\u65b0\u626b\u63cf'),
        ),
      ],
    );
  }
}
