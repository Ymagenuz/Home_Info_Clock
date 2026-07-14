import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimerFinishedMotion {
  const TimerFinishedMotion({required this.radians, required this.scale});

  factory TimerFinishedMotion.fromCycleProgress(double progress) {
    const shakeMilliseconds = 820.0;
    const cycleMilliseconds = 1620.0;
    final phase = progress.clamp(0.0, 1.0);
    if (phase >= shakeMilliseconds / cycleMilliseconds) {
      return const TimerFinishedMotion(radians: 0, scale: 1);
    }

    final time = phase * cycleMilliseconds / shakeMilliseconds;
    final envelope = math.sin(time * math.pi);
    final wave = math.sin(time * math.pi * 10) * envelope;
    return TimerFinishedMotion(
      radians: wave * 12 * math.pi / 180,
      scale: 1 + 0.07 * wave.abs(),
    );
  }

  final double radians;
  final double scale;
}

class TimerFinishedBellPainter extends CustomPainter {
  const TimerFinishedBellPainter({this.iconSize = 72});

  final double iconSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final cx = center.dx;
    final cy = center.dy;
    final stroke = iconSize * 0.055;
    const outline = Color(0xFF142230);
    const keyline = Color(0xFFEEFAF6);
    const fill = Color(0xFFFCDB7A);
    const brim = Color(0xFF67CDDA);
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final handle = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - iconSize * 0.11,
        cy - iconSize * 0.62,
        cx + iconSize * 0.11,
        cy - iconSize * 0.20,
      ),
      Radius.circular(iconSize * 0.11),
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.8
      ..color = keyline;
    canvas.drawRRect(handle, paint);
    paint
      ..strokeWidth = stroke
      ..color = outline;
    canvas.drawRRect(handle, paint);

    final bell = Path()
      ..moveTo(cx - iconSize * 0.42, cy + iconSize * 0.17)
      ..cubicTo(
        cx - iconSize * 0.38,
        cy - iconSize * 0.30,
        cx - iconSize * 0.24,
        cy - iconSize * 0.50,
        cx,
        cy - iconSize * 0.50,
      )
      ..cubicTo(
        cx + iconSize * 0.24,
        cy - iconSize * 0.50,
        cx + iconSize * 0.38,
        cy - iconSize * 0.30,
        cx + iconSize * 0.42,
        cy + iconSize * 0.17,
      )
      ..lineTo(cx + iconSize * 0.49, cy + iconSize * 0.30)
      ..lineTo(cx - iconSize * 0.49, cy + iconSize * 0.30)
      ..close();
    paint
      ..style = PaintingStyle.fill
      ..color = fill;
    canvas.drawPath(bell, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.75
      ..color = keyline;
    canvas.drawPath(bell, paint);
    paint
      ..strokeWidth = stroke
      ..color = outline;
    canvas.drawPath(bell, paint);

    final brimRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - iconSize * 0.55,
        cy + iconSize * 0.25,
        cx + iconSize * 0.55,
        cy + iconSize * 0.39,
      ),
      Radius.circular(iconSize * 0.07),
    );
    paint
      ..style = PaintingStyle.fill
      ..color = brim;
    canvas.drawRRect(brimRect, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.75
      ..color = keyline;
    canvas.drawRRect(brimRect, paint);
    paint
      ..strokeWidth = stroke
      ..color = outline;
    canvas.drawRRect(brimRect, paint);

    final clapper = Rect.fromLTRB(
      cx - iconSize * 0.16,
      cy + iconSize * 0.34,
      cx + iconSize * 0.16,
      cy + iconSize * 0.66,
    );
    paint
      ..style = PaintingStyle.fill
      ..color = fill;
    canvas.drawOval(clapper, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.75
      ..color = keyline;
    canvas.drawOval(clapper, paint);
    paint
      ..strokeWidth = stroke
      ..color = outline;
    canvas.drawOval(clapper, paint);

    final shine = Path()
      ..moveTo(cx - iconSize * 0.29, cy - iconSize * 0.22)
      ..cubicTo(
        cx - iconSize * 0.23,
        cy - iconSize * 0.36,
        cx - iconSize * 0.12,
        cy - iconSize * 0.42,
        cx - iconSize * 0.02,
        cy - iconSize * 0.43,
      );
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = iconSize * 0.045
      ..color = const Color(0xD7FFFFFF);
    canvas.drawPath(shine, paint);
    canvas.drawLine(
      Offset(cx - iconSize * 0.34, cy - iconSize * 0.08),
      Offset(cx - iconSize * 0.34, cy + iconSize * 0.02),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TimerFinishedBellPainter oldDelegate) {
    return oldDelegate.iconSize != iconSize;
  }
}
