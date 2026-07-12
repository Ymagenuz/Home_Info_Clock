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

    _drawMarks(canvas, center, radius, paint);
    _drawNumbers(canvas, center, radius);

    final smoothSecond = time.second + time.millisecond / 1000;
    final secondAngle = smoothSecond * 6;
    final minuteAngle = (time.minute + smoothSecond / 60) * 6;
    final hourAngle = ((time.hour % 12) + time.minute / 60) * 30;

    _drawPrimaryHand(
      canvas,
      center,
      radius,
      hourAngle,
      length: 0.43,
      backLength: 0.08,
      neckLength: 0.16,
      stroke: 0.066,
    );
    _drawPrimaryHand(
      canvas,
      center,
      radius,
      minuteAngle,
      length: 0.68,
      backLength: 0.10,
      neckLength: 0.17,
      stroke: 0.059,
    );
    _drawClockHand(
      canvas,
      center,
      radius,
      secondAngle,
      length: 0.88,
      backLength: 0.12,
      stroke: 0.015,
      color: const Color(0xFFFFB300),
    );

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFB300);
    canvas.drawCircle(center, radius * 0.061, paint);
    paint.color = const Color(0xFF141414);
    canvas.drawCircle(center, radius * 0.034, paint);
  }

  void _drawMarks(Canvas canvas, Offset center, double radius, Paint paint) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < 60; index += 1) {
      final major = index % 5 == 0;
      final angle = -math.pi / 2 + index * math.pi / 30;
      final direction = Offset(math.cos(angle), math.sin(angle));
      paint
        ..strokeWidth = radius * (major ? 0.027 : 0.017)
        ..color = major ? const Color(0xE1F8F8FA) : const Color(0x76F8F8FA);
      canvas.drawLine(
        center + direction * radius * 0.91,
        center + direction * radius * 0.98,
        paint,
      );
    }
  }

  void _drawNumbers(Canvas canvas, Offset center, double radius) {
    final style = TextStyle(
      color: const Color(0xF8F8F8FA),
      fontSize: radius * 0.155,
      fontWeight: FontWeight.w700,
      height: 1,
    );
    for (var number = 1; number <= 12; number += 1) {
      final angle = -math.pi / 2 + number * math.pi / 6;
      final anchor =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.78;
      final painter = TextPainter(
        text: TextSpan(text: '$number', style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(
        canvas,
        anchor - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  void _drawClockHand(
    Canvas canvas,
    Offset center,
    double radius,
    double degrees, {
    required double length,
    required double backLength,
    required double stroke,
    required Color color,
  }) {
    final angle = -math.pi / 2 + degrees * math.pi / 180;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * stroke
      ..color = color;
    canvas.drawLine(
      center - direction * radius * backLength,
      center + direction * radius * length,
      paint,
    );
  }

  void _drawPrimaryHand(
    Canvas canvas,
    Offset center,
    double radius,
    double degrees, {
    required double length,
    required double backLength,
    required double neckLength,
    required double stroke,
  }) {
    final angle = -math.pi / 2 + degrees * math.pi / 180;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * stroke
      ..color = const Color(0xFFF8F8FA);
    final neckEnd = center + direction * radius * neckLength;
    canvas.drawLine(neckEnd, center + direction * radius * length, paint);
    paint
      ..strokeWidth = radius * stroke * 0.44
      ..color = const Color(0xFFBCBEC4);
    canvas.drawLine(center - direction * radius * backLength, neckEnd, paint);
  }

  @override
  bool shouldRepaint(covariant AnalogClockPainter oldDelegate) =>
      oldDelegate.time.hour != time.hour ||
      oldDelegate.time.minute != time.minute ||
      oldDelegate.time.second != time.second ||
      oldDelegate.time.millisecond != time.millisecond;
}
