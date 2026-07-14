import 'dart:async';

import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../state/audio_player_controller.dart';
import 'audio_player_page.dart';
import 'quick_actions_panel.dart';
import 'tomorrow_panel.dart';

class DashboardRightPanel extends StatefulWidget {
  const DashboardRightPanel({
    super.key,
    required this.weather,
    required this.onRefresh,
    required this.onOpenBilibili,
    this.audioController,
  });

  final WeatherSnapshot? weather;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenBilibili;
  final AudioPlayerController? audioController;

  @override
  State<DashboardRightPanel> createState() => _DashboardRightPanelState();
}

class _DashboardRightPanelState extends State<DashboardRightPanel> {
  static const _titles = <String>[
    '\u660e\u65e5\u5929\u6c14',
    '\u5feb\u6377\u5165\u53e3',
    '\u97f3\u9891\u64ad\u653e\u5668',
  ];

  late final PageController _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    if (page == 2) {
      final audioController = widget.audioController;
      if (audioController != null) {
        unawaited(audioController.refreshLibrary());
      }
    }
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
                _PageIndicator(page: _page),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView(
            key: const ValueKey('home-right-page-view'),
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            children: [
              TomorrowPanel(
                weather: widget.weather,
                onRefresh: widget.onRefresh,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: QuickActionsPanel(onOpenBilibili: widget.onOpenBilibili),
              ),
              if (widget.audioController case final audioController?)
                AudioPlayerPage(controller: audioController)
              else
                const _AudioUnavailablePage(),
            ],
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('dashboard-right-page-indicator'),
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final selected = index == page;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            key: ValueKey(
              'dashboard-right-page-dot-$index-${selected ? 'active' : 'inactive'}',
            ),
            duration: const Duration(milliseconds: 180),
            width: selected ? 8 : 6,
            height: selected ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? const Color(0xFF64DCCC)
                  : const Color(0x5FFFFFFF),
            ),
          ),
        );
      }),
    );
  }
}
