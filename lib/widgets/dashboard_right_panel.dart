import 'dart:async';

import 'package:flutter/material.dart';

import '../models/weather.dart';
import 'quick_actions_panel.dart';
import 'tomorrow_panel.dart';

class DashboardRightPanel extends StatefulWidget {
  const DashboardRightPanel({
    super.key,
    required this.weather,
    required this.onRefresh,
    required this.onOpenBilibili,
  });

  final WeatherSnapshot? weather;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenBilibili;

  @override
  State<DashboardRightPanel> createState() => _DashboardRightPanelState();
}

class _DashboardRightPanelState extends State<DashboardRightPanel> {
  static const _titles = <String>[
    '\u660e\u65e5\u5929\u6c14',
    '\u5feb\u6377\u5165\u53e3',
    '\u9884\u7559\u9875',
  ];

  late final PageController _pageController = PageController();
  Timer? _resetTimer;
  var _page = 0;

  @override
  void dispose() {
    _resetTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    _resetTimer?.cancel();
    if (page == 0) return;

    _resetTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
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
              const _ReservedPage(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReservedPage extends StatelessWidget {
  const _ReservedPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u7b2c 3 \u9875',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u540e\u7eed\u53ef\u653e\u65e5\u7a0b\u3001\u5feb\u6377 App \u6216\u5bb6\u5ead\u4fe1\u606f',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xAFE0F2EB)),
            ),
          ],
        ),
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
