import 'dart:async';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextScreen});

  final Widget nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _creditTimer;
  Timer? _navigationTimer;
  bool _showCredit = false;
  bool _showNextScreen = false;

  @override
  void initState() {
    super.initState();
    _creditTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _showCredit = true);
      }
    });
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showNextScreen = true);
      }
    });
  }

  @override
  void dispose() {
    _creditTimer?.cancel();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showNextScreen) {
      return widget.nextScreen;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF082F43),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/branding/splash_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedSlide(
                  offset: _showCredit ? Offset.zero : const Offset(0, 0.45),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _showCredit ? 1 : 0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOut,
                    child: const Text(
                      'Developed by Ing. Samuel Parariá',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
