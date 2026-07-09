import 'package:flutter/material.dart';

import '../painters/timer_painter.dart';
import '../state/timer_controller.dart';

class TimerPanel extends StatelessWidget {
  const TimerPanel({super.key, required this.controller, required this.now});

  final TimerController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final units = state.unitsAt(now);
        final statusLabel = state.isFinished
            ? 'Finished'
            : state.isRunning
            ? 'Running'
            : 'Ready';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Timer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF93E5AB),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: TimerPainter(state, now),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_twoDigits(units.hours)}:${_twoDigits(units.minutes)}:${_twoDigits(units.seconds)}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontSize: 88,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _UnitControl(
                      label: 'Hours',
                      value: _twoDigits(units.hours),
                      plusKey: const ValueKey('timer-hour-plus'),
                      onPressed: state.isRunning
                          ? null
                          : () => controller.setUnit(
                              TimerUnit.hours,
                              state.hours + 1,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _UnitControl(
                      label: 'Minutes',
                      value: _twoDigits(units.minutes),
                      plusKey: const ValueKey('timer-minute-plus'),
                      onPressed: state.isRunning
                          ? null
                          : () => controller.setUnit(
                              TimerUnit.minutes,
                              state.minutes + 1,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _UnitControl(
                      label: 'Seconds',
                      value: _twoDigits(units.seconds),
                      plusKey: const ValueKey('timer-second-plus'),
                      onPressed: state.isRunning
                          ? null
                          : () => controller.setUnit(
                              TimerUnit.seconds,
                              state.seconds + 1,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('timer-start'),
                  onPressed: () => controller.startOrClear(now),
                  icon: Icon(state.isRunning ? Icons.clear : Icons.play_arrow),
                  label: Text(state.isRunning ? 'Clear' : 'Start'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitControl extends StatelessWidget {
  const _UnitControl({
    required this.label,
    required this.value,
    required this.plusKey,
    required this.onPressed,
  });

  final String label;
  final String value;
  final Key plusKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 112,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          border: Border.all(color: const Color(0x22FFFFFF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: const Color(0xCCFFFFFF),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox.square(
                dimension: 34,
                child: IconButton.filledTonal(
                  key: plusKey,
                  tooltip: 'Increase $label',
                  padding: EdgeInsets.zero,
                  onPressed: onPressed,
                  icon: const Icon(Icons.add, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
