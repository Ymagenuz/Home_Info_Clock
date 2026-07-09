import 'package:flutter/material.dart';

import '../models/weather.dart';
import 'tomorrow_panel.dart';

class SimpleModeView extends StatelessWidget {
  const SimpleModeView({
    super.key,
    required this.weather,
    required this.now,
    required this.onToggleMode,
  });

  final WeatherSnapshot? weather;
  final DateTime now;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final snapshot = weather;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: _ClockColumn(
                  key: const ValueKey('simple-clock-column'),
                  now: now,
                  weather: snapshot,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: VerticalDivider(color: Color(0x22FFFFFF), width: 1),
              ),
              Expanded(
                flex: 4,
                child: TomorrowPanel(
                  key: const ValueKey('simple-tomorrow-column'),
                  weather: snapshot,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filledTonal(
            tooltip: 'Dashboard mode',
            onPressed: onToggleMode,
            icon: const Icon(Icons.dashboard_customize),
          ),
        ),
      ],
    );
  }
}

class _ClockColumn extends StatelessWidget {
  const _ClockColumn({super.key, required this.now, required this.weather});

  final DateTime now;
  final WeatherSnapshot? weather;

  @override
  Widget build(BuildContext context) {
    final location = weather?.locationLabel ?? '\u7b49\u5f85\u5b9a\u4f4d';
    final description =
        weather?.currentDescription ?? '\u7b49\u5f85\u5929\u6c14';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 150,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFFFD166),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$location  $description',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xCCFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
