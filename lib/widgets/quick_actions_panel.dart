import 'package:flutter/material.dart';

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_display, color: Color(0xFFFF8A80)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bilibili',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: IconButton.filledTonal(
                    tooltip: 'Open video',
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IconButton.filledTonal(
                    tooltip: 'Refresh',
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IconButton.filledTonal(
                    tooltip: 'Settings',
                    onPressed: () {},
                    icon: const Icon(Icons.tune),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
