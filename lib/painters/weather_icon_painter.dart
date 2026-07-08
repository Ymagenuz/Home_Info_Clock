import 'dart:math' as math;

import 'package:flutter/material.dart';

class WeatherIconPainter extends CustomPainter {
  const WeatherIconPainter(this.code, this.accent);

  final int code;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final scale = side / 100;
    final normalized = _normalizedCode(code);

    if (_isStorm(normalized)) {
      _cloud(canvas, center, scale);
      _rain(canvas, center, scale, storm: true);
      _bolt(canvas, center, scale);
    } else if (_isSnow(normalized)) {
      _cloud(canvas, center, scale);
      _snow(canvas, center, scale);
    } else if (_isRain(normalized)) {
      _cloud(canvas, center, scale);
      _rain(canvas, center, scale);
    } else if (_isCloudy(normalized)) {
      if (_isPartlyCloudy(normalized)) {
        _sun(canvas, center.translate(-20 * scale, -20 * scale), 18 * scale);
      }
      _cloud(canvas, center, scale);
    } else {
      _sun(canvas, center, 27 * scale);
    }
  }

  int _normalizedCode(int raw) {
    if (raw == 1000) return 0;
    if (raw == 1003) return 2;
    if (raw == 1006 || raw == 1009) return 3;
    if (raw == 451) return 45;
    if (raw >= 1063 && raw <= 1201) return 61;
    if (raw >= 1210 && raw <= 1237) return 71;
    if (raw >= 1240 && raw <= 1264) return 80;
    if (raw >= 1273) return 95;
    return raw;
  }

  bool _isPartlyCloudy(int value) => value == 1 || value == 2;

  bool _isCloudy(int value) =>
      _isPartlyCloudy(value) || value == 3 || value == 45 || value == 48;

  bool _isRain(int value) =>
      (value >= 51 && value <= 67) || (value >= 80 && value <= 82);

  bool _isSnow(int value) =>
      (value >= 71 && value <= 77) || value == 85 || value == 86;

  bool _isStorm(int value) => value >= 95 && value <= 99;

  void _sun(Canvas canvas, Offset center, double radius) {
    final rayPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round
      ..color = accent.withAlpha(165);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * radius * 1.25,
        center + direction * radius * 1.7,
        rayPaint,
      );
    }
    final paint = Paint()
      ..isAntiAlias = true
      ..color = accent;
    canvas.drawCircle(center, radius, paint);
  }

  void _cloud(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..isAntiAlias = true
      ..color = Color.lerp(accent, Colors.white, 0.36)!;
    final shadow = Paint()
      ..isAntiAlias = true
      ..color = Colors.black.withAlpha(55);

    final base = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(6 * scale, 18 * scale),
        width: 70 * scale,
        height: 30 * scale,
      ),
      Radius.circular(15 * scale),
    );
    canvas.drawRRect(base.shift(Offset(0, 3 * scale)), shadow);
    canvas.drawCircle(
      center.translate(-18 * scale, 8 * scale),
      18 * scale,
      paint,
    );
    canvas.drawCircle(center.translate(4 * scale, 0), 25 * scale, paint);
    canvas.drawCircle(
      center.translate(27 * scale, 10 * scale),
      17 * scale,
      paint,
    );
    canvas.drawRRect(base, paint);
  }

  void _rain(Canvas canvas, Offset center, double scale, {bool storm = false}) {
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 4.2 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7DD3FC);
    final drops = storm
        ? const [-20.0, 0.0, 20.0]
        : const [-24.0, -8.0, 8.0, 24.0];
    for (final x in drops) {
      canvas.drawLine(
        center.translate(x * scale, 37 * scale),
        center.translate((x - 6) * scale, 52 * scale),
        paint,
      );
    }
  }

  void _snow(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8F1EC);
    for (final offset in const [
      Offset(-20, 43),
      Offset(2, 51),
      Offset(24, 43),
    ]) {
      final point = center + offset * scale;
      canvas.drawLine(
        point.translate(-5 * scale, 0),
        point.translate(5 * scale, 0),
        paint,
      );
      canvas.drawLine(
        point.translate(0, -5 * scale),
        point.translate(0, 5 * scale),
        paint,
      );
    }
  }

  void _bolt(Canvas canvas, Offset center, double scale) {
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFCD5E);
    final path = Path()
      ..moveTo(center.dx + 2 * scale, center.dy + 28 * scale)
      ..lineTo(center.dx - 8 * scale, center.dy + 56 * scale)
      ..lineTo(center.dx + 6 * scale, center.dy + 50 * scale)
      ..lineTo(center.dx, center.dy + 72 * scale)
      ..lineTo(center.dx + 18 * scale, center.dy + 41 * scale)
      ..lineTo(center.dx + 4 * scale, center.dy + 46 * scale)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WeatherIconPainter oldDelegate) =>
      oldDelegate.code != code || oldDelegate.accent != accent;
}
