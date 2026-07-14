import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/china_region.dart';
import '../models/manual_location.dart';
import '../painters/timer_finished_bell_painter.dart';
import '../services/china_region_repository.dart';
import '../state/home_controller.dart';
import '../state/audio_player_controller.dart';
import '../state/timer_controller.dart';
import '../widgets/clock_panel.dart';
import '../widgets/dashboard_right_panel.dart';
import '../widgets/manual_location_dialog.dart';
import '../widgets/simple_mode_view.dart';
import '../widgets/timer_panel.dart';
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
    this.audioController,
  });

  final HomeController homeController;
  final TimerController timerController;
  final DateTime Function() now;
  final Duration tickInterval;
  final ChinaRegionLoader loadChinaRegions;
  final ManualLocationResolver? resolveChinaLocation;
  final ManualLocationResolver? resolveLocation;
  final AudioPlayerController? audioController;

  @override
  State<HomeClockScreen> createState() => _HomeClockScreenState();
}

Future<List<ChinaRegion>> _loadChinaRegions() {
  return const ChinaRegionRepository().load();
}

class _HomeClockScreenState extends State<HomeClockScreen>
    with SingleTickerProviderStateMixin {
  late final Timer _ticker;
  late final ValueNotifier<DateTime> _secondTime;
  late final ValueNotifier<DateTime> _frameTime;
  late final AnimationController _frameController;
  bool _isTimerAdjusting = false;

  @override
  void initState() {
    super.initState();
    final now = widget.now();
    _secondTime = ValueNotifier<DateTime>(now);
    _frameTime = ValueNotifier<DateTime>(now);
    _frameController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_updateFrameTime)
          ..repeat();
    widget.timerController.sync(now);
    _ticker = Timer.periodic(widget.tickInterval, (_) {
      final next = widget.now();
      widget.timerController.sync(next);
      _secondTime.value = next;
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _frameController.dispose();
    _frameTime.dispose();
    _secondTime.dispose();
    super.dispose();
  }

  void _updateFrameTime() {
    _frameTime.value = widget.now();
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
          body: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  child: ExcludeFocus(
                    excluding: isTimerFinished,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: const Interval(
                        0.5,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                      switchOutCurve: const Interval(
                        0.5,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                      child: widget.homeController.isSimpleMode
                          ? ValueListenableBuilder<DateTime>(
                              key: const ValueKey('simple'),
                              valueListenable: _secondTime,
                              builder: (context, now, _) => SimpleModeView(
                                weather: widget.homeController.weather,
                                battery: widget.homeController.battery,
                                now: now,
                                timerController: widget.timerController,
                                frameTime: _frameTime,
                                onToggleMode:
                                    widget.homeController.toggleSimpleMode,
                              ),
                            )
                          : _FullDashboard(
                              key: const ValueKey('full'),
                              homeController: widget.homeController,
                              timerController: widget.timerController,
                              secondTime: _secondTime,
                              frameTime: _frameTime,
                              onLocationTap: _showLocationDialog,
                              isTimerAdjusting: _isTimerAdjusting,
                              onTimerAdjustingChanged:
                                  _handleTimerAdjustingChanged,
                              audioController: widget.audioController,
                            ),
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
        );
      },
    );
  }

  void _handleTimerAdjustingChanged(bool value) {
    if (!mounted || _isTimerAdjusting == value) {
      return;
    }
    setState(() => _isTimerAdjusting = value);
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

class _TimerFinishedOverlayState extends State<_TimerFinishedOverlay>
    with SingleTickerProviderStateMixin {
  late final FocusNode _dismissFocusNode = FocusNode(
    debugLabel: 'Timer finished dismiss',
  );
  late final AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _dismissFocusNode.addListener(_handleFocusChanged);
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1620),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    _dismissFocusNode.removeListener(_handleFocusChanged);
    _dismissFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
        label: '时间到',
        child: FocusScope(
          debugLabel: 'Timer finished overlay',
          child: Material(
            key: const ValueKey('timer-finished-overlay'),
            color: Colors.black,
            child: Focus(
              focusNode: _dismissFocusNode,
              autofocus: true,
              onKeyEvent: _handleKeyEvent,
              child: Semantics(
                button: true,
                focusable: true,
                focused: _dismissFocusNode.hasFocus,
                label: '关闭时间到提醒',
                onTap: widget.onDismiss,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('timer-finished-dismiss'),
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: widget.onDismiss,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final centerX = width * 0.5;
                      final centerY = height * 0.44;
                      return Stack(
                        children: [
                          Positioned(
                            left: centerX - 60,
                            top: centerY - 102,
                            width: 120,
                            height: 120,
                            child: AnimatedBuilder(
                              animation: _motionController,
                              builder: (context, child) {
                                final motion =
                                    TimerFinishedMotion.fromCycleProgress(
                                      _motionController.value,
                                    );
                                return Transform(
                                  key: const ValueKey(
                                    'timer-finished-bell-motion',
                                  ),
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateZ(motion.radians)
                                    ..scaleByDouble(
                                      motion.scale,
                                      motion.scale,
                                      1,
                                      1,
                                    ),
                                  child: child,
                                );
                              },
                              child: const CustomPaint(
                                key: ValueKey('timer-finished-bell'),
                                painter: TimerFinishedBellPainter(),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: centerY + 28,
                            height: 52,
                            child: const Center(
                              child: Text(
                                '时间到',
                                style: TextStyle(
                                  color: Color(0xFFEEFAF6),
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: centerY + 87,
                            height: 18,
                            child: const Center(
                              child: Text(
                                '轻触屏幕关闭',
                                style: TextStyle(
                                  color: Color(0xAAE0F2EB),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
    required this.secondTime,
    required this.frameTime,
    required this.onLocationTap,
    required this.isTimerAdjusting,
    required this.onTimerAdjustingChanged,
    this.audioController,
  });

  final HomeController homeController;
  final TimerController timerController;
  final ValueListenable<DateTime> secondTime;
  final ValueListenable<DateTime> frameTime;
  final VoidCallback onLocationTap;
  final bool isTimerAdjusting;
  final ValueChanged<bool> onTimerAdjustingChanged;
  final AudioPlayerController? audioController;

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
              child: ValueListenableBuilder<DateTime>(
                valueListenable: secondTime,
                builder: (context, now, _) => PageView(
                  key: const ValueKey('home-center-page-view'),
                  physics: isTimerAdjusting
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  children: [
                    ClockPanel(
                      now: now,
                      frameTime: frameTime,
                      timerController: timerController,
                      onToggleMode: homeController.toggleSimpleMode,
                    ),
                    TimerPanel(
                      controller: timerController,
                      now: now,
                      frameTime: frameTime,
                      onAdjustingChanged: onTimerAdjustingChanged,
                    ),
                  ],
                ),
              ),
            ),
            const _Separator(),
            SizedBox(
              width: rightWidth,
              child: DashboardRightPanel(
                weather: homeController.weather,
                onRefresh: () => homeController.refreshWeather(force: true),
                audioController: audioController,
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
