import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../painters/weather_icon_painter.dart';
import '../state/home_controller.dart';
import 'weather_status_header.dart';

class WeatherCurrentPage extends StatelessWidget {
  const WeatherCurrentPage({
    super.key,
    required this.weather,
    required this.locationLabel,
    required this.battery,
    required this.status,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onLocationTap,
  });

  final WeatherSnapshot? weather;
  final String locationLabel;
  final BatteryStatus battery;
  final WeatherStatus status;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight <= 390;
        final padding = compact ? 14.0 : 18.0;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            key: const ValueKey('weather-current-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(padding),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      WeatherStatusHeader(
                        weather: weather,
                        locationLabel: locationLabel,
                        status: status,
                        isRefreshing: isRefreshing,
                        onLocationTap: onLocationTap,
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      SizedBox(
                        key: const ValueKey('current-weather-compact-summary'),
                        height: compact ? 82 : 96,
                        child: _CompactWeatherSummary(weather: weather),
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      SizedBox(
                        height: compact ? 86 : 98,
                        child: _WeatherMetricRings(weather: weather),
                      ),
                      SizedBox(height: compact ? 18 : 22),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 4 : 6,
                        ),
                        child: _BatteryStrip(battery: battery),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactWeatherSummary extends StatelessWidget {
  const _CompactWeatherSummary({required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final description =
        snapshot?.currentDescription ?? '\u7b49\u5f85\u5929\u6c14';
    final temp = snapshot == null ? '--' : '${snapshot.currentTemp}\u00B0';
    final today = snapshot?.days.isNotEmpty ?? false
        ? snapshot!.days.first
        : null;
    final highLow = today == null
        ? '--\u00B0/--\u00B0'
        : '${today.high}\u00B0/${today.low}\u00B0';

    return Row(
      children: [
        SizedBox(
          width: 58,
          height: 58,
          child: CustomPaint(
            painter: WeatherIconPainter(
              snapshot?.currentCode ?? 0,
              const Color(0xFF93E5AB),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        temp,
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              color: const Color(0xFFEEFAF6),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomRight,
                      child: Text(
                        highLow,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: const Color(0xDDE8F1EC)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeatherMetricRings extends StatelessWidget {
  const _WeatherMetricRings({required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    final today = snapshot?.days.isNotEmpty ?? false
        ? snapshot!.days.first
        : null;
    final humidity = snapshot?.humidity ?? 0;
    final precipitation = today?.precipitation ?? 0;
    final uv = today?.uv ?? 0;

    return Row(
      children: [
        Expanded(
          child: _WeatherMetricRing(
            key: const ValueKey('weather-metric-humidity'),
            label: '\u6e7f\u5ea6',
            value: snapshot == null ? '--' : '$humidity%',
            progress: humidity / 100,
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF70E0CC),
          ),
        ),
        Expanded(
          child: _WeatherMetricRing(
            key: const ValueKey('weather-metric-precipitation'),
            label: '\u964d\u6c34',
            value: today == null ? '--' : '$precipitation%',
            progress: precipitation / 100,
            icon: Icons.grain,
            color: const Color(0xFF68C4FF),
          ),
        ),
        Expanded(
          child: _WeatherMetricRing(
            key: const ValueKey('weather-metric-uv'),
            label: '\u7d2b\u5916\u7ebf',
            value: today == null ? '--' : '$uv ${_uvLevel(uv)}',
            progress: uv / 11,
            icon: Icons.wb_sunny_outlined,
            color: const Color(0xFFFFD769),
          ),
        ),
      ],
    );
  }
}

class _WeatherMetricRing extends StatelessWidget {
  const _WeatherMetricRing({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final double progress;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _MetricRingPainter(progress: progress, color: color),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: const Color(0xB2E0F2EB)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFEEFAF6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRingPainter extends CustomPainter {
  const _MetricRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.shortestSide * 0.12;
    final arcRect = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0x22DCEBE5);
    final value = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = color;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2, false, track);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      value,
    );
  }

  @override
  bool shouldRepaint(covariant _MetricRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _BatteryStrip extends StatelessWidget {
  const _BatteryStrip({required this.battery});

  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final available = battery.isAvailable;
    final level = available ? battery.level.clamp(0, 100) : 0;
    final low = battery.isLow;
    final color = battery.isCharging
        ? const Color(0xFF87EB9B)
        : low
        ? const Color(0xFFFFAE5C)
        : const Color(0xFFACC0FF);
    final state = !available
        ? '--'
        : battery.isCharging
        ? '\u5145\u7535\u4e2d'
        : '\u672a\u5145\u7535';

    return Column(
      key: const ValueKey('weather-battery-strip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              available ? '\u7535\u91cf $level%' : '\u7535\u91cf --',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: const Color(0xBCE0F2EB)),
            ),
            const Spacer(),
            Text(
              state,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: level / 100,
            backgroundColor: color.withAlpha(40),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

String _uvLevel(int uv) {
  if (uv >= 8) return '\u5f3a';
  if (uv >= 6) return '\u8f83\u5f3a';
  if (uv >= 3) return '\u4e2d';
  return '\u4f4e';
}
