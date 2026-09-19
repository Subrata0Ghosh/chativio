import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _shimmerController;

  late Animation<double> _pulseAnim;
  late Animation<double> _coreScaleAnim;

  final List<_NeuralParticle> _particles = [];
  final List<_TouchRipple> _ripples = [];
  final math.Random _random = math.Random();

  String _statusMessage = "Calibrating Neural Matrix...";

  @override
  void initState() {
    super.initState();

    // 1. Core breathing pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutCubic,
    );

    _coreScaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(_pulseAnim);

    // 2. Gyroscope orbital ring rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // 3. Typographic shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Spawn 32 organic neural particles
    for (int i = 0; i < 32; i++) {
      _particles.add(
        _NeuralParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          vx: (_random.nextDouble() - 0.5) * 0.0018,
          vy: (_random.nextDouble() - 0.5) * 0.0018,
          radius: 1.5 + _random.nextDouble() * 2.5,
          baseAlpha: 0.25 + _random.nextDouble() * 0.45,
          color: i % 2 == 0 ? const Color(0xFF6366F1) : const Color(0xFF38BDF8),
        ),
      );
    }

    // Staged status ticker updates
    Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _statusMessage = "Synchronizing Voice Models...");
      }
    });
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _statusMessage = "Chativio Neural Core Ready");
      }
    });

    // Snappy navigation transition
    Timer(const Duration(milliseconds: 2400), () async {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch = prefs.getBool("isFirstLaunch") ?? true;

      if (!mounted) return;

      final Widget nextScreen = isFirstLaunch
          ? const OnboardingScreen()
          : const MainWrapper();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a1, a2) => nextScreen,
          transitionsBuilder: (context, a1, a2, child) =>
              FadeTransition(opacity: a1, child: child),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    });
  }

  void _addTouchRipple(Offset pos, Size size) {
    HapticFeedback.lightImpact();
    setState(() {
      _ripples.add(
        _TouchRipple(
          origin: Offset(pos.dx / size.width, pos.dy / size.height),
          progress: 0.0,
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: GestureDetector(
        onPanDown: (details) => _addTouchRipple(details.localPosition, size),
        onPanUpdate: (details) => _addTouchRipple(details.localPosition, size),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Interactive Neural Mesh & Ripple Canvas
            AnimatedBuilder(
              animation: Listenable.merge([
                _rotationController,
                _pulseController,
              ]),
              builder: (context, child) {
                // Advance ripples
                for (int i = _ripples.length - 1; i >= 0; i--) {
                  _ripples[i].progress += 0.035;
                  if (_ripples[i].progress >= 1.0) {
                    _ripples.removeAt(i);
                  }
                }

                // Advance particle drift
                for (final p in _particles) {
                  p.x = (p.x + p.vx) % 1.0;
                  p.y = (p.y + p.vy) % 1.0;
                  if (p.x < 0) p.x += 1.0;
                  if (p.y < 0) p.y += 1.0;
                }

                return CustomPaint(
                  painter: _NeuralMeshPainter(
                    particles: _particles,
                    ripples: _ripples,
                    pulse: _pulseAnim.value,
                  ),
                );
              },
            ),

            // 2. Centerpiece: 3D Holographic AI Gyroscope Core
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Radial Core Glow
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (context, child) {
                            return Container(
                              width: 190 * _coreScaleAnim.value,
                              height: 190 * _coreScaleAnim.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.38),
                                    const Color(
                                      0xFF38BDF8,
                                    ).withValues(alpha: 0.18),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            );
                          },
                        ),

                        // Outer 3D Gyroscopic Ring (Tilted X, Rotating Z)
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            final angle =
                                _rotationController.value * 2 * math.pi;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0018)
                                ..rotateX(0.7)
                                ..rotateZ(angle),
                              child: Container(
                                width: 190,
                                height: 190,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF38BDF8,
                                    ).withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Inner Counter-Rotating 3D Gyroscopic Ring (Tilted Y, Rotating Counter)
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            final angle =
                                -_rotationController.value * 2 * math.pi;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0018)
                                ..rotateY(0.75)
                                ..rotateZ(angle * 1.3),
                              child: Container(
                                width: 156,
                                height: 156,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(
                                      0xFF818CF8,
                                    ).withValues(alpha: 0.4),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Central Radiant Emblem Core
                        ScaleTransition(
                          scale: _coreScaleAnim,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF38BDF8,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 48,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(55),
                              child: Image.asset(
                                "assets/images/logo.png",
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF38BDF8),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 3. Shimmering Holographic Typography
                  AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      final shimmerVal = _shimmerController.value;
                      return ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            colors: const [
                              Colors.white,
                              Color(0xFFE0E7FF),
                              Color(0xFF38BDF8),
                              Colors.white,
                            ],
                            stops: [
                              (shimmerVal - 0.25).clamp(0.0, 1.0),
                              (shimmerVal - 0.1).clamp(0.0, 1.0),
                              (shimmerVal + 0.1).clamp(0.0, 1.0),
                              (shimmerVal + 0.25).clamp(0.0, 1.0),
                            ],
                          ).createShader(bounds);
                        },
                        child: Text(
                          "Chativio",
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Intelligent • Empathetic • Always Here",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.0,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 4. Sleek Futuristic Status Ticker
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 8,
                          height: 8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF38BDF8).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _statusMessage,
                            key: ValueKey(_statusMessage),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeuralParticle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double baseAlpha;
  Color color;

  _NeuralParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.baseAlpha,
    required this.color,
  });
}

class _TouchRipple {
  final Offset origin;
  double progress;

  _TouchRipple({required this.origin, required this.progress});
}

class _NeuralMeshPainter extends CustomPainter {
  final List<_NeuralParticle> particles;
  final List<_TouchRipple> ripples;
  final double pulse;

  _NeuralMeshPainter({
    required this.particles,
    required this.ripples,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 1. Draw Synaptic Connection Web Lines
    for (int i = 0; i < particles.length; i++) {
      final p1 = particles[i];
      final pos1 = Offset(p1.x * size.width, p1.y * size.height);

      for (int j = i + 1; j < particles.length; j++) {
        final p2 = particles[j];
        final pos2 = Offset(p2.x * size.width, p2.y * size.height);
        final dist = (pos1 - pos2).distance;

        // Connect if within 110 pixels
        if (dist < 110) {
          final alpha = (1.0 - (dist / 110)) * 0.28 * (0.8 + 0.2 * pulse);
          linePaint.color = const Color(0xFF6366F1).withValues(alpha: alpha);
          canvas.drawLine(pos1, pos2, linePaint);
        }
      }
    }

    // 2. Draw Touch Ripple Waves
    for (final r in ripples) {
      final center = Offset(
        r.origin.dx * size.width,
        r.origin.dy * size.height,
      );
      final radius = r.progress * 180;
      final alpha = (1.0 - r.progress) * 0.35;
      final ripplePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF38BDF8).withValues(alpha: alpha);
      canvas.drawCircle(center, radius, ripplePaint);
    }

    // 3. Draw Particle Nodes
    for (final p in particles) {
      final center = Offset(p.x * size.width, p.y * size.height);
      final dynamicAlpha = (p.baseAlpha * (0.85 + 0.15 * pulse)).clamp(
        0.0,
        1.0,
      );
      particlePaint.color = p.color.withValues(alpha: dynamicAlpha);
      canvas.drawCircle(center, p.radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralMeshPainter oldDelegate) => true;
}
