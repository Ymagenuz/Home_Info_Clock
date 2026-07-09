import 'package:flutter/foundation.dart';

import '../models/timer_state.dart';

enum TimerUnit { hours, minutes, seconds }

class TimerController extends ChangeNotifier {
  TimerController({TimerState initial = const TimerState()}) : _state = initial;

  TimerState _state;

  TimerState get state => _state;

  void restore(TimerState state) {
    _state = state;
    notifyListeners();
  }

  void setUnit(TimerUnit unit, int value) {
    final clamped = switch (unit) {
      TimerUnit.hours => value.clamp(0, 11).toInt(),
      TimerUnit.minutes => value.clamp(0, 59).toInt(),
      TimerUnit.seconds => value.clamp(0, 59).toInt(),
    };

    _state = switch (unit) {
      TimerUnit.hours => _state.copyWith(hours: clamped),
      TimerUnit.minutes => _state.copyWith(minutes: clamped),
      TimerUnit.seconds => _state.copyWith(seconds: clamped),
    };
    notifyListeners();
  }

  void startOrClear(DateTime now) {
    if (_state.isRunning) {
      _state = const TimerState();
    } else if (_state.totalSeconds > 0) {
      _state = TimerState.runningUntil(
        now.add(Duration(seconds: _state.totalSeconds)),
      );
    }
    notifyListeners();
  }

  void sync(DateTime now) {
    if (!_state.isRunning) return;
    if (_state.remainingAt(now) == Duration.zero) {
      _state = const TimerState(isFinished: true);
      notifyListeners();
    }
  }

  void dismissFinished() {
    _state = _state.copyWith(isFinished: false);
    notifyListeners();
  }
}
