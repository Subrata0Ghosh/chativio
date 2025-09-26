import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/screens/bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/onboarding_screen.dart';



class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animation for pulse effect
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.9, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Navigate to home after 4s
    Timer(const Duration(seconds: 4), ()async {

      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool("isFirstLaunch") ?? true;

      if (!mounted) return; // ✅ prevent using context if widget is disposed

      if (isFirstLaunch) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainWrapper()),
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
      // backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated glowing logo
            ScaleTransition(
              scale: _animation,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withValues(alpha:0.6),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 65,
                ),
              ),
            ),
            const SizedBox(height: 25),
            // App Name
            const Text(
              "Chativio",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                // color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            const Text(
              "Your AI Friend, Always Here 💙",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),
            // Futuristic Loading Bar
            SizedBox(
              width: 120,
              height: 4,
              
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeInOut,
                tween: Tween<double>(begin: 0, end: 1.0),
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
                    ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor:
                          Colors.transparent, // important for gradient
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


