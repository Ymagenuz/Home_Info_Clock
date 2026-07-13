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
  });

  final WeatherSnapshot? weather;
  final WeatherStatus status;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final days = weather?.days ?? const <WeatherDay>[];
    final range = _temperatureRange(days);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WeatherStatusHeader(
            weather: weather,
            status: status,
            isRefreshing: isRefreshing,
            title: '\u5929\u6c14\u8d8b\u52bf',
          ),
          const SizedBox(height: 8),
          Expanded(
            key: const ValueKey('weather-trend-temperature-list'),
            child: days.isEmpty
                ? const _EmptyTrend()
                : ListView.builder(
                    key: const ValueKey('weather-trend-list'),
                    physics: const ClampingScrollPhysics(),
                    itemExtent: 42,
                    itemCount: days.length,
                    itemBuilder: (context, index) => _TrendDay(
                      key: ValueKey('weather-trend-temperature-row-$index'),
                      day: days[index],
                      index: index,
                      minTemp: range.$1,
                      maxTemp: range.$2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrendDay extends StatelessWidget {
  const _TrendDay({
    super.key,
    required this.day,
    required this.index,
    required this.minTemp,
    required this.maxTemp,
  });

  final WeatherDay day;
  final int index;
  final int minTemp;
  final int maxTemp;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              _dayLabel(index, day.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: const Color(0xBFE0F2EB)),
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(
              painter: WeatherIconPainter(day.code, const Color(0xFF7DD3FC)),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 30,
            child: Text(
              '${day.low}\u00B0',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFE0F2EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: SizedBox(
              height: 12,
              child: CustomPaint(
                painter: _TemperatureRangePainter(
                  low: day.low,
                  high: day.high,
                  minimum: minTemp,
                  maximum: maxTemp,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 30,
            child: Text(
              '${day.high}\u00B0',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFFE0F2EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureRangePainter extends CustomPainter {
  const _TemperatureRangePainter({
    required this.low,
    required this.high,
    required this.minimum,
    required this.maximum,
  });

  final int low;
  final int high;
  final int minimum;
  final int maximum;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final track = Paint()
      ..color = const Color(0x37DCEBE5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawLine(Offset(3, centerY), Offset(size.width - 3, centerY), track);

    final spread = (maximum - minimum).clamp(1, 1000);
    final usableWidth = (size.width - 6).clamp(1.0, double.infinity);
    final lowX = 3 + usableWidth * (low - minimum) / spread;
    final highX = 3 + usableWidth * (high - minimum) / spread;
    final value = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFF7BD9C4), Color(0xFFF5CF65)],
          ).createShader(
            Rect.fromLTWH(
              lowX,
              0,
              (highX - lowX).clamp(1, usableWidth),
              size.height,
            ),
          )
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawLine(Offset(lowX, centerY), Offset(highX, centerY), value);
  }

  @override
  bool shouldRepaint(covariant _TemperatureRangePainter oldDelegate) =>
      oldDelegate.low != low ||
      oldDelegate.high != high ||
      oldDelegate.minimum != minimum ||
      oldDelegate.maximum != maximum;
}

(int, int) _temperatureRange(List<WeatherDay> days) {
  if (days.isEmpty) return (0, 1);
  var minimum = days.first.low;
  var maximum = days.first.high;
  for (final day in days.skip(1)) {
    if (day.low < minimum) minimum = day.low;
    if (day.high > maximum) maximum = day.high;
  }
  if (minimum == maximum) return (minimum - 1, maximum + 1);
  return (minimum, maximum);
}

String _dayLabel(int index, String date) {
  if (index == 0) return '\u4eca\u5929';
  if (index == 1) return '\u660e\u5929';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  const weekdays = <String>[
    '\u5468\u4e00',
    '\u5468\u4e8c',
    '\u5468\u4e09',
    '\u5468\u56db',
    '\u5468\u4e94',
    '\u5468\u516d',
    '\u5468\u65e5',
  ];
  return weekdays[parsed.weekday - 1];
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
