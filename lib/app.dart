import 'package:flutter/material.dart';

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
      home: const Scaffold(
        backgroundColor: Color(0xFF061016),
        body: Center(child: Text('Home Info Clock')),
      ),
    );
  }
}
