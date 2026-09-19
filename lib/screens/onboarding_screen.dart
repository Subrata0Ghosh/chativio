import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userNameController = TextEditingController(
    text: "Friend",
  );
  String _userGender = "Not set";
  final TextEditingController _aiNameController = TextEditingController(
    text: "Chativio",
  );
  String _aiGender = "Not set";

  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _userNameController.dispose();
    _aiNameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final name = _userNameController.text.trim().isEmpty
        ? "Friend"
        : _userNameController.text.trim();
    await prefs.setBool("isFirstLaunch", false);
    await prefs.setString("userName", name);
    await prefs.setString("userGender", _userGender);
    await prefs.setString(
      "aiName",
      _aiNameController.text.trim().isEmpty
          ? "Chativio"
          : _aiNameController.text.trim(),
    );
    await prefs.setString("aiGender", _aiGender);

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
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(24),
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
                    ? Colors.black.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
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
        color: isDark ? const Color(0x40FFFFFF) : const Color(0x0D000000),
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

  Widget _buildStoryPage({
    required String assetPath,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const Spacer(flex: 1),
            // 3D Visual Asset Card
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, err, stack) => Container(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 70,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),

            // Glass text card
            _buildGlassCard(
              isDark: isDark,
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizationPage(bool isDark) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 16,
              bottom: 24 + (bottomInset > 0 ? bottomInset : 0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "Personalize Chativio",
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    "Tailor your AI friend for the best experience",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _buildGlassCard(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Name",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _userNameController,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.outfit(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "What should Chativio call you?",
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        "Your Gender",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _genderPillSelector(
                        selected: _userGender,
                        onChanged: (val) => setState(() => _userGender = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      Text(
                        "AI Companion Name",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _aiNameController,
                        textInputAction: TextInputAction.done,
                        style: GoogleFonts.outfit(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Give your AI a custom name",
                          prefixIcon: const Icon(Icons.smart_toy_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        "AI Personality Voice",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _genderPillSelector(
                        selected: _aiGender,
                        onChanged: (val) => setState(() => _aiGender = val),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

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
                width: isSelected ? 22 : 7,
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
          // Ambient luxury background orbs
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

          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            children: [
              _buildStoryPage(
                assetPath: "assets/images/logo.png",
                title: "Welcome to Chativio",
                subtitle:
                    "Experience next-generation companionship powered by empathetic intelligence and sleek craft.",
                isDark: isDark,
              ),
              _buildStoryPage(
                assetPath: "assets/images/onboarding_1.png",
                title: "Fluid Intelligent Conversations",
                subtitle:
                    "Engage in lightning-fast, perceptive discussions that adapt to your thoughts and daily life.",
                isDark: isDark,
              ),
              _buildStoryPage(
                assetPath: "assets/images/onboarding_2.png",
                title: "Mindfulness & Emotional Balance",
                subtitle:
                    "Reflect on your mood, discover calming balance, and cultivate daily mental clarity.",
                isDark: isDark,
              ),
              _buildPersonalizationPage(isDark),
            ],
          ),
        ],
      ),
      bottomSheet: _currentPage < 3 ? _buildBottomBar(isDark) : null,
    );
  }
}
