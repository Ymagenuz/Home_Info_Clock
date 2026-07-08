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
        final boundedWidth = constraints.maxWidth.clamp(900.0, 1600.0);
        final leftWidth = (boundedWidth * 0.27).clamp(220.0, 360.0);
        final rightWidth = (boundedWidth * 0.31).clamp(250.0, 410.0);

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
                children: [
                  _TomorrowActionsPage(homeController: homeController),
                  const Center(child: Text('棰勭暀椤?')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TomorrowActionsPage extends StatelessWidget {
  const _TomorrowActionsPage({required this.homeController});

  final HomeController homeController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Expanded(child: TomorrowPanel(weather: homeController.weather)),
          const SizedBox(height: 14),
          const SizedBox(height: 164, child: QuickActionsPanel()),
        ],
      ),
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
