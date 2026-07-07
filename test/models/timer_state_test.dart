import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';

void main() {
  test('TimerState converts selected units to seconds', () {
    const state = TimerState(hours: 1, minutes: 2, seconds: 3);

    expect(state.totalSeconds, 3723);
  });

  test('TimerState derives remaining time from an end timestamp', () {
    final now = DateTime(2026, 7, 7, 9, 0);
    final state = TimerState.runningUntil(now.add(const Duration(seconds: 65)));

    expect(state.remainingAt(now), const Duration(seconds: 65));
    expect(state.unitsAt(now), const TimerUnits(hours: 0, minutes: 1, seconds: 5));
  });
}
