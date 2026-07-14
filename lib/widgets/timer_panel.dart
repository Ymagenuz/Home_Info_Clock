import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/timer_state.dart';
import '../painters/timer_painter.dart';
import '../state/timer_controller.dart';
import 'timer_countdown_rings.dart';

class TimerPanel extends StatefulWidget {
  const TimerPanel({
    super.key,
    required this.controller,
    required this.now,
    this.onAdjustingChanged,
    this.frameTime,
  });

  final TimerController controller;
  final DateTime now;
  final ValueChanged<bool>? onAdjustingChanged;
  final ValueListenable<DateTime>? frameTime;

  @override
  State<TimerPanel> createState() => _TimerPanelState();
}

class _TimerPanelState extends State<TimerPanel> with TickerProviderStateMixin {
  TimerUnit? _activeUnit;
  TimerUnit? _fadingUnit;
  double _lastAngle = 0;
  double _continuousValue = 0;
  double _fadingValue = 0;
  double _accumulatedAngle = 0;
  bool _isAdjusting = false;
  bool _rotationStarted = false;
  int? _primaryAdjustmentPointer;
  final Set<int> _adjustmentPointers = <int>{};
  _TimerPanelGeometry? _geometry;
  late final AnimationController _arrowFadeInController;
  late final AnimationController _arrowFadeOutController;
  late final AnimationController _valueFadeController;

  @override
  void initState() {
    super.initState();
    _arrowFadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _arrowFadeOutController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _valueFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addStatusListener(_handleValueFadeStatus);
  }

  @override
  void dispose() {
    final wasAdjusting = _adjustmentPointers.isNotEmpty;
    _adjustmentPointers.clear();
    _primaryAdjustmentPointer = null;
    _activeUnit = null;
    _fadingUnit = null;
    _isAdjusting = false;
    _geometry = null;
    _valueFadeController.removeStatusListener(_handleValueFadeStatus);
    _arrowFadeInController.dispose();
    _arrowFadeOutController.dispose();
    _valueFadeController.dispose();
    if (wasAdjusting) {
      final onAdjustingChanged = widget.onAdjustingChanged;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAdjustingChanged?.call(false);
      });
    }
    super.dispose();
  }

  void _handleValueFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _fadingUnit = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final now = widget.now;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _TimerPanelGeometry.fromSize(constraints.biggest);
        _geometry = geometry;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final state = controller.state;
            final units = state.unitsAt(now);
            final displayUnit = _activeUnit ?? _fadingUnit;
            final displayValue = _activeUnit != null
                ? _continuousValue
                : _fadingValue;
            final Animation<double> highlightOpacity = _activeUnit != null
                ? const AlwaysStoppedAnimation<double>(1)
                : _fadingUnit != null
                ? ReverseAnimation(_valueFadeController)
                : const AlwaysStoppedAnimation<double>(0);
            final Animation<double> arrowOpacity = _rotationStarted
                ? ReverseAnimation(_arrowFadeOutController)
                : _arrowFadeInController;
            return Listener(
              key: const ValueKey('timer-adjustment-surface'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: _handleAdjustmentPointerDown,
              onPointerMove: _handleAdjustmentPointerMove,
              onPointerUp: _handleAdjustmentPointerEnd,
              onPointerCancel: _handleAdjustmentPointerEnd,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('timer-dial-paint'),
                        painter: TimerPainter(
                          state: state,
                          now: now,
                          center: geometry.center,
                          radius: geometry.radius,
                          displayUnit: displayUnit,
                          displayValue: displayValue,
                          highlightOpacity: highlightOpacity,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: TimerCountdownRings(
                        controller: controller,
                        now: now,
                        center: geometry.center,
                        radius: geometry.radius,
                        keyPrefix: 'timer',
                        onTimerPage: true,
                        frameTime: widget.frameTime,
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: geometry.dialRect,
                    child: IgnorePointer(
                      child: SizedBox.expand(
                        key: const ValueKey('timer-adjustment-dial'),
                      ),
                    ),
                  ),
                  if (_isAdjusting)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FadeTransition(
                          key: const ValueKey('timer-rotation-guidance'),
                          opacity: arrowOpacity,
                          child: CustomPaint(
                            painter: TimerRotationGuidancePainter(
                              center: geometry.center,
                              radius: geometry.radius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (displayUnit != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FadeTransition(
                          key: const ValueKey('timer-tick-value'),
                          opacity: highlightOpacity,
                          child: CustomPaint(
                            painter: TimerTickValuePainter(
                              center: geometry.center,
                              radius: geometry.radius,
                              unit: displayUnit,
                              value: displayValue,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fromRect(
                    rect: geometry.hourButtonRect,
                    child: IgnorePointer(
                      child: _UnitControl(
                        label: '时',
                        value: _twoDigits(units.hours),
                        selectKey: const ValueKey('timer-hour-select'),
                        color: _timerUnitColor(TimerUnit.hours),
                        selected:
                            !state.isRunning && _activeUnit == TimerUnit.hours,
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: geometry.minuteButtonRect,
                    child: IgnorePointer(
                      child: _UnitControl(
                        label: '分',
                        value: _twoDigits(units.minutes),
                        selectKey: const ValueKey('timer-minute-select'),
                        color: _timerUnitColor(TimerUnit.minutes),
                        selected:
                            !state.isRunning &&
                            _activeUnit == TimerUnit.minutes,
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: geometry.secondButtonRect,
                    child: IgnorePointer(
                      child: _UnitControl(
                        label: '秒',
                        value: _twoDigits(units.seconds),
                        selectKey: const ValueKey('timer-second-select'),
                        color: _timerUnitColor(TimerUnit.seconds),
                        selected:
                            !state.isRunning &&
                            _activeUnit == TimerUnit.seconds,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: geometry.titleCenterY - 11,
                    height: 22,
                    child: const IgnorePointer(
                      child: Center(
                        child: Text(
                          '定时器',
                          style: TextStyle(
                            color: Color(0xBEE0F2EB),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: geometry.startButtonRect,
                    child: _TimerStartButton(
                      key: const ValueKey('timer-start'),
                      isRunning: state.isRunning,
                      units: units,
                      enabled: state.isRunning || state.totalSeconds > 0,
                      onTap: () => controller.startOrClear(now),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleAdjustmentPointerMove(PointerMoveEvent event) {
    final unit = _activeUnit;
    final geometry = _geometry;
    if (!_isAdjusting ||
        unit == null ||
        geometry == null ||
        event.pointer != _primaryAdjustmentPointer) {
      return;
    }
    final angle = _angleFor(event.localPosition, geometry.center);
    var delta = angle - _lastAngle;
    if (delta > math.pi) delta -= math.pi * 2;
    if (delta < -math.pi) delta += math.pi * 2;
    _lastAngle = angle;
    _accumulatedAngle += delta;
    if (!_rotationStarted && _accumulatedAngle.abs() > 4 * math.pi / 180) {
      setState(() => _rotationStarted = true);
      _arrowFadeOutController.forward(from: 0);
    }
    final steps = unit == TimerUnit.hours ? 12 : 60;
    _continuousValue = (_continuousValue + delta / (math.pi * 2 / steps)).clamp(
      0.0,
      (steps - 1).toDouble(),
    );
    widget.controller.setUnit(unit, _continuousValue.round());
  }

  void _finishAdjustment() {
    if (!_isAdjusting && _activeUnit == null) return;
    final fadingUnit = _activeUnit;
    final fadingValue = _continuousValue;
    _arrowFadeInController.stop();
    _arrowFadeOutController.stop();
    setState(() {
      _isAdjusting = false;
      _fadingUnit = fadingUnit;
      _fadingValue = fadingValue;
      _activeUnit = null;
      _primaryAdjustmentPointer = null;
      _continuousValue = 0;
      _accumulatedAngle = 0;
      _rotationStarted = false;
    });
    if (fadingUnit != null) {
      _valueFadeController.forward(from: 0);
    }
  }

  void _handleAdjustmentPointerDown(PointerDownEvent event) {
    final geometry = _geometry;
    if (geometry == null || widget.controller.state.isRunning) return;

    if (_adjustmentPointers.isNotEmpty) {
      if (geometry.containsDial(event.localPosition)) {
        _adjustmentPointers.add(event.pointer);
      }
      return;
    }

    final unit = geometry.unitAt(event.localPosition);
    if (unit == null || !_adjustmentPointers.add(event.pointer)) return;

    final angle = _angleFor(event.localPosition, geometry.center);
    final steps = unit == TimerUnit.hours ? 12 : 60;
    final continuousValue = (angle / (math.pi * 2 / steps)).clamp(
      0.0,
      (steps - 1).toDouble(),
    );
    _valueFadeController.stop();
    _valueFadeController.value = 0;
    _arrowFadeOutController.stop();
    _arrowFadeOutController.value = 0;
    setState(() {
      _activeUnit = unit;
      _fadingUnit = null;
      _isAdjusting = true;
      _rotationStarted = false;
      _primaryAdjustmentPointer = event.pointer;
      _lastAngle = angle;
      _continuousValue = continuousValue;
      _accumulatedAngle = 0;
    });
    _arrowFadeInController.forward(from: 0);
    widget.onAdjustingChanged?.call(true);
    widget.controller.setUnit(unit, continuousValue.round());
  }

  void _handleAdjustmentPointerEnd(PointerEvent event) {
    if (!_adjustmentPointers.remove(event.pointer)) {
      return;
    }
    if (event.pointer == _primaryAdjustmentPointer) {
      _finishAdjustment();
    }
    if (_adjustmentPointers.isEmpty) {
      widget.onAdjustingChanged?.call(false);
    }
  }

  double _angleFor(Offset position, Offset center) {
    var angle =
        math.atan2(position.dy - center.dy, position.dx - center.dx) +
        math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    if (angle >= math.pi * 2) angle -= math.pi * 2;
    return angle;
  }
}

class _UnitControl extends StatelessWidget {
  const _UnitControl({
    required this.label,
    required this.value,
    required this.selectKey,
    required this.color,
    required this.selected,
  });

  final String label;
  final String value;
  final Key selectKey;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '调整$label',
      value: value,
      child: SizedBox.expand(
        key: selectKey,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: selected ? color.withAlpha(78) : const Color(0x1CFFFFFF),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: selected
                    ? color.withAlpha(210)
                    : const Color(0x26FFFFFF),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFEEFAF6),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : const Color(0xAAE0F2EB),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerStartButton extends StatelessWidget {
  const _TimerStartButton({
    super.key,
    required this.isRunning,
    required this.units,
    required this.enabled,
    required this.onTap,
  });

  final bool isRunning;
  final TimerUnits units;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isRunning
        ? const Color(0xFFFF885E)
        : enabled
        ? const Color(0xFF64DCCD)
        : const Color(0xAAE0F2EB);
    final fill = isRunning
        ? const Color(0x2EFF885E)
        : enabled
        ? const Color(0x2664DCCD)
        : const Color(0x16FFFFFF);
    final border = isRunning
        ? const Color(0x87FF885E)
        : enabled
        ? const Color(0x8264DCCD)
        : const Color(0x2AFFFFFF);
    final label = isRunning
        ? '清零'
        : enabled
        ? '开始 ${_twoDigits(units.hours)}:${_twoDigits(units.minutes)}:${_twoDigits(units.seconds)}'
        : '开始';

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: fill,
        shape: StadiumBorder(side: BorderSide(color: border, width: 1.2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerPanelGeometry {
  const _TimerPanelGeometry({
    required this.dialRect,
    required this.hourButtonRect,
    required this.minuteButtonRect,
    required this.secondButtonRect,
    required this.startButtonRect,
    required this.titleCenterY,
  });

  factory _TimerPanelGeometry.fromSize(Size size) {
    final radius = math.min(size.width * 0.37, size.height * 0.36);
    final center = Offset(
      size.width * 0.5,
      math.max(radius + 12, size.height * 0.36),
    );
    final buttonWidth = math.min(78.0, radius * 0.54);
    const buttonHeight = 48.0;
    const gap = 10.0;
    final totalWidth = buttonWidth * 3 + gap * 2;
    final firstLeft = center.dx - totalWidth * 0.5;
    final buttonTop = center.dy - buttonHeight * 0.5;
    final startWidth = math.min(size.width * 0.48, 190.0);
    const startHeight = 50.0;
    final startCenter = Offset(size.width * 0.5, size.height - 37);

    Rect buttonRect(double left) =>
        Rect.fromLTWH(left, buttonTop, buttonWidth, buttonHeight);

    return _TimerPanelGeometry(
      dialRect: Rect.fromCircle(center: center, radius: radius),
      hourButtonRect: buttonRect(firstLeft),
      minuteButtonRect: buttonRect(firstLeft + buttonWidth + gap),
      secondButtonRect: buttonRect(firstLeft + (buttonWidth + gap) * 2),
      startButtonRect: Rect.fromCenter(
        center: startCenter,
        width: startWidth,
        height: startHeight,
      ),
      titleCenterY: size.height - 78,
    );
  }

  final Rect dialRect;
  final Rect hourButtonRect;
  final Rect minuteButtonRect;
  final Rect secondButtonRect;
  final Rect startButtonRect;
  final double titleCenterY;

  Offset get center => dialRect.center;
  double get radius => dialRect.width * 0.5;

  TimerUnit? unitAt(Offset position) {
    if (hourButtonRect.contains(position)) return TimerUnit.hours;
    if (minuteButtonRect.contains(position)) return TimerUnit.minutes;
    if (secondButtonRect.contains(position)) return TimerUnit.seconds;
    return null;
  }

  bool containsDial(Offset position) {
    return (position - center).distance <= dialRect.width * 0.5 + 1;
  }
}

Color _timerUnitColor(TimerUnit unit) {
  return switch (unit) {
    TimerUnit.hours => const Color(0xFFFFCD5E),
    TimerUnit.minutes => const Color(0xFF64DCCD),
    TimerUnit.seconds => const Color(0xFFFF885E),
  };
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
