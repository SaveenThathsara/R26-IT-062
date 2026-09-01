import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/model_initializer.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const BetelQualityApp());

  // Pre-warm model in background so Analysis screen loads instantly
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ModelInitializer.instance.ensureReady();
  });
}

class BetelQualityApp extends StatelessWidget {
  const BetelQualityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Betel Quality AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
