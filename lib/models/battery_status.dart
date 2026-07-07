class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.isCharging,
    this.isAvailable = true,
  });

  const BatteryStatus.unavailable()
      : level = -1,
        isCharging = false,
        isAvailable = false;

  final int level;
  final bool isCharging;
  final bool isAvailable;

  bool get isLow => isAvailable && !isCharging && level <= 20;
}
