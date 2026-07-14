import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../painters/timer_countdown_painter.dart';
import '../state/timer_controller.dart';
import 'timer_countdown_animator.dart';

class TimerCountdownRings extends StatelessWidget {
  const TimerCountdownRings({
    super.key,
    required this.controller,
    required this.now,
    required this.center,
    required this.radius,
    required this.keyPrefix,
    required this.onTimerPage,
    this.frameTime,
  });

  final TimerController controller;
  final DateTime now;
  final Offset center;
  final double radius;
  final String keyPrefix;
  final bool onTimerPage;
  final ValueListenable<DateTime>? frameTime;

  @override
  Widget build(BuildContext context) {
    return TimerCountdownAnimator(
      controller: controller,
      now: now,
      frameTime: frameTime,
      builder: (context, visual) {
        if (!visual.isRunning) return const SizedBox.shrink();
        return FadeTransition(
          key: ValueKey('$keyPrefix-countdown-rings'),
          opacity: visual.entranceOpacity,
          child: Stack(
            children: [
              for (final unit in TimerUnit.values)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: ValueKey(
                        '$keyPrefix-countdown-${switch (unit) {
                          TimerUnit.hours => 'hours',
                          TimerUnit.minutes => 'minutes',
                          TimerUnit.seconds => 'seconds',
                        }}',
                      ),
                      painter: TimerCountdownUnitPainter(
                        visual: visual,
                        unit: unit,
                        center: center,
                        radius: radius,
                        onTimerPage: onTimerPage,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
