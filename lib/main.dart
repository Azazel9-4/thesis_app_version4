import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';  

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E2C),
        cardTheme: const CardThemeData(color: Color(0xFF121430)),
      ),
      home: const SplashScreen(), // start with splash
    );
  }
}
