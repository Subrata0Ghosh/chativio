import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Navigate to home after 2.2s for snappy experience
    Timer(const Duration(milliseconds: 2200), () async {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool("isFirstLaunch") ?? true;

      if (!mounted) return;

      if (isFirstLaunch) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a1, a2) => const OnboardingScreen(),
            transitionsBuilder: (context, a1, a2, child) =>
                FadeTransition(opacity: a1, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, a1, a2) => const MainWrapper(),
            transitionsBuilder: (context, a1, a2, child) =>
                FadeTransition(opacity: a1, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B14),
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated bespoke 3D logo
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF06B6D4,
                            ).withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFF6366F1,
                            ).withValues(alpha: 0.3),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(70),
                        child: Image.asset(
                          "assets/images/logo.png",
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFF0F172A),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFF38BDF8),
                                  size: 60,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Brand name with Apple typographic styling
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      "Chativio",
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Text(
                      "Intelligent • Empathetic • Always Here",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Minimal iOS Loading Indicator
                  SizedBox(
                    width: 100,
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0x33FFFFFF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
