import 'dart:async';

import 'package:flutter/material.dart';

import '../state/home_controller.dart';
import '../state/timer_controller.dart';
import '../widgets/clock_panel.dart';
import '../widgets/quick_actions_panel.dart';
import '../widgets/simple_mode_view.dart';
import '../widgets/timer_panel.dart';
import '../widgets/tomorrow_panel.dart';
import '../widgets/weather_panel.dart';

class HomeClockScreen extends StatefulWidget {
  const HomeClockScreen({
    super.key,
    required this.homeController,
    required this.timerController,
    this.now = DateTime.now,
    this.tickInterval = const Duration(seconds: 1),
  });

  final HomeController homeController;
  final TimerController timerController;
  final DateTime Function() now;
  final Duration tickInterval;

  @override
  State<HomeClockScreen> createState() => _HomeClockScreenState();
}

class _HomeClockScreenState extends State<HomeClockScreen> {
  late DateTime _now;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _now = widget.now();
    widget.timerController.sync(_now);
    _ticker = Timer.periodic(widget.tickInterval, (_) {
      final next = widget.now();
      widget.timerController.sync(next);
      if (mounted) {
        setState(() => _now = next);
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.homeController,
        widget.timerController,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF061016),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: widget.homeController.isSimpleMode
                  ? SimpleModeView(
                      key: const ValueKey('simple'),
                      weather: widget.homeController.weather,
                      now: _now,
                      onToggleMode: widget.homeController.toggleSimpleMode,
                    )
                  : _FullDashboard(
                      key: const ValueKey('full'),
                      homeController: widget.homeController,
                      timerController: widget.timerController,
                      now: _now,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _FullDashboard extends StatelessWidget {
  const _FullDashboard({
    super.key,
    required this.homeController,
    required this.timerController,
    required this.now,
  });

  final HomeController homeController;
  final TimerController timerController;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final boundedWidth = width.clamp(700.0, 1600.0);
        final compact = width < 900.0;
        final leftWidth = (boundedWidth * 0.27).clamp(
          compact ? 190.0 : 220.0,
          360.0,
        );
        final rightWidth = (boundedWidth * 0.31).clamp(
          compact ? 220.0 : 250.0,
          410.0,
        );

        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: WeatherPanel(
                weather: homeController.weather,
                battery: homeController.battery,
                status: homeController.weatherStatus,
                isRefreshing: homeController.isRefreshingWeather,
                onRefresh: () => homeController.refreshWeather(force: true),
              ),
            ),
            const _Separator(),
            Expanded(
              child: PageView(
                key: const ValueKey('home-center-page-view'),
                children: [
                  ClockPanel(
                    now: now,
                    onToggleMode: homeController.toggleSimpleMode,
                  ),
                  TimerPanel(controller: timerController, now: now),
                ],
              ),
            ),
            const _Separator(),
            SizedBox(
              width: rightWidth,
              child: PageView(
                key: const ValueKey('home-right-page-view'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: TomorrowPanel(weather: homeController.weather),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: QuickActionsPanel(
                      onOpenBilibili: homeController.openBilibili,
                      onRefreshWeather: () =>
                          homeController.refreshWeather(force: true),
                    ),
                  ),
                  const Center(child: Text('\u9884\u7559\u9875')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x22FFFFFF),
      child: SizedBox(width: 1, height: double.infinity),
    );
  }
}
