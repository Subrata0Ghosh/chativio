import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/chat_screen.dart';
import 'package:myapp/screens/events_screen.dart';
import 'package:myapp/screens/stories_screen.dart';
import 'package:myapp/screens/profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ChatScreen(),
    EventsScreen(),
    StoriesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF080B14)
          : const Color(0xFFF8FAFC),
      extendBody: false,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: isKeyboardOpen
          ? const SizedBox.shrink()
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      height: 66,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xE00B101E)
                            : const Color(0xEEFFFFFF),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.45)
                                : Colors.black.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            0,
                            Icons.chat_bubble_outline_rounded,
                            Icons.chat_bubble_rounded,
                            "Chat",
                            isDark,
                          ),
                          _buildNavItem(
                            1,
                            Icons.calendar_today_outlined,
                            Icons.calendar_month_rounded,
                            "Events",
                            isDark,
                          ),
                          _buildNavItem(
                            2,
                            Icons.auto_stories_outlined,
                            Icons.auto_stories_rounded,
                            "Stories",
                            isDark,
                          ),
                          _buildNavItem(
                            3,
                            Icons.person_outline_rounded,
                            Icons.person_rounded,
                            "Profile",
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    bool isDark,
  ) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 16 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white60 : Colors.black54),
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
