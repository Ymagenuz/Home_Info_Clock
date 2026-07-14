import 'dart:async';

import 'package:home_info_clock/models/battery_status.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/platform_service.dart';

WeatherSnapshot testWeatherSnapshot({
  String locationLabel = 'Cached City',
  DateTime? updatedAt,
  String sourceLabel = 'Test',
}) {
  return WeatherSnapshot(
    locationLabel: locationLabel,
    updatedAt: updatedAt ?? DateTime(2026, 7, 8, 9, 0),
    currentTemp: 22,
    apparentTemp: 24,
    humidity: 58,
    windKmh: 9,
    currentCode: 1,
    currentDescription: 'Clear',
    sourceLabel: sourceLabel,
    reportTimeLabel: '09:00',
    days: const [
      WeatherDay(
        date: '2026-07-08',
        code: 1,
        description: 'Clear',
        high: 25,
        low: 19,
      ),
      WeatherDay(
        date: '2026-07-09',
        code: 61,
        description: 'Rain',
        high: 24,
        low: 18,
      ),
    ],
  );
}

class RecordingWeatherFetcher {
  RecordingWeatherFetcher(this.snapshot);

  final WeatherSnapshot snapshot;
  int calls = 0;
  WeatherRequest? lastRequest;

  Future<WeatherSnapshot> call(WeatherRequest request) async {
    calls += 1;
    lastRequest = request;
    return snapshot;
  }
}

class FakePlatformGateway implements PlatformGateway {
  FakePlatformGateway({
    this.initialBattery = const BatteryStatus(level: 55, isCharging: false),
    this.readBatteryStatusOverride,
  });

  final BatteryStatus initialBattery;
  final Future<BatteryStatus> Function()? readBatteryStatusOverride;
  final StreamController<BatteryStatus> batteryUpdates =
      StreamController<BatteryStatus>.broadcast();

  int batteryReads = 0;
  int batteryWatches = 0;

  @override
  Future<void> enterKioskMode() async {}

  @override
  Future<BatteryStatus> readBatteryStatus() {
    batteryReads += 1;
    return readBatteryStatusOverride?.call() ??
        Future<BatteryStatus>.value(initialBattery);
  }

  @override
  Stream<BatteryStatus> watchBatteryStatus() {
    batteryWatches += 1;
    return batteryUpdates.stream;
  }

  Future<void> close() => batteryUpdates.close();
}
