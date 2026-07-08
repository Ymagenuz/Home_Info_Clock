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

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      locationLabel: json['locationLabel'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      currentTemp: (json['currentTemp'] as num).toInt(),
      apparentTemp: (json['apparentTemp'] as num).toInt(),
      humidity: (json['humidity'] as num).toInt(),
      windKmh: (json['windKmh'] as num).toInt(),
      currentCode: (json['currentCode'] as num).toInt(),
      currentDescription: json['currentDescription'] as String,
      sourceLabel: json['sourceLabel'] as String,
      reportTimeLabel: json['reportTimeLabel'] as String,
      forecastAvailable: json['forecastAvailable'] as bool? ?? true,
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((day) => WeatherDay.fromJson(day as Map<String, dynamic>))
          .toList(),
    );
  }

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

  WeatherSnapshot copyWith({
    String? locationLabel,
    DateTime? updatedAt,
    int? currentTemp,
    int? apparentTemp,
    int? humidity,
    int? windKmh,
    int? currentCode,
    String? currentDescription,
    String? sourceLabel,
    String? reportTimeLabel,
    bool? forecastAvailable,
    List<WeatherDay>? days,
  }) {
    return WeatherSnapshot(
      locationLabel: locationLabel ?? this.locationLabel,
      updatedAt: updatedAt ?? this.updatedAt,
      currentTemp: currentTemp ?? this.currentTemp,
      apparentTemp: apparentTemp ?? this.apparentTemp,
      humidity: humidity ?? this.humidity,
      windKmh: windKmh ?? this.windKmh,
      currentCode: currentCode ?? this.currentCode,
      currentDescription: currentDescription ?? this.currentDescription,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      reportTimeLabel: reportTimeLabel ?? this.reportTimeLabel,
      forecastAvailable: forecastAvailable ?? this.forecastAvailable,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationLabel': locationLabel,
      'updatedAt': updatedAt.toIso8601String(),
      'currentTemp': currentTemp,
      'apparentTemp': apparentTemp,
      'humidity': humidity,
      'windKmh': windKmh,
      'currentCode': currentCode,
      'currentDescription': currentDescription,
      'sourceLabel': sourceLabel,
      'reportTimeLabel': reportTimeLabel,
      'forecastAvailable': forecastAvailable,
      'days': days.map((day) => day.toJson()).toList(),
    };
  }
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

  factory WeatherDay.fromJson(Map<String, dynamic> json) {
    return WeatherDay(
      date: json['date'] as String,
      code: (json['code'] as num).toInt(),
      description: json['description'] as String,
      icon: json['icon'] as String? ?? '',
      high: (json['high'] as num).toInt(),
      low: (json['low'] as num).toInt(),
      precipitation: (json['precipitation'] as num?)?.toInt() ?? 0,
      uv: (json['uv'] as num?)?.toInt() ?? 0,
      windKmh: (json['windKmh'] as num?)?.toInt() ?? 0,
      windDirection: json['windDirection'] as String?,
      clothingTip: json['clothingTip'] as String?,
      umbrellaTip: json['umbrellaTip'] as String?,
      sportTip: json['sportTip'] as String?,
      travelTip: json['travelTip'] as String?,
      sunProtectionTip: json['sunProtectionTip'] as String?,
    );
  }

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

  WeatherDay copyWith({
    String? date,
    int? code,
    String? description,
    String? icon,
    int? high,
    int? low,
    int? precipitation,
    int? uv,
    int? windKmh,
    String? windDirection,
    String? clothingTip,
    String? umbrellaTip,
    String? sportTip,
    String? travelTip,
    String? sunProtectionTip,
  }) {
    return WeatherDay(
      date: date ?? this.date,
      code: code ?? this.code,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      high: high ?? this.high,
      low: low ?? this.low,
      precipitation: precipitation ?? this.precipitation,
      uv: uv ?? this.uv,
      windKmh: windKmh ?? this.windKmh,
      windDirection: windDirection ?? this.windDirection,
      clothingTip: clothingTip ?? this.clothingTip,
      umbrellaTip: umbrellaTip ?? this.umbrellaTip,
      sportTip: sportTip ?? this.sportTip,
      travelTip: travelTip ?? this.travelTip,
      sunProtectionTip: sunProtectionTip ?? this.sunProtectionTip,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'code': code,
      'description': description,
      'icon': icon,
      'high': high,
      'low': low,
      'precipitation': precipitation,
      'uv': uv,
      'windKmh': windKmh,
      'windDirection': windDirection,
      'clothingTip': clothingTip,
      'umbrellaTip': umbrellaTip,
      'sportTip': sportTip,
      'travelTip': travelTip,
      'sunProtectionTip': sunProtectionTip,
    };
  }
}
