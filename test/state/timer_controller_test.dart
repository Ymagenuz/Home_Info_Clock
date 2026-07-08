import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/state/timer_controller.dart';

void main() {
  test('TimerController starts and finishes from wall clock', () {
    final controller = TimerController(initial: const TimerState(minutes: 1));
    final now = DateTime(2026, 7, 7, 9, 0);

    controller.startOrClear(now);

    expect(controller.state.isRunning, isTrue);
    expect(controller.state.endsAt, now.add(const Duration(minutes: 1)));

    controller.sync(now.add(const Duration(minutes: 2)));

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.isFinished, isTrue);
  });

  test('TimerController clamps selected units', () {
    final controller = TimerController();

    controller.setUnit(TimerUnit.hours, 12);
    controller.setUnit(TimerUnit.minutes, -1);
    controller.setUnit(TimerUnit.seconds, 90);

    expect(controller.state.hours, 11);
    expect(controller.state.minutes, 0);
    expect(controller.state.seconds, 59);
  });

  test('TimerController clears a running timer', () {
    final now = DateTime(2026, 7, 7, 9, 0);
    final controller = TimerController(initial: const TimerState(seconds: 30));

    controller.startOrClear(now);
    controller.startOrClear(now.add(const Duration(seconds: 5)));

    expect(controller.state.isRunning, isFalse);
    expect(controller.state.endsAt, isNull);
    expect(controller.state.totalSeconds, 0);
    expect(controller.state.isFinished, isFalse);
  });

  test('TimerController dismisses finished state', () {
    final controller = TimerController(
      initial: const TimerState(isFinished: true),
    );

    controller.dismissFinished();

    expect(controller.state.isFinished, isFalse);
  });
}
