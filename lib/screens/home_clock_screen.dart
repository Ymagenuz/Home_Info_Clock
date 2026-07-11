import 'dart:async';

import 'package:flutter/material.dart';

import '../models/china_region.dart';
import '../models/manual_location.dart';
import '../services/china_region_repository.dart';
import '../state/home_controller.dart';
import '../state/timer_controller.dart';
import '../widgets/clock_panel.dart';
import '../widgets/manual_location_dialog.dart';
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
    this.loadChinaRegions = _loadChinaRegions,
    this.resolveChinaLocation,
    this.resolveLocation,
  });

  final HomeController homeController;
  final TimerController timerController;
  final DateTime Function() now;
  final Duration tickInterval;
  final ChinaRegionLoader loadChinaRegions;
  final ManualLocationResolver? resolveChinaLocation;
  final ManualLocationResolver? resolveLocation;

  @override
  State<HomeClockScreen> createState() => _HomeClockScreenState();
}

Future<List<ChinaRegion>> _loadChinaRegions() {
  return const ChinaRegionRepository().load();
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
        final isTimerFinished = widget.timerController.state.isFinished;
        return Scaffold(
          backgroundColor: const Color(0xFF061016),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ExcludeFocus(
                    excluding: isTimerFinished,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: widget.homeController.isSimpleMode
                          ? SimpleModeView(
                              key: const ValueKey('simple'),
                              weather: widget.homeController.weather,
                              now: _now,
                              onToggleMode:
                                  widget.homeController.toggleSimpleMode,
                            )
                          : _FullDashboard(
                              key: const ValueKey('full'),
                              homeController: widget.homeController,
                              timerController: widget.timerController,
                              now: _now,
                              onLocationTap: _showLocationDialog,
                            ),
                    ),
                  ),
                ),
                if (isTimerFinished)
                  Positioned.fill(
                    child: _TimerFinishedOverlay(
                      onDismiss: widget.timerController.dismissFinished,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLocationDialog() async {
    final chinaResolver =
        widget.resolveChinaLocation ??
        (_) => Future<ManualLocation>.error(
          const FormatException('China location lookup is unavailable'),
        );
    final resolver =
        widget.resolveLocation ??
        (_) => Future<ManualLocation>.error(
          StateError('AI location parsing is not configured'),
        );
    final selected = await showDialog<ManualLocation>(
      context: context,
      builder: (context) => ManualLocationDialog(
        currentLabel: widget.homeController.locationLabel,
        loadRegions: widget.loadChinaRegions,
        resolveChinaLocation: chinaResolver,
        resolveLocation: resolver,
      ),
    );
    if (!mounted || selected == null) return;
    await widget.homeController.selectLocation(selected);
  }
}

class _TimerFinishedOverlay extends StatefulWidget {
  const _TimerFinishedOverlay({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_TimerFinishedOverlay> createState() => _TimerFinishedOverlayState();
}

class _TimerFinishedOverlayState extends State<_TimerFinishedOverlay> {
  late final FocusNode _dismissFocusNode = FocusNode(
    debugLabel: 'Timer finished dismiss',
  );

  @override
  void dispose() {
    _dismissFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        scopesRoute: true,
        namesRoute: true,
        liveRegion: true,
        label: 'Timer finished',
        child: FocusScope(
          debugLabel: 'Timer finished overlay',
          child: Material(
            key: const ValueKey('timer-finished-overlay'),
            color: const Color(0xE6061016),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF17252D),
                      border: Border.all(color: const Color(0x6693E5AB)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 48,
                            color: Color(0xFF93E5AB),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Timer finished',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            key: const ValueKey('timer-finished-dismiss'),
                            focusNode: _dismissFocusNode,
                            autofocus: true,
                            onPressed: widget.onDismiss,
                            icon: const Icon(Icons.check),
                            label: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullDashboard extends StatelessWidget {
  const _FullDashboard({
    super.key,
    required this.homeController,
    required this.timerController,
    required this.now,
    required this.onLocationTap,
  });

  final HomeController homeController;
  final TimerController timerController;
  final DateTime now;
  final VoidCallback onLocationTap;

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
                locationLabel: homeController.locationLabel,
                battery: homeController.battery,
                status: homeController.weatherStatus,
                isRefreshing: homeController.isRefreshingWeather,
                onRefresh: () => homeController.refreshWeather(force: true),
                onLocationTap: onLocationTap,
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
