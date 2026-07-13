import 'dart:async';

import 'package:flutter/material.dart';

class QuickActionsPanel extends StatelessWidget {
  const QuickActionsPanel({super.key, this.onOpenBilibili});

  final Future<void> Function()? onOpenBilibili;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.8,
          colors: [Color(0x26FB7299), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.smart_display_rounded,
            size: 36,
            color: Color(0xFFFF7DA3),
          ),
          const SizedBox(height: 8),
          Text(
            'Bilibili',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\u6253\u5f00\u54d4\u54e9\u54d4\u54e9 App',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xB9E0F2EB)),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 178),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7DA3), Color(0xFF43C4FF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x55FFFFFF)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('bilibili-open-button'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: onOpenBilibili == null
                        ? null
                        : () => unawaited(onOpenBilibili!()),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\u6253\u5f00 Bilibili',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
