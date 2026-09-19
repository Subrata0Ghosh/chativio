import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myapp/services/notification_service.dart';

class EngagementService {
  EngagementService._();
  static final EngagementService instance = EngagementService._();

  Box? _box;
  bool _initialized = false;

  int _currentStreak = 1;
  int _longestStreak = 1;
  int _totalXp = 25;
  String _lastActiveDay = '';

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalXp => _totalXp;

  String get relationshipLevel {
    if (_totalXp < 60) return "New Acquaintance";
    if (_totalXp < 160) return "Trusted Friend";
    if (_totalXp < 360) return "Close Confidant";
    if (_totalXp < 750) return "Kindred Soul";
    return "Inseparable Bond";
  }

  int get levelIndex {
    if (_totalXp < 60) return 1;
    if (_totalXp < 160) return 2;
    if (_totalXp < 360) return 3;
    if (_totalXp < 750) return 4;
    return 5;
  }

  double get levelProgress {
    if (_totalXp < 60) return _totalXp / 60.0;
    if (_totalXp < 160) return (_totalXp - 60) / 100.0;
    if (_totalXp < 360) return (_totalXp - 160) / 200.0;
    if (_totalXp < 750) return (_totalXp - 360) / 390.0;
    return 1.0;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (!Hive.isBoxOpen('engagement')) {
        _box = await Hive.openBox('engagement');
      } else {
        _box = Hive.box('engagement');
      }

      _currentStreak = _box?.get('currentStreak', defaultValue: 1) as int;
      _longestStreak = _box?.get('longestStreak', defaultValue: 1) as int;
      _totalXp = _box?.get('totalXp', defaultValue: 25) as int;
      _lastActiveDay = _box?.get('lastActiveDay', defaultValue: '') as String;

      _evaluateStreak();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint("EngagementService init error: $e");
    }
  }

  /// Evaluates whether the streak continues, increments, or resets based on calendar days
  void _evaluateStreak() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastActiveDay.isEmpty) {
      _lastActiveDay = today;
      _currentStreak = 1;
      _box?.put('lastActiveDay', today);
      _box?.put('currentStreak', 1);
      return;
    }

    if (_lastActiveDay == today) {
      // Already active today; streak maintained
      return;
    }

    try {
      final lastDate = DateTime.parse(_lastActiveDay);
      final currentDate = DateTime.parse(today);
      final differenceInDays = currentDate.difference(lastDate).inDays;

      if (differenceInDays == 1) {
        // Consecutive day activity!
        _currentStreak += 1;
        if (_currentStreak > _longestStreak) {
          _longestStreak = _currentStreak;
          _box?.put('longestStreak', _longestStreak);
        }
      } else if (differenceInDays > 1) {
        // Missed a day
        _currentStreak = 1;
      }
      _lastActiveDay = today;
      _box?.put('lastActiveDay', today);
      _box?.put('currentStreak', _currentStreak);
    } catch (_) {}
  }

  /// Award XP for user interaction and trigger streak check
  Future<int> recordUserMessage() async {
    await init();
    _evaluateStreak();
    _totalXp += 5;
    await _box?.put('totalXp', _totalXp);
    return _totalXp;
  }

  /// Schedule daily morning and evening smart check-in notifications
  Future<void> scheduleDailyEngagementNotifications({
    required String userName,
    required String aiName,
  }) async {
    await NotificationService.instance.init();

    final companion = aiName.trim().isEmpty ? "Chativio" : aiName.trim();
    final user = userName.trim().isEmpty ? "friend" : userName.trim();

    // 1. Morning Inspiration (9:00 AM)
    await NotificationService.instance.scheduleDailyNudge(
      "☀️ Good Morning, $user!",
      "$companion is here. Ready to make today memorable together?",
      hour: 9,
      minute: 0,
      id: 9101,
    );

    // 2. Midday Recharge (2:15 PM)
    await NotificationService.instance.scheduleDailyNudge(
      "☕ Quick Afternoon Breather",
      "How is your energy right now? Let's take a 2-minute reset.",
      hour: 14,
      minute: 15,
      id: 9102,
    );

    // 3. Evening Reflection & Wind-down (8:30 PM)
    await NotificationService.instance.scheduleDailyNudge(
      "🌙 Evening Check-in with $companion",
      "The day is wrapping up. What was the highlight of your day?",
      hour: 20,
      minute: 30,
      id: 9103,
    );
  }

  /// Get contextual conversation starters based on the time of day
  List<String> getDailyStarters() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return [
        "☀️ What's on your mind today?",
        "☕ Quick 3-minute goal setting",
        "💡 Give me a spark of inspiration",
        "🧘 1-min morning calm breath",
      ];
    } else if (hour < 18) {
      return [
        "☕ How is your energy right now?",
        "💭 Need advice or a second opinion?",
        "✨ Tell me a fascinating fact",
        "😄 Cheer me up with a laugh",
      ];
    } else {
      return [
        "🌙 Tell me about the best part of today",
        "📖 Create a short relaxing bedtime story",
        "💭 Let's reflect on today's thoughts",
        "✨ Share a thought for tomorrow",
      ];
    }
  }
}
