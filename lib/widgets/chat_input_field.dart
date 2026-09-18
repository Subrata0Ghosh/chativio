import 'package:flutter/material.dart';

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

  Widget _buildResponsiveButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    bool? isListening,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final radius = screenWidth < 400 ? 20.0 : 25.0; // Smaller on narrow screens
    return CircleAvatar(
      radius: radius,
      backgroundColor: isListening == true ? Colors.red : Colors.blueAccent,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: radius * 0.8),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction:
                    TextInputAction.send, // shows send icon on keyboard
                onSubmitted: (_) =>
                    onSendPressed(), // submit when pressing Enter/Send
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildResponsiveButton(
              context,
              icon: Icons.image,
              onPressed: onImagePressed,
            ),
            const SizedBox(width: 8),
            _buildResponsiveButton(
              context,
              icon: isListening ? Icons.mic_off : Icons.mic,
              onPressed: onVoicePressed,
              isListening: isListening,
            ),
            const SizedBox(width: 8),
            _buildResponsiveButton(
              context,
              icon: Icons.send,
              onPressed: onSendPressed,
            ),
          ],
        ),
      ),
    );
  }
}
