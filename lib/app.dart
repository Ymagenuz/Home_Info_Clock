import 'package:flutter/material.dart';

import 'screens/home_clock_screen.dart';
import 'state/home_controller.dart';
import 'state/timer_controller.dart';

class HomeInfoClockApp extends StatelessWidget {
  const HomeInfoClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Info Clock',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: HomeClockScreen(
        homeController: HomeController.preview(),
        timerController: TimerController(),
      ),
    );
  }
}
