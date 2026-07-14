import 'dart:async';

import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../state/audio_player_controller.dart';
import 'audio_player_page.dart';
import 'tomorrow_panel.dart';

class DashboardRightPanel extends StatefulWidget {
  const DashboardRightPanel({
    super.key,
    required this.weather,
    required this.onRefresh,
    this.audioController,
  });

  final WeatherSnapshot? weather;
  final Future<void> Function() onRefresh;
  final AudioPlayerController? audioController;

  @override
  State<DashboardRightPanel> createState() => _DashboardRightPanelState();
}

class _DashboardRightPanelState extends State<DashboardRightPanel> {
  static const _titles = <String>[
    '\u660e\u65e5\u5929\u6c14',
    '\u97f3\u9891\u64ad\u653e\u5668',
  ];

  late final PageController _pageController = PageController();
  var _page = 0;
  var _refreshAudioWhenSettled = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    _refreshAudioWhenSettled = page == 1;
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal ||
        !_refreshAudioWhenSettled) {
      return false;
    }

    _refreshAudioWhenSettled = false;
    final audioController = widget.audioController;
    if (audioController != null) {
      unawaited(audioController.refreshLibrary());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          key: const ValueKey('dashboard-right-header'),
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _titles[_page],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: const Color(0xBFE0F2EB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: _handleScrollEnd,
            child: PageView(
              key: const ValueKey('home-right-page-view'),
              controller: _pageController,
              onPageChanged: _handlePageChanged,
              children: [
                TomorrowPanel(
                  weather: widget.weather,
                  onRefresh: widget.onRefresh,
                ),
                if (widget.audioController case final audioController?)
                  AudioPlayerPage(controller: audioController)
                else
                  const _AudioUnavailablePage(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AudioUnavailablePage extends StatelessWidget {
  const _AudioUnavailablePage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '\u97f3\u9891\u64ad\u653e\u5668\u672a\u8fde\u63a5',
        style: TextStyle(color: Color(0xAFE0F2EB), fontSize: 12),
      ),
    );
  }
}
