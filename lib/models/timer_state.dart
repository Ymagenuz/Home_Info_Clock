class TimerUnits {
  const TimerUnits({
    required this.hours,
    required this.minutes,
    required this.seconds,
  });

  final int hours;
  final int minutes;
  final int seconds;

  @override
  bool operator ==(Object other) =>
      other is TimerUnits &&
      other.hours == hours &&
      other.minutes == minutes &&
      other.seconds == seconds;

  @override
  int get hashCode => Object.hash(hours, minutes, seconds);
}

class TimerState {
  const TimerState({
    this.hours = 0,
    this.minutes = 0,
    this.seconds = 0,
    this.isRunning = false,
    this.endsAt,
    this.isFinished = false,
  });

  factory TimerState.runningUntil(DateTime endsAt) {
    return TimerState(isRunning: true, endsAt: endsAt);
  }

  factory TimerState.fromJson(Map<String, dynamic> json) {
    return TimerState(
      hours: (json['hours'] as num?)?.toInt() ?? 0,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      isRunning: json['isRunning'] as bool? ?? false,
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.parse(json['endsAt'] as String),
      isFinished: json['isFinished'] as bool? ?? false,
    );
  }

  final int hours;
  final int minutes;
  final int seconds;
  final bool isRunning;
  final DateTime? endsAt;
  final bool isFinished;

  int get totalSeconds => hours * 3600 + minutes * 60 + seconds;

  Duration remainingAt(DateTime now) {
    final end = endsAt;
    if (!isRunning || end == null) {
      return Duration(seconds: totalSeconds);
    }

    final remaining = end.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  TimerUnits unitsAt(DateTime now) {
    final total = remainingAt(now).inSeconds;
    return TimerUnits(
      hours: total ~/ 3600,
      minutes: (total ~/ 60) % 60,
      seconds: total % 60,
    );
  }

  TimerState copyWith({
    int? hours,
    int? minutes,
    int? seconds,
    bool? isRunning,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? isFinished,
  }) {
    return TimerState(
      hours: hours ?? this.hours,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      isRunning: isRunning ?? this.isRunning,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      isFinished: isFinished ?? this.isFinished,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'isRunning': isRunning,
      'endsAt': endsAt?.toIso8601String(),
      'isFinished': isFinished,
    };
  }
}
