import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/timer_controller.dart';
import '../widgets/timer_countdown_animator.dart';
import 'timer_painter.dart';

class TimerCountdownUnitPainter extends CustomPainter {
  TimerCountdownUnitPainter({
    required this.visual,
    required this.unit,
    required this.center,
    required this.radius,
    required this.onTimerPage,
  }) : super(
         repaint: Listenable.merge([
           visual.repaint,
           if (unit == TimerUnit.seconds) visual.frameTime,
         ]),
       );

  final TimerCountdownVisual visual;
  final TimerUnit unit;
  final Offset center;
  final double radius;
  final bool onTimerPage;

  double get value => visual.valueFor(unit);

  @override
  void paint(Canvas canvas, Size size) {
    paintTimerCountdownUnit(
      canvas,
      center: center,
      radius: radius,
      onTimerPage: onTimerPage,
      unit: unit,
      value: value,
    );
  }

  @override
  bool shouldRepaint(covariant TimerCountdownUnitPainter oldDelegate) {
    return oldDelegate.visual != visual ||
        oldDelegate.unit != unit ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.onTimerPage != onTimerPage;
  }
}

void paintTimerCountdownRings(
  Canvas canvas, {
  required TimerCountdownVisual visual,
  required Offset center,
  required double radius,
  required bool onTimerPage,
  double opacity = 1,
}) {
  for (final unit in TimerUnit.values) {
    paintTimerCountdownUnit(
      canvas,
      center: center,
      radius: radius,
      onTimerPage: onTimerPage,
      unit: unit,
      value: visual.valueFor(unit),
      opacity: opacity,
    );
  }
}

void paintTimerCountdownUnit(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required bool onTimerPage,
  required TimerUnit unit,
  required double value,
  double opacity = 1,
}) {
  if (value <= 0.01) return;

  final scale = unit == TimerUnit.hours ? 12.0 : 60.0;
  var normalized = value % scale;
  if (normalized <= 0.01) normalized = scale;
  final fraction = (normalized / scale).clamp(0.0, 1.0);
  final baseRadius = radius * (onTimerPage ? 0.73 : 0.71);
  final gap = onTimerPage ? 8.4 : 7.4;
  final stroke = onTimerPage ? 4.2 : 3.7;
  final ringRadius = baseRadius + gap * unit.index;
  final paint = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = stroke
    ..color = timerUnitColor(
      unit,
    ).withAlpha((185 * opacity.clamp(0.0, 1.0)).round());
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: ringRadius),
    -math.pi / 2,
    math.pi * 2 * fraction,
    false,
    paint,
  );
}
