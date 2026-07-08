import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnalogClockPainter extends CustomPainter {
  const AnalogClockPainter(this.time);

  final DateTime time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()..isAntiAlias = true;
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.045
      ..color = const Color(0xFFE8F1EC);
    canvas.drawCircle(center, radius * 0.92, paint);

    for (var i = 0; i < 12; i++) {
      final angle = -math.pi / 2 + i * math.pi / 6;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.72;
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.82;
      paint.strokeWidth = i % 3 == 0 ? radius * 0.018 : radius * 0.01;
      canvas.drawLine(start, end, paint);
    }

    _hand(
      canvas,
      center,
      radius * 0.48,
      ((time.hour % 12) + time.minute / 60) * 30,
      radius * 0.035,
      Colors.white,
    );
    _hand(
      canvas,
      center,
      radius * 0.66,
      (time.minute + time.second / 60) * 6,
      radius * 0.022,
      const Color(0xFF64DCCD),
    );
    _hand(
      canvas,
      center,
      radius * 0.72,
      time.second * 6,
      radius * 0.009,
      const Color(0xFFFFCD5E),
    );
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFCD5E);
    canvas.drawCircle(center, radius * 0.045, paint);
  }

  void _hand(
    Canvas canvas,
    Offset center,
    double length,
    double degrees,
    double stroke,
    Color color,
  ) {
    final angle = -math.pi / 2 + degrees * math.pi / 180;
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = color;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * length,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) =>
      oldDelegate.time.second != time.second;
}
