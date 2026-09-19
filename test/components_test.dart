import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart'; // import google_fonts
import 'package:myapp/widgets/message_bubble.dart';
import 'package:myapp/widgets/chat_input_field.dart';
import 'package:myapp/widgets/typing_indicator.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Component Tests', () {
    testWidgets('MessageBubble renders correctly for User', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MessageBubble(
                  isUser: true,
                  text: "Hello World",
                  time: "10:00 AM",
                  status: "seen",
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text("Hello World"), findsOneWidget);
      expect(find.text("10:00 AM"), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget); // Seen icon
    });

    testWidgets('MessageBubble renders correctly for Bot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                MessageBubble(isUser: false, text: "I am AI", time: "10:01 AM"),
              ],
            ),
          ),
        ),
      );

      expect(find.text("I am AI"), findsOneWidget);
      expect(find.text("10:01 AM"), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('TypingDots animates', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TypingDots())),
      );

      expect(find.byType(TypingDots), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500)); // Advance animation
    });

    testWidgets('ChatInputField has text field and buttons', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInputField(
              controller: controller,
              focusNode: focusNode,
              onSendPressed: () {},
              onImagePressed: () {},
              onVoicePressed: () {},
              isListening: false,
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });
  });
}
