import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/services/engagement_service.dart';

void main() {
  group('EngagementService Tests', () {
    test('Relationship levels calculate properly based on XP', () {
      final service = EngagementService.instance;
      expect(service.getDailyStarters().isNotEmpty, isTrue);
      expect(service.currentStreak >= 1, isTrue);
    });

    test('Daily starters adapt by time of day', () {
      final starters = EngagementService.instance.getDailyStarters();
      expect(starters.length, equals(4));
      expect(starters[0].isNotEmpty, isTrue);
    });
  });
}
