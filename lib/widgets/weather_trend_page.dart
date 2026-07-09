import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import '../state/home_controller.dart';
import 'weather_status_header.dart';

class WeatherTrendPage extends StatelessWidget {
  const WeatherTrendPage({
    super.key,
    required this.weather,
    required this.status,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final WeatherSnapshot? weather;
  final WeatherStatus status;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('weather-trend-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          WeatherStatusHeader(
            weather: weather,
            status: status,
            isRefreshing: isRefreshing,
            title: 'Weather trend',
          ),
          const SizedBox(height: 14),
          if (weather?.days.isNotEmpty ?? false)
            ...weather!.days.map((day) => _TrendDay(day: day))
          else
            const _EmptyTrend(),
        ],
      ),
    );
  }
}

class _TrendDay extends StatelessWidget {
  const _TrendDay({required this.day});

  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0x12FFFFFF),
      child: ListTile(
        dense: true,
        leading: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(
            painter: WeatherIconPainter(day.code, const Color(0xFF7DD3FC)),
          ),
        ),
        title: Text(
          '${day.date}  ${day.description}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('Rain ${day.precipitation}%'),
        trailing: Text('${day.low}\u00B0 / ${day.high}\u00B0'),
      ),
    );
  }
}

class _EmptyTrend extends StatelessWidget {
  const _EmptyTrend();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(child: Text('Weather trend unavailable')),
    );
  }
}
