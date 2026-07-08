import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/state/timer_controller.dart';
import 'package:home_info_clock/widgets/timer_panel.dart';

void main() {
  testWidgets('TimerPanel changes minute value and starts', (tester) async {
    final controller = TimerController();

    await tester.pumpWidget(
      MaterialApp(home: TimerPanel(controller: controller)),
    );

    await tester.tap(find.byKey(const ValueKey('timer-minute-plus')));
    await tester.pump();
    expect(controller.state.minutes, 1);

    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pump();
    expect(controller.state.isRunning, isTrue);
  });
}
