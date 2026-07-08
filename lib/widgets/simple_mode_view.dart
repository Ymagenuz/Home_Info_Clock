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
    final location = snapshot?.locationLabel ?? '\u7b49\u5f85\u5b9a\u4f4d';
    final description =
        snapshot?.currentDescription ?? '\u7b49\u5f85\u5929\u6c14';

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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
