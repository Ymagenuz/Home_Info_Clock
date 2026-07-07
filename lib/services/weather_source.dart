import '../models/weather.dart';

abstract class WeatherSource {
  Future<WeatherSnapshot> fetch(WeatherRequest request);
}
