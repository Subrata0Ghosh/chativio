import 'dart:io';
import 'package:flutter/material.dart';

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
    final hasImage = imagePath != null;

    return Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                    ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isUser ? 24 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 24),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUser ? Colors.purple : Colors.pink).withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(imagePath!),
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: MediaQuery.of(context).size.width * 0.6,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (text != null)
                  Text(
                    text!,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
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
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (isUser && status != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        status == "seen"
                            ? Icons.done_all
                            : (status == "delivered"
                                  ? Icons.done_all
                                  : Icons.done),
                        size: 12,
                        color: status == "seen"
                            ? Colors.blueAccent
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
