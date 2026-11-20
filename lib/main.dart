import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'route_observer.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const WheelShotApp());
}

class WheelShotApp extends StatelessWidget {
  const WheelShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF12141A);
    const accent = Color(0xFFE85D04);
    return MaterialApp(
      title: 'WheelShot',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          primary: accent,
          surface: ink,
        ),
        scaffoldBackgroundColor: ink,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
