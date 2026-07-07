class WeatherRequest {
  const WeatherRequest({
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
  });

  final double latitude;
  final double longitude;
  final String locationLabel;
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.locationLabel,
    required this.updatedAt,
    required this.currentTemp,
    required this.apparentTemp,
    required this.humidity,
    required this.windKmh,
    required this.currentCode,
    required this.currentDescription,
    required this.sourceLabel,
    required this.reportTimeLabel,
    this.forecastAvailable = true,
    this.days = const [],
  });

  final String locationLabel;
  final DateTime updatedAt;
  final int currentTemp;
  final int apparentTemp;
  final int humidity;
  final int windKmh;
  final int currentCode;
  final String currentDescription;
  final String sourceLabel;
  final String reportTimeLabel;
  final bool forecastAvailable;
  final List<WeatherDay> days;

  WeatherDay? get today => days.isEmpty ? null : days.first;
  WeatherDay? get tomorrow => days.length < 2 ? null : days[1];
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.code,
    required this.description,
    required this.high,
    required this.low,
    this.icon = '',
    this.precipitation = 0,
    this.uv = 0,
    this.windKmh = 0,
    this.windDirection,
    this.clothingTip,
    this.umbrellaTip,
    this.sportTip,
    this.travelTip,
    this.sunProtectionTip,
  });

  final String date;
  final int code;
  final String description;
  final String icon;
  final int high;
  final int low;
  final int precipitation;
  final int uv;
  final int windKmh;
  final String? windDirection;
  final String? clothingTip;
  final String? umbrellaTip;
  final String? sportTip;
  final String? travelTip;
  final String? sunProtectionTip;

  int get temperatureRange => (high - low).abs();
}
