import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/battery_status.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/state/home_controller.dart';

void main() {
  test('HomeController toggles simple mode', () {
    final controller = HomeController.preview();

    expect(controller.isSimpleMode, isFalse);
    controller.toggleSimpleMode();
    expect(controller.isSimpleMode, isTrue);
  });

  test('HomeController preview exposes weather and battery state', () {
    final controller = HomeController.preview();

    expect(controller.weather, isNotNull);
    expect(controller.weather!.days, hasLength(2));
    expect(controller.battery.level, 86);
    expect(controller.battery.isCharging, isTrue);
  });

  test('HomeController updates weather and battery state', () {
    final controller = HomeController();
    final weather = WeatherSnapshot(
      locationLabel: 'Test City',
      updatedAt: DateTime(2026, 7, 7, 9, 0),
      currentTemp: 22,
      apparentTemp: 23,
      humidity: 50,
      windKmh: 8,
      currentCode: 1,
      currentDescription: 'Clear',
      sourceLabel: 'Test',
      reportTimeLabel: '09:00',
    );

    controller.setWeather(weather);
    controller.setBattery(const BatteryStatus(level: 42, isCharging: false));

    expect(controller.weather, same(weather));
    expect(controller.battery.level, 42);
    expect(controller.battery.isCharging, isFalse);
  });
}
