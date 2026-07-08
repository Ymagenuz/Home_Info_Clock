import 'package:flutter/foundation.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    WeatherSnapshot? initialWeather,
    BatteryStatus initialBattery = const BatteryStatus.unavailable(),
  }) : _weather = initialWeather,
       _battery = initialBattery;

  factory HomeController.preview() {
    return HomeController(
      initialWeather: WeatherSnapshot(
        locationLabel: '\u4e0a\u6d77 \u6d66\u4e1c',
        updatedAt: DateTime(2026, 7, 7, 9, 0),
        currentTemp: 31,
        apparentTemp: 34,
        humidity: 72,
        windKmh: 12,
        currentCode: 2,
        currentDescription: '\u591a\u4e91',
        sourceLabel: '\u9884\u89c8',
        reportTimeLabel: '09:00',
        days: const [
          WeatherDay(
            date: '2026-07-07',
            code: 2,
            description: '\u591a\u4e91',
            high: 33,
            low: 27,
          ),
          WeatherDay(
            date: '2026-07-08',
            code: 61,
            description: '\u5c0f\u96e8',
            high: 31,
            low: 26,
            precipitation: 65,
            uv: 6,
            windKmh: 18,
            clothingTip: '\u8f7b\u8584\u77ed\u8896\u5373\u53ef\u3002',
            umbrellaTip: '\u51fa\u95e8\u5e26\u4f1e\u66f4\u7a33\u3002',
            travelTip: '\u9519\u5cf0\u51fa\u884c\u66f4\u597d\u3002',
          ),
        ],
      ),
      initialBattery: const BatteryStatus(level: 86, isCharging: true),
    );
  }

  WeatherSnapshot? _weather;
  BatteryStatus _battery;
  bool _isSimpleMode = false;

  WeatherSnapshot? get weather => _weather;
  BatteryStatus get battery => _battery;
  bool get isSimpleMode => _isSimpleMode;

  void toggleSimpleMode() {
    _isSimpleMode = !_isSimpleMode;
    notifyListeners();
  }

  void setWeather(WeatherSnapshot snapshot) {
    _weather = snapshot;
    notifyListeners();
  }

  void setBattery(BatteryStatus status) {
    _battery = status;
    notifyListeners();
  }
}
