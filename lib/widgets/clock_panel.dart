import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../painters/analog_clock_painter.dart';

class ClockPanel extends StatelessWidget {
  const ClockPanel({super.key, required this.now, required this.onToggleMode});

  final DateTime now;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '切换简洁模式',
      child: GestureDetector(
        key: const ValueKey('clock-panel-tap-target'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggleMode,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final radius = math.min(width * 0.37, height * 0.36);
            final centerY = math.max(radius + 12, height * 0.36);
            final diameter = radius * 2;
            final timeSize = _scaledTimeSize(height);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: (width - diameter) / 2,
                  top: centerY - radius,
                  width: diameter,
                  height: diameter,
                  child: RepaintBoundary(
                    key: const ValueKey('analog-clock-face'),
                    child: CustomPaint(painter: AnalogClockPainter(now)),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 84,
                  child: Text(
                    _fullDateLabel(now),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xBEE0F2EB),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 10,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}',
                      style: TextStyle(
                        color: const Color(0xFFEEFAF6),
                        fontSize: timeSize,
                        fontWeight: FontWeight.w800,
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
    );
  }
}

double _scaledTimeSize(double height) {
  final progress = ((height - 320) / 150).clamp(0.0, 1.0);
  return 56 + 18 * progress;
}

String _fullDateLabel(DateTime value) {
  const weekdays = <String>['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${value.year}年${value.month}月${value.day}日 ${weekdays[value.weekday - 1]}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
