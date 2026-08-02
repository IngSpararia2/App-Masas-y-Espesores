import 'package:flutter/material.dart';

import 'services/app_controller.dart';
import 'ui/app_shell.dart';
import 'ui/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(MasaLabApp(controller: controller));
  controller.initialize();
}

class MasaLabApp extends StatelessWidget {
  const MasaLabApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MasaLab Histórico',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF185FA5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xFFE1E7EF)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: SplashScreen(nextScreen: AppShell(controller: controller)),
    );
  }
}
