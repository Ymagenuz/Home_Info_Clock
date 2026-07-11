import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/timer_state.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/timer_panel.dart';

void main() {
  testWidgets('TimerPanel changes minute value and starts', (tester) async {
    final controller = TimerController();
    final now = DateTime(2026, 7, 9, 9);

    await tester.pumpWidget(
      MaterialApp(
        home: TimerPanel(controller: controller, now: now),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('timer-minute-plus')));
    await tester.pump();
    expect(controller.state.minutes, 1);

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();
    expect(controller.state.isRunning, isTrue);
  });

  testWidgets('TimerPanel does not own the screen-global finished overlay', (
    tester,
  ) async {
    final controller = TimerController(
      initial: const TimerState(isFinished: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TimerPanel(controller: controller, now: DateTime(2026, 7, 9, 9)),
      ),
    );

    expect(find.byKey(const ValueKey('timer-finished-overlay')), findsNothing);
    expect(find.text('Finished'), findsOneWidget);
    expect(controller.state.isFinished, isTrue);
  });
}
