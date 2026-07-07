import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/weather.dart';
import 'package:home_info_clock/services/weather_service.dart';
import 'package:home_info_clock/services/weather_source.dart';

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource(this.name, this.result);

  final String name;
  final Object result;
  bool called = false;

  @override
  Future<WeatherSnapshot> fetch(WeatherRequest request) async {
    called = true;
    if (result is Exception) {
      throw result as Exception;
    }
    return result as WeatherSnapshot;
  }
}

WeatherSnapshot snapshot(
  String source, {
  bool forecast = true,
  int dayCount = 2,
}) {
  return WeatherSnapshot(
    locationLabel: '\u4e0a\u6d77',
    updatedAt: DateTime(2026, 7, 7, 9),
    currentTemp: 30,
    apparentTemp: 32,
    humidity: 70,
    windKmh: 12,
    currentCode: 2,
    currentDescription: '\u591a\u4e91',
    sourceLabel: source,
    reportTimeLabel: '09:00',
    forecastAvailable: forecast,
    days: List.generate(
      dayCount,
      (index) => WeatherDay(
        date: '2026-07-0${index + 7}',
        code: 2,
        description: '\u591a\u4e91',
        high: 32,
        low: 26,
      ),
    ),
  );
}

void main() {
  const request = WeatherRequest(
    latitude: 31.2,
    longitude: 121.5,
    locationLabel: '\u4e0a\u6d77',
  );

  test('WeatherService uses primary when it has forecast data', () async {
    final uapi = FakeWeatherSource('uapi', snapshot('UAPI\u9884\u62a5'));
    final openMeteo = FakeWeatherSource('open', snapshot('Open-Meteo'));
    final service = WeatherService(primary: uapi, fallback: openMeteo);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'UAPI\u9884\u62a5');
    expect(openMeteo.called, isFalse);
  });

  test('WeatherService falls back when primary lacks forecast data', () async {
    final uapi = FakeWeatherSource(
      'uapi',
      snapshot('UAPI\u5b9e\u65f6', forecast: false, dayCount: 1),
    );
    final openMeteo = FakeWeatherSource('open', snapshot('Open-Meteo'));
    final service = WeatherService(primary: uapi, fallback: openMeteo);

    final result = await service.fetchWeather(request);

    expect(result.sourceLabel, 'Open-Meteo');
    expect(openMeteo.called, isTrue);
  });
}
