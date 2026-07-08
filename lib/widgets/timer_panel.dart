import 'package:flutter/material.dart';

import '../state/timer_controller.dart';
import 'metric_cell.dart';

class TimerPanel extends StatelessWidget {
  const TimerPanel({super.key, required this.controller});

  final TimerController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final units = state.unitsAt(DateTime.now());
    final actionLabel = state.isRunning ? 'Clear' : 'Start';

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
              FilledButton.icon(
                onPressed: () => controller.startOrClear(DateTime.now()),
                icon: Icon(state.isRunning ? Icons.clear : Icons.play_arrow),
                label: Text(actionLabel),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_twoDigits(units.hours)}:${_twoDigits(units.minutes)}:${_twoDigits(units.seconds)}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 104,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _TimerUnitControl(
                  label: 'Hours',
                  value: units.hours,
                  onMinus: () =>
                      controller.setUnit(TimerUnit.hours, state.hours - 1),
                  onPlus: () =>
                      controller.setUnit(TimerUnit.hours, state.hours + 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimerUnitControl(
                  label: 'Minutes',
                  value: units.minutes,
                  onMinus: () =>
                      controller.setUnit(TimerUnit.minutes, state.minutes - 1),
                  onPlus: () =>
                      controller.setUnit(TimerUnit.minutes, state.minutes + 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimerUnitControl(
                  label: 'Seconds',
                  value: units.seconds,
                  onMinus: () =>
                      controller.setUnit(TimerUnit.seconds, state.seconds - 1),
                  onPlus: () =>
                      controller.setUnit(TimerUnit.seconds, state.seconds + 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerUnitControl extends StatelessWidget {
  const _TimerUnitControl({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 92,
          child: MetricCell(label: label, value: _twoDigits(value)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: IconButton.filledTonal(
                tooltip: 'Decrease $label',
                onPressed: onMinus,
                icon: const Icon(Icons.remove),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: IconButton.filledTonal(
                tooltip: 'Increase $label',
                onPressed: onPlus,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
