import 'package:flutter/material.dart';

import '../painters/analog_clock_painter.dart';

class ClockPanel extends StatelessWidget {
  const ClockPanel({super.key, required this.now, required this.onToggleMode});

  final DateTime now;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final timeLabel = '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';
    final dateLabel =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 520 || constraints.maxWidth < 420;
        final gap = compact ? 8.0 : 18.0;
        final clockSize = compact
            ? (constraints.maxHeight * 0.28).clamp(72.0, 120.0)
            : 210.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 28,
            vertical: compact ? 10 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Home Info Clock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? Theme.of(context).textTheme.titleSmall
                                  : Theme.of(context).textTheme.titleMedium)
                              ?.copyWith(
                                color: const Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Simple mode',
                    onPressed: onToggleMode,
                    icon: const Icon(Icons.fullscreen_exit),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: clockSize,
                        child: CustomPaint(painter: AnalogClockPainter(now)),
                      ),
                      SizedBox(height: gap),
                      Text(
                        dateLabel,
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.headlineSmall)
                                ?.copyWith(
                                  color: const Color(0xB3FFFFFF),
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                      SizedBox(height: gap),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: compact ? 64 : 132,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      SizedBox(height: gap),
                      const Text(
                        'Ready',
                        style: TextStyle(
                          color: Color(0xFF93E5AB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
