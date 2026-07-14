import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../painters/analog_clock_painter.dart';
import '../state/timer_controller.dart';
import 'timer_countdown_animator.dart';

class ClockPanel extends StatelessWidget {
  const ClockPanel({
    super.key,
    required this.now,
    required this.onToggleMode,
    this.timerController,
    this.frameTime,
  });

  final DateTime now;
  final VoidCallback onToggleMode;
  final TimerController? timerController;
  final ValueListenable<DateTime>? frameTime;

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
                    child: timerController == null
                        ? CustomPaint(
                            painter: AnalogClockPainter(
                              now,
                              frameTime: frameTime,
                            ),
                          )
                        : TimerCountdownAnimator(
                            controller: timerController!,
                            now: now,
                            frameTime: frameTime,
                            builder: (context, visual) {
                              final face = CustomPaint(
                                painter: AnalogClockPainter(
                                  now,
                                  countdownVisual: visual,
                                  frameTime: frameTime,
                                ),
                              );
                              if (!visual.isRunning) return face;
                              return Semantics(
                                key: const ValueKey('clock-countdown-rings'),
                                label: '倒计时进行中',
                                child: face,
                              );
                            },
                          ),
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
