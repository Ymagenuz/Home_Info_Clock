import 'package:flutter/material.dart';

class ClockPanel extends StatelessWidget {
  const ClockPanel({super.key, required this.onToggleMode});

  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeLabel = '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}';
    final dateLabel =
        '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Home Info Clock',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xCCFFFFFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Simple mode',
                onPressed: onToggleMode,
                icon: const Icon(Icons.fullscreen_exit),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xB3FFFFFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 132,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ready',
                    style: TextStyle(
                      color: Color(0xFF93E5AB),
                      fontWeight: FontWeight.w700,
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
