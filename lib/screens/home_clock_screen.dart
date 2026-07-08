import 'package:flutter/material.dart';

import '../state/home_controller.dart';
import '../state/timer_controller.dart';
import '../widgets/clock_panel.dart';
import '../widgets/quick_actions_panel.dart';
import '../widgets/simple_mode_view.dart';
import '../widgets/timer_panel.dart';
import '../widgets/tomorrow_panel.dart';
import '../widgets/weather_panel.dart';

class HomeClockScreen extends StatelessWidget {
  const HomeClockScreen({
    super.key,
    required this.homeController,
    required this.timerController,
  });

  final HomeController homeController;
  final TimerController timerController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([homeController, timerController]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF061016),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              child: homeController.isSimpleMode
                  ? SimpleModeView(
                      key: const ValueKey('simple'),
                      weather: homeController.weather,
                      onToggleMode: homeController.toggleSimpleMode,
                    )
                  : _FullDashboard(
                      key: const ValueKey('full'),
                      homeController: homeController,
                      timerController: timerController,
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
  });

  final HomeController homeController;
  final TimerController timerController;

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
              ),
            ),
            const _Separator(),
            Expanded(
              child: PageView(
                key: const ValueKey('home-center-page-view'),
                children: [
                  ClockPanel(onToggleMode: homeController.toggleSimpleMode),
                  TimerPanel(controller: timerController),
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
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: QuickActionsPanel(),
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
