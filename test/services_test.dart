import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/subscription_service.dart';
import 'package:myapp/services/persona_service.dart';
import 'package:myapp/services/nlp_service.dart';
import 'package:myapp/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SubscriptionService Tests', () {
    test('Defaults to free tier with remaining messages', () async {
      final sub = SubscriptionService.instance;
      await sub.init();

      expect(sub.isPro, isFalse);
      expect(sub.planTier, 'free');
      expect(sub.messagesSentToday, 0);
      expect(sub.canSendMessage, isTrue);
      expect(sub.remainingFreeMessages, SubscriptionService.dailyFreeLimit);
    });

    test('Consumes free messages and limits when quota exhausted', () async {
      final sub = SubscriptionService.instance;
      await sub.init();

      for (int i = 0; i < SubscriptionService.dailyFreeLimit; i++) {
        expect(sub.canSendMessage, isTrue);
        await sub.recordMessageSent();
      }

      expect(sub.messagesSentToday, SubscriptionService.dailyFreeLimit);
      expect(sub.remainingFreeMessages, 0);
      expect(sub.canSendMessage, isFalse);
    });

    test('Redeems VIPPRO promo code for Lifetime Pro access', () async {
      final sub = SubscriptionService.instance;
      await sub.init();

      final redeemed = await sub.redeemPromoCode('VIPPRO');
      expect(redeemed, isTrue);
      expect(sub.isPro, isTrue);
      expect(sub.planTier, 'lifetime');
      expect(sub.canSendMessage, isTrue);
    });

    test('Rejects invalid promo codes', () async {
      final sub = SubscriptionService.instance;
      await sub.init();

      final redeemed = await sub.redeemPromoCode('INVALID_CODE_123');
      expect(redeemed, isFalse);
    });
  });

  group('PersonaService Tests', () {
    test('Provides 5 distinct companion personas', () {
      expect(PersonaService.availablePersonas.length, 5);
      final ids = PersonaService.availablePersonas.map((p) => p.id).toList();
      expect(
        ids,
        containsAll(['friend', 'wellness', 'mentor', 'storyteller', 'career']),
      );
    });

    test('Generates customized system prompt with user data', () {
      final service = PersonaService.instance;
      final prompt = service.buildSystemPrompt(
        userName: 'Alice',
        userGender: 'Female',
        aiName: 'Buddy',
        currentMood: 'happy',
        memory: 'Loves hiking and painting',
        eventsSummary: 'Doctor appointment tomorrow',
      );

      expect(prompt, contains('Alice'));
      expect(prompt, contains('Buddy'));
      expect(prompt, contains('happy'));
      expect(prompt, contains('Loves hiking and painting'));
      expect(prompt, contains('Doctor appointment tomorrow'));
    });
  });

  group('NlpService Scheduling Tests', () {
    test('Parses standard schedule command', () {
      final nlp = NlpService();
      final res = nlp.parseScheduleCommand(
        'schedule dentist appointment tomorrow at 10:30am',
      );

      expect(res, isNotNull);
      expect(res!['event'], contains('dentist appointment'));
      expect(res['dateTime'], isA<DateTime>());
      final dt = res['dateTime'] as DateTime;
      expect(dt.hour, 10);
      expect(dt.minute, 30);
    });

    test('Parses natural "remind me to" command', () {
      final nlp = NlpService();
      final res = nlp.parseScheduleCommand(
        'remind me to call Mom tomorrow at 5pm',
      );

      expect(res, isNotNull);
      expect(res!['event'], contains('call Mom'));
      final dt = res['dateTime'] as DateTime;
      expect(dt.hour, 17);
    });

    test('Returns null for non-scheduling sentences', () {
      final nlp = NlpService();
      final res = nlp.parseScheduleCommand('how is the weather outside today?');
      expect(res, isNull);
    });
  });

  group('AiService Mood Detection Tests', () {
    test('Heuristically classifies cheerful message as happy', () async {
      final mood = await AiService.instance.analyzeMood(
        "I'm so happy and excited about my new job!",
      );
      expect(mood, anyOf(equals('happy'), equals('excited')));
    });

    test('Heuristically classifies stressed message as stressed', () async {
      final mood = await AiService.instance.analyzeMood(
        "I am so anxious and stressed with exams",
      );
      expect(mood, 'stressed');
    });

    test('Heuristically classifies tired message as tired', () async {
      final mood = await AiService.instance.analyzeMood(
        "I'm completely exhausted and need sleep",
      );
      expect(mood, 'tired');
    });
  });
}
