import '../models/weather.dart';

WeatherSnapshot ensureLocalWeatherAdvice(WeatherSnapshot snapshot) {
  if (snapshot.days.isEmpty) {
    return snapshot;
  }
  return snapshot.copyWith(
    days: snapshot.days.map(_ensureDayAdvice).toList(growable: false),
  );
}

WeatherDay _ensureDayAdvice(WeatherDay day) {
  return day.copyWith(
    clothingTip: _present(day.clothingTip) ?? _clothingAdvice(day),
    umbrellaTip: _present(day.umbrellaTip) ?? _umbrellaAdvice(day),
    travelTip: _present(day.travelTip) ?? _travelAdvice(day),
  );
}

String? _present(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : value;
}

String _clothingAdvice(WeatherDay day) {
  if (day.low <= 8) {
    return '\u6c14\u6e29\u504f\u4f4e\uff0c\u8bf7\u7a7f\u4fdd\u6696\u5916\u5957\u3002';
  }
  if (day.low <= 16 || day.temperatureRange >= 10) {
    return '\u65e9\u665a\u504f\u51c9\uff0c\u5efa\u8bae\u5907\u8584\u5916\u5957\u3002';
  }
  if (day.high >= 30) {
    return '\u5929\u6c14\u504f\u70ed\uff0c\u9009\u8f7b\u8584\u900f\u6c14\u8863\u7269\u3002';
  }
  return '\u6e29\u5ea6\u8212\u9002\uff0c\u8f7b\u4fbf\u7740\u88c5\u5373\u53ef\u3002';
}

String _umbrellaAdvice(WeatherDay day) {
  final wetCode =
      (day.code >= 51 && day.code <= 99) ||
      day.description.contains('\u96e8') ||
      day.description.contains('\u96ea');
  if (day.precipitation >= 50 || wetCode) {
    return '\u6709\u964d\u6c34\u53ef\u80fd\uff0c\u51fa\u95e8\u8bf7\u5e26\u4f1e\u3002';
  }
  if (day.precipitation > 20) {
    return '\u53ef\u80fd\u77ed\u65f6\u964d\u6c34\uff0c\u5efa\u8bae\u5907\u4f1e\u3002';
  }
  return '\u964d\u6c34\u6982\u7387\u8f83\u4f4e\uff0c\u65e0\u9700\u7279\u610f\u5e26\u4f1e\u3002';
}

String _travelAdvice(WeatherDay day) {
  if (day.windKmh >= 30) {
    return '\u98ce\u529b\u504f\u5927\uff0c\u51fa\u884c\u6ce8\u610f\u9635\u98ce\u3002';
  }
  if (day.precipitation >= 50) {
    return '\u8def\u9762\u53ef\u80fd\u6e7f\u6ed1\uff0c\u9884\u7559\u51fa\u884c\u65f6\u95f4\u3002';
  }
  if (day.uv >= 7) {
    return '\u7d2b\u5916\u7ebf\u8f83\u5f3a\uff0c\u51fa\u884c\u6ce8\u610f\u9632\u6652\u3002';
  }
  return '\u5929\u6c14\u5e73\u7a33\uff0c\u9002\u5408\u65e5\u5e38\u51fa\u884c\u3002';
}
