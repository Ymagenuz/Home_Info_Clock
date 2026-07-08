import 'package:flutter/material.dart';

import '../state/timer_controller.dart';
import 'metric_cell.dart';

class TimerPanel extends StatelessWidget {
  const TimerPanel({super.key, required this.controller});

  final TimerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final units = state.unitsAt(DateTime.now());
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
                    child: SizedBox(
                      height: 92,
                      child: MetricCell(
                        label: 'Hours',
                        value: _twoDigits(units.hours),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 92,
                      child: MetricCell(
                        label: 'Minutes',
                        value: _twoDigits(units.minutes),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 92,
                      child: MetricCell(
                        label: 'Seconds',
                        value: _twoDigits(units.seconds),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
