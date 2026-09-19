import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/natural_voice_service.dart';

void main() {
  group('NaturalVoiceService Tests', () {
    final service = NaturalVoiceService.instance;

    test('sanitizeForSpeech removes markdown formatting', () {
      const raw = '**Hello!** Here is `inline code` and *italic text*.';
      final clean = service.sanitizeForSpeech(raw);
      expect(clean, equals('Hello! Here is inline code and italic text.'));
    });

    test('sanitizeForSpeech handles code blocks cleanly', () {
      const raw =
          'Check this code:\n```dart\nvoid main() {\n  print("Hi");\n}\n```\nLet me know what you think!';
      final clean = service.sanitizeForSpeech(raw);
      expect(clean.contains('void main'), isFalse);
      expect(clean.contains('Check this code:'), isTrue);
      expect(clean.contains('Let me know what you think!'), isTrue);
    });

    test('sanitizeForSpeech strips emojis and urls', () {
      const raw =
          'Visit https://example.com/ai today! 🤖🚀 Beautiful sunset 🌅✨';
      final clean = service.sanitizeForSpeech(raw);
      expect(clean.contains('🤖'), isFalse);
      expect(clean.contains('🚀'), isFalse);
      expect(clean.contains('🌅'), isFalse);
      expect(clean.contains('https://'), isFalse);
      expect(clean.contains('Beautiful sunset'), isTrue);
    });

    test('Available personas has default Ava and other voices', () {
      expect(
        NaturalVoiceService.availablePersonas.length,
        greaterThanOrEqualTo(5),
      );
      final ava = NaturalVoiceService.availablePersonas.firstWhere(
        (p) => p.id == 'ava',
      );
      expect(ava.name, equals('Ava'));
      expect(ava.cloudLocale, equals('en-US'));

      final oliver = NaturalVoiceService.availablePersonas.firstWhere(
        (p) => p.id == 'oliver',
      );
      expect(oliver.name, equals('Oliver'));
      expect(oliver.cloudLocale, equals('en-GB'));
    });
  });
}
