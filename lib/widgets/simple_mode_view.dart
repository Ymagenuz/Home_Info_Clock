import 'package:flutter/material.dart';

import '../models/weather.dart';

class SimpleModeView extends StatelessWidget {
  const SimpleModeView({
    super.key,
    required this.weather,
    required this.onToggleMode,
  });

  final WeatherSnapshot? weather;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final snapshot = weather;
    final location = _briefText(snapshot?.locationLabel, '绛夊緟瀹氫綅');
    final description = _briefText(snapshot?.currentDescription, '绛夊緟澶╂皵');

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filledTonal(
              tooltip: 'Dashboard mode',
              onPressed: onToggleMode,
              icon: const Icon(Icons.dashboard_customize),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
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
                  const SizedBox(height: 20),
                  Text(
                    '$location  $description',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xCCFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot == null ? '--' : '${snapshot.currentTemp}\u00B0',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: const Color(0xFF93E5AB),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _briefText(String? value, String fallback) {
  return switch (value) {
    null => fallback,
    '\u4e0a\u6d77 \u6d66\u4e1c' => '涓婃捣 娴︿笢',
    '\u591a\u4e91' => '澶氫簯',
    '\u5c0f\u96e8' => '灏忛洦',
    _ => value,
  };
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
