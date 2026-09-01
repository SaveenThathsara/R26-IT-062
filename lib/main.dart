import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const BetelInsectApp());
}

class BetelInsectApp extends StatelessWidget {
  const BetelInsectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Betel Insect Detector',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
