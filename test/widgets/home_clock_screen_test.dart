import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/screens/home_clock_screen.dart';
import 'package:home_info_clock/state/home_controller.dart';
import 'package:home_info_clock/state/timer_controller.dart';

void main() {
  testWidgets('HomeClockScreen renders the three dashboard regions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomeClockScreen(
          homeController: HomeController.preview(),
          timerController: TimerController(),
        ),
      ),
    );

    expect(find.text('涓婃捣 娴︿笢'), findsOneWidget);
    expect(find.text('Bilibili'), findsOneWidget);
    expect(find.textContaining('灏忛洦'), findsWidgets);
  });
}
