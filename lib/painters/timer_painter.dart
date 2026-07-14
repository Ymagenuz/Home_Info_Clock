import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/timer_state.dart';
import '../state/timer_controller.dart';

class TimerPainter extends CustomPainter {
  TimerPainter({
    required this.state,
    required this.now,
    required this.center,
    required this.radius,
    required this.displayUnit,
    required this.displayValue,
    required this.highlightOpacity,
  }) : super(repaint: highlightOpacity);

  final TimerState state;
  final DateTime now;
  final Offset center;
  final double radius;
  final TimerUnit? displayUnit;
  final double displayValue;
  final Animation<double> highlightOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final activeColor = displayUnit == null
        ? const Color(0xFFFFB300)
        : timerUnitColor(displayUnit!);
    final units = displayUnit == TimerUnit.hours ? 12 : 60;
    final angleValue = displayUnit == TimerUnit.hours
        ? displayValue <= 0
              ? 0.0
              : (((displayValue - 1) % 12) + 1) / 12
        : displayValue / 60;
    final highlight = highlightOpacity.value.clamp(0.0, 1.0);
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final ring = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9.5
      ..color = displayUnit == null
          ? const Color(0x16F8F8FA)
          : activeColor.withAlpha(58);
    canvas.drawArc(ringRect, -math.pi / 2, math.pi * 2, false, ring);

    if (displayUnit != null && angleValue > 0 && highlight > 0) {
      ring.color = activeColor.withAlpha((165 * highlight).round());
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        math.pi * 2 * angleValue,
        false,
        ring,
      );
    }

    final activeTick = displayUnit == TimerUnit.hours
        ? displayValue <= 0
              ? 0.0
              : ((displayValue - 1) % 12) + 1
        : displayValue;
    for (var index = 0; index < units; index += 1) {
      final angle = index * math.pi * 2 / units - math.pi / 2;
      final tickDistance = _circularDistance(
        index.toDouble(),
        activeTick,
        units,
      );
      final emphasis = displayUnit == null
          ? 0.0
          : math.max(0.0, 1 - tickDistance) * highlight;
      final outer = radius * 0.99 + 8 * emphasis;
      final major = units == 12 || index % 5 == 0;
      final inner = radius * (major ? 0.91 : 0.94) - 8 * emphasis;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final tick = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.1 + 1.5 * emphasis
        ..color = emphasis > 0
            ? const Color(0xFFF8F8FA).withAlpha((210 + 45 * emphasis).round())
            : major
            ? const Color(0xE6F8F8FA)
            : const Color(0x84F8F8FA);
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        tick,
      );
    }
  }

  double _circularDistance(double a, double b, int units) {
    final difference = (a - b).abs();
    return math.min(difference, units - difference);
  }

  @override
  bool shouldRepaint(covariant TimerPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.now != now ||
        oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.displayUnit != displayUnit ||
        oldDelegate.displayValue != displayValue ||
        oldDelegate.highlightOpacity != highlightOpacity;
  }
}

class TimerRotationGuidancePainter extends CustomPainter {
  const TimerRotationGuidancePainter({
    required this.center,
    required this.radius,
  });

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final arrowRadius = radius + 24;
    _drawArrow(canvas, arrowRadius, 145, 72);
    _drawArrow(canvas, arrowRadius, -45, 90);
  }

  void _drawArrow(
    Canvas canvas,
    double arrowRadius,
    double startDegrees,
    double sweepDegrees,
  ) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4
      ..color = const Color(0x5CF8F8FA);
    final rect = Rect.fromCircle(center: center, radius: arrowRadius);
    final start = startDegrees * math.pi / 180;
    final sweep = sweepDegrees * math.pi / 180;
    canvas.drawArc(rect, start, sweep, false, paint);

    final end = start + sweep;
    final endPoint =
        center + Offset(math.cos(end), math.sin(end)) * arrowRadius;
    final tangent = end + math.pi / 2;
    for (final offset in const <double>[150, -150]) {
      final arrowAngle = tangent + offset * math.pi / 180;
      canvas.drawLine(
        endPoint,
        endPoint + Offset(math.cos(arrowAngle), math.sin(arrowAngle)) * 8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TimerRotationGuidancePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

class TimerTickValuePainter extends CustomPainter {
  const TimerTickValuePainter({
    required this.center,
    required this.radius,
    required this.unit,
    required this.value,
  });

  final Offset center;
  final double radius;
  final TimerUnit unit;
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final units = unit == TimerUnit.hours ? 12 : 60;
    final roundedValue = value.round();
    final tick = unit == TimerUnit.hours
        ? roundedValue == 0
              ? 0
              : ((roundedValue - 1) % 12) + 1
        : roundedValue;
    final angle = tick * math.pi * 2 / units - math.pi / 2;
    final anchor =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius + 34);
    final color = timerUnitColor(unit);
    canvas.drawCircle(
      anchor,
      16,
      Paint()
        ..isAntiAlias = true
        ..color = color.withAlpha(85),
    );

    final text = TextPainter(
      text: TextSpan(
        text: '$roundedValue',
        style: const TextStyle(
          color: Color(0xFFF8F8FA),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    text.paint(canvas, anchor - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(covariant TimerTickValuePainter oldDelegate) {
    return oldDelegate.center != center ||
        oldDelegate.radius != radius ||
        oldDelegate.unit != unit ||
        oldDelegate.value != value;
  }
}

Color timerUnitColor(TimerUnit unit) {
  return switch (unit) {
    TimerUnit.hours => const Color(0xFFFFCD5E),
    TimerUnit.minutes => const Color(0xFF64DCCD),
    TimerUnit.seconds => const Color(0xFFFF885E),
  };
}
