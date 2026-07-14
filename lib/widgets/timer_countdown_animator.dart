import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/timer_state.dart';
import '../state/timer_controller.dart';

typedef TimerCountdownVisualBuilder =
    Widget Function(BuildContext context, TimerCountdownVisual visual);

class TimerCountdownAnimator extends StatefulWidget {
  const TimerCountdownAnimator({
    super.key,
    required this.controller,
    required this.now,
    required this.builder,
    this.frameTime,
  });

  final TimerController controller;
  final DateTime now;
  final TimerCountdownVisualBuilder builder;
  final ValueListenable<DateTime>? frameTime;

  @override
  State<TimerCountdownAnimator> createState() => _TimerCountdownAnimatorState();
}

class _TimerCountdownAnimatorState extends State<TimerCountdownAnimator>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _parentDropController;
  late final Animation<double> _entranceOpacity;
  late final Listenable _repaint;
  late bool _isRunning;
  late TimerUnits _units;
  bool _animateHourDrop = false;
  bool _animateMinuteDrop = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _parentDropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _entranceOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeInOutCubic,
    );
    _repaint = Listenable.merge([_entranceController, _parentDropController]);
    _isRunning = widget.controller.state.isRunning;
    _units = widget.controller.state.unitsAt(widget.now);
    if (_isRunning) _entranceController.value = 1;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TimerCountdownAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _isRunning = widget.controller.state.isRunning;
      _entranceController.value = _isRunning ? 1 : 0;
      _parentDropController.value = 0;
      _animateHourDrop = false;
      _animateMinuteDrop = false;
    }
    final nextUnits = widget.controller.state.unitsAt(widget.now);
    if (_isRunning && nextUnits != _units) {
      _startParentDrop(_units, nextUnits);
    }
    _units = nextUnits;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _entranceController.dispose();
    _parentDropController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final nextRunning = widget.controller.state.isRunning;
    final nextUnits = widget.controller.state.unitsAt(widget.now);
    if (nextRunning == _isRunning && nextUnits == _units) return;

    setState(() {
      _isRunning = nextRunning;
      _units = nextUnits;
      _animateHourDrop = false;
      _animateMinuteDrop = false;
    });
    if (nextRunning && !_entranceController.isAnimating) {
      _parentDropController.stop();
      _parentDropController.value = 0;
      _entranceController.forward(from: 0);
    } else if (!nextRunning) {
      _entranceController.stop();
      _entranceController.value = 0;
      _parentDropController.stop();
      _parentDropController.value = 0;
    }
  }

  void _startParentDrop(TimerUnits previous, TimerUnits next) {
    final hourDrop = next.hours < previous.hours;
    final minuteDrop = next.minutes < previous.minutes;
    if (!hourDrop && !minuteDrop) return;

    _animateHourDrop = hourDrop;
    _animateMinuteDrop = minuteDrop;
    _parentDropController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      TimerCountdownVisual(
        isRunning: _isRunning,
        units: _units,
        entranceOpacity: _entranceOpacity,
        parentDropProgress: _parentDropController,
        animateHourDrop: _animateHourDrop,
        animateMinuteDrop: _animateMinuteDrop,
        repaint: _repaint,
        timerState: widget.controller.state,
        frameTime: widget.frameTime,
      ),
    );
  }
}

class TimerCountdownVisual {
  const TimerCountdownVisual({
    required this.isRunning,
    required this.units,
    required this.entranceOpacity,
    required this.parentDropProgress,
    required this.animateHourDrop,
    required this.animateMinuteDrop,
    required this.repaint,
    required this.timerState,
    required this.frameTime,
  });

  final bool isRunning;
  final TimerUnits units;
  final Animation<double> entranceOpacity;
  final Animation<double> parentDropProgress;
  final bool animateHourDrop;
  final bool animateMinuteDrop;
  final Listenable repaint;
  final TimerState timerState;
  final ValueListenable<DateTime>? frameTime;

  double valueFor(TimerUnit unit) {
    if (unit == TimerUnit.seconds && isRunning && frameTime != null) {
      final remaining = timerState.remainingAt(frameTime!.value);
      final microseconds = remaining.inMicroseconds;
      if (microseconds <= 0) return 0;
      final totalSeconds =
          microseconds / Duration.microsecondsPerSecond;
      final seconds = totalSeconds % 60;
      return seconds <= 0.000001 ? 60 : seconds;
    }

    final base = switch (unit) {
      TimerUnit.hours => units.hours.toDouble(),
      TimerUnit.minutes => units.minutes.toDouble(),
      TimerUnit.seconds => units.seconds.toDouble(),
    };
    final isParentDrop = switch (unit) {
      TimerUnit.hours => animateHourDrop,
      TimerUnit.minutes => animateMinuteDrop,
      TimerUnit.seconds => false,
    };
    if (!isParentDrop) return base;

    final progress = parentDropProgress.value.clamp(0.0, 1.0);
    return base + 1 - progress * progress;
  }
}
