import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSendPressed;
  final VoidCallback onImagePressed;
  final VoidCallback onVoicePressed;
  final bool isListening;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSendPressed,
    required this.onImagePressed,
    required this.onVoicePressed,
    required this.isListening,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111728) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Photo attachment button
              IconButton(
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 22,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onImagePressed();
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),

              // Mic / Voice Button
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    key: ValueKey<bool>(isListening),
                    color: isListening
                        ? Colors.redAccent
                        : (isDark ? Colors.white70 : Colors.black54),
                    size: 22,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onVoicePressed();
                },
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 4),

              // Text input field
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      HapticFeedback.lightImpact();
                      onSendPressed();
                    },
                    maxLines: 4,
                    minLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: isListening
                          ? "Listening..."
                          : "Message Chativio...",
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 15,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // Apple iMessage style arrow-up send button
              Padding(
                padding: const EdgeInsets.only(bottom: 2, right: 2),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSendPressed();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primary, const Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
