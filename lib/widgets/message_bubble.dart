import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessageBubble extends StatelessWidget {
  final String? text;
  final String? imagePath;
  final bool isUser;
  final String time;
  final String? status; // sent, delivered, seen
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    this.text,
    this.imagePath,
    required this.isUser,
    required this.time,
    this.status,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final hasImage = imagePath != null;

    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUser
                  ? null
                  : (isDark
                        ? const Color(0xFF141B2D)
                        : const Color(0xFFE9EEF5)),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              border: isUser
                  ? null
                  : Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                      width: 0.8,
                    ),
              boxShadow: [
                BoxShadow(
                  color: isUser
                      ? primary.withValues(alpha: 0.25)
                      : (isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.04)),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(imagePath!),
                      width: MediaQuery.of(context).size.width * 0.62,
                      height: MediaQuery.of(context).size.width * 0.62,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (text != null) const SizedBox(height: 8),
                ],
                if (text != null)
                  Text(
                    text!,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      color: isUser
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFF0F172A)),
                    ),
                    softWrap: true,
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: isUser
                            ? Colors.white70
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                    if (isUser && status != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        status == "seen"
                            ? Icons.done_all_rounded
                            : (status == "delivered"
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded),
                        size: 13,
                        color: status == "seen"
                            ? const Color(0xFF38BDF8)
                            : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
