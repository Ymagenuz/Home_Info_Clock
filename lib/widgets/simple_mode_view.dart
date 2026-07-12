import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../models/weather.dart';
import '../painters/analog_clock_painter.dart';
import '../painters/weather_icon_painter.dart';

class SimpleModeView extends StatelessWidget {
  const SimpleModeView({
    super.key,
    required this.weather,
    required this.now,
    required this.onToggleMode,
    this.battery = const BatteryStatus.unavailable(),
  });

  final WeatherSnapshot? weather;
  final DateTime now;
  final VoidCallback onToggleMode;
  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '返回完整模式',
      child: GestureDetector(
        key: const ValueKey('simple-mode-view'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggleMode,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = math.max(34.0, constraints.maxWidth * 0.045);
              const gap = 28.0;
              final contentWidth = constraints.maxWidth - inset * 2;
              final leftWidth = contentWidth * 0.48;
              final rightWidth = contentWidth - leftWidth - gap;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Row(
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: _SimpleAnalogClock(now: now, battery: battery),
                    ),
                    const SizedBox(width: gap),
                    SizedBox(
                      width: rightWidth,
                      child: _SimpleDigitalWeather(now: now, weather: weather),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SimpleAnalogClock extends StatelessWidget {
  const _SimpleAnalogClock({required this.now, required this.battery});

  final DateTime now;
  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final batteryHeight = battery.isAvailable ? 48.0 : 0.0;
        final radius = math.min(
          constraints.maxWidth * 0.42,
          (constraints.maxHeight - batteryHeight - 28) * 0.43,
        );
        final diameter = radius * 2;
        final centerY = (constraints.maxHeight - batteryHeight) * 0.5;

        return Stack(
          children: [
            Positioned(
              left: (constraints.maxWidth - diameter) / 2,
              top: centerY - radius,
              width: diameter,
              height: diameter,
              child: RepaintBoundary(
                key: const ValueKey('simple-analog-clock'),
                child: CustomPaint(painter: AnalogClockPainter(now)),
              ),
            ),
            if (battery.isAvailable)
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(child: _CompactBattery(battery: battery)),
              ),
          ],
        );
      },
    );
  }
}

class _CompactBattery extends StatelessWidget {
  const _CompactBattery({required this.battery});

  final BatteryStatus battery;

  @override
  Widget build(BuildContext context) {
    final baseColor = battery.isCharging
        ? const Color(0xFF87EB9B)
        : battery.isLow
        ? const Color(0xFFFFA446)
        : const Color(0xFFF8F8FA);
    final level = battery.level.clamp(0, 100);

    return Row(
      key: const ValueKey('simple-compact-battery'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 39,
          height: 17,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 34,
                height: 17,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: baseColor, width: 1.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.all(2.5),
                      width: 27 * level / 100,
                      decoration: BoxDecoration(
                        color: baseColor.withAlpha(
                          battery.isCharging || battery.isLow ? 170 : 120,
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 36,
                top: 5,
                width: 3,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$level%',
          style: TextStyle(
            color: baseColor.withAlpha(
              battery.isCharging || battery.isLow ? 230 : 205,
            ),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        if (battery.isCharging) ...[
          const SizedBox(width: 4),
          Text(
            '⚡',
            style: TextStyle(color: baseColor, fontSize: 16, height: 1),
          ),
        ],
      ],
    );
  }
}

class _SimpleDigitalWeather extends StatelessWidget {
  const _SimpleDigitalWeather({required this.now, required this.weather});

  final DateTime now;
  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final digitalHeight = constraints.maxHeight * 0.55;
        final timeSize = _scaledSimpleTimeSize(constraints.maxHeight);

        return Column(
          children: [
            SizedBox(
              height: digitalHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      key: const ValueKey('simple-digital-time'),
                      '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}',
                      style: TextStyle(
                        color: const Color(0xE2F8F8FA),
                        fontSize: timeSize,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _simpleDateLabel(now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xAFF8F8FA),
                      fontSize: 19,
                      fontWeight: FontWeight.w400,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Expanded(child: _TomorrowSummary(weather: weather)),
          ],
        );
      },
    );
  }
}

class _TomorrowSummary extends StatelessWidget {
  const _TomorrowSummary({required this.weather});

  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final tomorrow = weather?.tomorrow;
    if (tomorrow == null) {
      return const Center(
        key: ValueKey('simple-tomorrow-summary'),
        child: Text(
          '等待天气数据',
          style: TextStyle(
            color: Color(0xFFF8F8FA),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('simple-tomorrow-summary'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'TOMORROW WEATHER',
          style: TextStyle(
            color: Color(0x4EF8F8FA),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox.square(
                dimension: 46,
                child: CustomPaint(
                  painter: WeatherIconPainter(
                    tomorrow.code,
                    const Color(0xFF68C4FF),
                  ),
                ),
              ),
            ),
            Expanded(child: _WeatherNumber('${tomorrow.high}°')),
            Expanded(child: _WeatherNumber('${tomorrow.low}°')),
            const Expanded(
              child: Icon(
                Icons.water_drop_outlined,
                size: 25,
                color: Color(0xFF68C4FF),
              ),
            ),
            Expanded(child: _WeatherNumber('${tomorrow.precipitation}%')),
          ],
        ),
      ],
    );
  }
}

class _WeatherNumber extends StatelessWidget {
  const _WeatherNumber(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xD7F8F8FA),
          fontSize: 31,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

double _scaledSimpleTimeSize(double height) {
  final progress = ((height - 320) / 150).clamp(0.0, 1.0);
  return 78 + 26 * progress;
}

String _simpleDateLabel(DateTime value) {
  const weekdays = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return '${value.year}-${_twoDigits(value.month)}-${_twoDigits(value.day)}  '
      '${weekdays[value.weekday - 1]}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
