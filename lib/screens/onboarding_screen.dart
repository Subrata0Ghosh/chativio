import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/bottom_navigation.dart';
import 'package:myapp/services/natural_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userNameController = TextEditingController(
    text: "Friend",
  );
  String _userGender = "Not set";
  final TextEditingController _aiNameController = TextEditingController(
    text: "Chativio",
  );
  String _aiGender = "Not set";
  String _selectedVoice = "ava";

  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Visual Animation Controllers
  late AnimationController _rotationController;
  late AnimationController _soundwaveController;
  late AnimationController _zenController;

  bool _isPlayingVoiceSample = false;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _soundwaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _zenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _userNameController.addListener(() {
      if (mounted) setState(() {});
    });
    _aiNameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_isPlayingVoiceSample) {
      NaturalVoiceService.instance.stop();
    }
    _pageController.dispose();
    _userNameController.dispose();
    _aiNameController.dispose();
    _rotationController.dispose();
    _soundwaveController.dispose();
    _zenController.dispose();
    super.dispose();
  }

  Future<void> _previewVoice() async {
    HapticFeedback.lightImpact();
    if (_isPlayingVoiceSample) {
      await NaturalVoiceService.instance.stop();
      if (mounted) setState(() => _isPlayingVoiceSample = false);
      return;
    }

    setState(() => _isPlayingVoiceSample = true);
    final persona = NaturalVoiceService.availablePersonas.firstWhere(
      (p) => p.id == _selectedVoice,
      orElse: () => NaturalVoiceService.availablePersonas.first,
    );

    await NaturalVoiceService.instance.setPersona(persona.id);
    await NaturalVoiceService.instance.speak(
      "Hi there! I am ${persona.name}. I'm here to chat, listen, and brighten your day!",
    );

    if (mounted) setState(() => _isPlayingVoiceSample = false);
  }

  Future<void> _saveAndContinue() async {
    HapticFeedback.mediumImpact();
    if (_isPlayingVoiceSample) {
      await NaturalVoiceService.instance.stop();
    }

    final prefs = await SharedPreferences.getInstance();
    final name = _userNameController.text.trim().isEmpty
        ? "Friend"
        : _userNameController.text.trim();
    final aiName = _aiNameController.text.trim().isEmpty
        ? "Chativio"
        : _aiNameController.text.trim();

    await prefs.setBool("isFirstLaunch", false);
    await prefs.setString("userName", name);
    await prefs.setString("user_name", name);
    await prefs.setString("userGender", _userGender);
    await prefs.setString("aiName", aiName);
    await prefs.setString("ai_name", aiName);
    await prefs.setString("aiGender", _aiGender);

    await NaturalVoiceService.instance.setPersona(_selectedVoice);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) => const MainWrapper(),
        transitionsBuilder: (context, a1, a2, child) =>
            FadeTransition(opacity: a1, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_isPlayingVoiceSample) {
      NaturalVoiceService.instance.stop();
      setState(() => _isPlayingVoiceSample = false);
    }
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildGlassCard({required Widget child, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x99111827) : const Color(0xB3FFFFFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _genderPillSelector({
    required String selected,
    required ValueChanged<String> onChanged,
    required bool isDark,
  }) {
    final options = ["Male", "Female", "Other"];
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x33FFFFFF) : const Color(0x0D000000),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(opt);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- SLIDE 1: INTERACTIVE NEURAL ORBITAL CORE ---
  Widget _buildScene1(bool isDark) {
    return Column(
      children: [
        const Spacer(flex: 1),
        SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Gyroscope Ring 1
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  final angle = _rotationController.value * 2 * math.pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateX(0.7)
                      ..rotateZ(angle),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                          width: 1.8,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Gyroscope Ring 2
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  final angle = -_rotationController.value * 2 * math.pi;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateY(0.8)
                      ..rotateZ(angle * 1.2),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFF818CF8,
                          ).withValues(alpha: 0.55),
                          width: 1.8,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Orbiting Moon
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  final angle = _rotationController.value * 2 * math.pi;
                  const radius = 100.0;
                  final x = math.cos(angle) * radius;
                  final y = math.sin(angle) * radius * 0.4;
                  return Transform.translate(
                    offset: Offset(x, y),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF38BDF8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF38BDF8,
                            ).withValues(alpha: 0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Center Glowing Emblem
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.asset(
                    "assets/images/logo.png",
                    fit: BoxFit.cover,
                    errorBuilder: (context, err, stack) => const Icon(
                      Icons.auto_awesome,
                      size: 60,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),

        _buildGlassCard(
          isDark: isDark,
          child: Column(
            children: [
              Text(
                "Awaken Your Companion",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Experience intelligent conversational empathy with genuine memory, intuition, and authentic warmth.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  // --- SLIDE 2: LIVE SOUNDWAVE FREQUENCY VISUALIZER ---
  Widget _buildScene2(bool isDark) {
    return Column(
      children: [
        const Spacer(flex: 1),
        // Live Soundwave Visualizer Frame
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF818CF8).withValues(alpha: 0.18),
                Colors.transparent,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing Circular Sound Rings
              AnimatedBuilder(
                animation: _soundwaveController,
                builder: (context, child) {
                  final scale = 0.85 + _soundwaveController.value * 0.25;
                  return Container(
                    width: 220 * scale,
                    height: 220 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6366F1).withValues(
                          alpha: (1.0 - _soundwaveController.value) * 0.4,
                        ),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),

              // Dynamic FFT-Style Waveform Bars
              AnimatedBuilder(
                animation: _soundwaveController,
                builder: (context, child) {
                  const barCount = 14;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(barCount, (i) {
                      final phase = (i / barCount) * math.pi;
                      final waveHeight =
                          16.0 +
                          (math
                                  .sin(
                                    phase +
                                        _soundwaveController.value *
                                            math.pi *
                                            2,
                                  )
                                  .abs()) *
                              64.0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 5,
                        height: waveHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xFF6366F1), Color(0xFF38BDF8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF38BDF8,
                              ).withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),

              // Interactive Voice Sample Pill
              Positioned(
                bottom: 12,
                child: GestureDetector(
                  onTap: _previewVoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPlayingVoiceSample
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlayingVoiceSample
                              ? "Listening..."
                              : "Tap to Hear Voice",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),

        _buildGlassCard(
          isDark: isDark,
          child: Column(
            children: [
              Text(
                "Natural Human Voice",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Speak naturally with human vocal cadence, warm inflection, and zero robotic delays across 6 distinct personas.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  // --- SLIDE 3: INTERACTIVE ZEN MINDFULNESS AURA ---
  Widget _buildScene3(bool isDark) {
    return Column(
      children: [
        const Spacer(flex: 1),
        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Zen Breathing Aura Rings
              AnimatedBuilder(
                animation: _zenController,
                builder: (context, child) {
                  final breathe = _zenController.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 170 + (breathe * 60),
                        height: 170 + (breathe * 60),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFFEC4899,
                          ).withValues(alpha: (1.0 - breathe) * 0.18),
                        ),
                      ),
                      Container(
                        width: 130 + (breathe * 40),
                        height: 130 + (breathe * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: (1.0 - breathe) * 0.25),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Meditative Crystal Heart Orb
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.35),
                      blurRadius: 40,
                    ),
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                      blurRadius: 50,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Image.asset(
                    "assets/images/onboarding_2.png",
                    fit: BoxFit.cover,
                    errorBuilder: (context, err, stack) => const Icon(
                      Icons.favorite_rounded,
                      size: 60,
                      color: Color(0xFFEC4899),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),

        _buildGlassCard(
          isDark: isDark,
          child: Column(
            children: [
              Text(
                "Mindfulness & Daily Balance",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Reflect on your emotions, track daily streaks, and receive thoughtful caring check-ins tailored to your mood.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  // --- SLIDE 4: LIVE INTERACTIVE COMPANION CREATOR ---
  Widget _buildPersonalizationPage(bool isDark) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;
    final aiName = _aiNameController.text.trim().isEmpty
        ? "Chativio"
        : _aiNameController.text.trim();
    final userName = _userNameController.text.trim().isEmpty
        ? "Friend"
        : _userNameController.text.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 12,
              bottom: 24 + (bottomInset > 0 ? bottomInset : 0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Holographic Identity Badge Card
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: 0.22),
                          const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.2),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(23),
                            child: Image.asset(
                              "assets/images/logo.png",
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  aiName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "AI Companion",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Ready for $userName • $_selectedVoice voice",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Name",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _userNameController,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.outfit(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: "What should Chativio call you?",
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        "Your Gender",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _genderPillSelector(
                        selected: _userGender,
                        onChanged: (val) => setState(() => _userGender = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      Text(
                        "AI Companion Name",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _aiNameController,
                        textInputAction: TextInputAction.done,
                        style: GoogleFonts.outfit(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: "Give your AI a custom name",
                          prefixIcon: Icon(Icons.smart_toy_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        "AI Gender",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _genderPillSelector(
                        selected: _aiGender,
                        onChanged: (val) => setState(() => _aiGender = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 14),

                      Text(
                        "Companion Voice Persona",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: NaturalVoiceService.availablePersonas.map((
                          p,
                        ) {
                          final isSelected = _selectedVoice == p.id;
                          return ChoiceChip(
                            label: Text("${p.name} (${p.gender})"),
                            selected: isSelected,
                            selectedColor: primary,
                            backgroundColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFE2E8F0),
                            labelStyle: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            onSelected: (val) {
                              if (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedVoice = p.id);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Launch button with Apple gradient style
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Enter Chativio",
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
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

  Widget _buildBottomBar(bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots indicator
          Row(
            children: List.generate(4, (index) {
              final isSelected = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSelected ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary
                      : (isDark ? Colors.white24 : Colors.black12),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Skip buttons
          Row(
            children: [
              TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _pageController.jumpToPage(3);
                },
                child: Text(
                  "Skip",
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _nextPage,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF080B14)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient cosmic illumination orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                    : const Color(0xFF6366F1).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF06B6D4).withValues(alpha: 0.12)
                    : const Color(0xFF06B6D4).withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_isPlayingVoiceSample) {
                  NaturalVoiceService.instance.stop();
                  _isPlayingVoiceSample = false;
                }
                setState(() => _currentPage = index);
              },
              children: [
                _buildScene1(isDark),
                _buildScene2(isDark),
                _buildScene3(isDark),
                _buildPersonalizationPage(isDark),
              ],
            ),
          ),
        ],
      ),
      bottomSheet: _currentPage < 3 ? _buildBottomBar(isDark) : null,
    );
  }
}
