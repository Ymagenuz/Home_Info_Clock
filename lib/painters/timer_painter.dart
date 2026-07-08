import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/timer_state.dart';

class TimerPainter extends CustomPainter {
  const TimerPainter(this.state, this.now);

  final TimerState state;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final trackRadius = radius * 0.84;
    final remainingSeconds = state.remainingAt(now).inSeconds;
    final progress = _progressFor(remainingSeconds);
    final accent = state.isFinished
        ? const Color(0xFFFF8A80)
        : state.isRunning
        ? const Color(0xFF64DCCD)
        : const Color(0xFFFFCD5E);

    final track = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x26FFFFFF);
    canvas.drawCircle(center, trackRadius, track);

    if (progress > 0) {
      final arc = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07
        ..strokeCap = StrokeCap.round
        ..color = accent;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: trackRadius),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        arc,
      );
    }

    _ticks(canvas, center, trackRadius, radius);
    _innerGlow(canvas, center, radius, accent);
  }

  double _progressFor(int remainingSeconds) {
    if (state.isFinished) return 1;
    if (state.totalSeconds == 0 && !state.isRunning) return 0;
    if (!state.isRunning) return 1;
    final minuteProgress = remainingSeconds % 60;
    return minuteProgress == 0 ? 1 : minuteProgress / 60;
  }

  void _ticks(Canvas canvas, Offset center, double trackRadius, double radius) {
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = radius * 0.012
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 60; i += 5) {
      final angle = -math.pi / 2 + i * math.pi / 30;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * trackRadius * 0.9,
        center + direction * trackRadius * 0.98,
        paint,
      );
    }
  }

  void _innerGlow(Canvas canvas, Offset center, double radius, Color accent) {
    final fill = Paint()
      ..isAntiAlias = true
      ..shader = RadialGradient(
        colors: [accent.withAlpha(50), const Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.72));
    canvas.drawCircle(center, radius * 0.72, fill);
  }

  @override
  bool shouldRepaint(covariant TimerPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.now.second != now.second;
}
