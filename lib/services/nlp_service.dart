import 'package:hive_flutter/hive_flutter.dart';

class NlpService {
  static final NlpService _instance = NlpService._internal();
  factory NlpService() => _instance;
  NlpService._internal();

  Box? _memoryBox;

  Future<void> init() async {
    if (!Hive.isBoxOpen('memory')) {
      try {
        await Hive.initFlutter();
        _memoryBox = await Hive.openBox('memory');
      } catch (_) {}
    } else {
      _memoryBox = Hive.box('memory');
    }
  }

  /// Parse a message for scheduling or reminder commands like:
  /// - "schedule dentist next Tuesday at 10am"
  /// - "remind me to call mom tomorrow at 5pm"
  /// - "remember to workout tonight at 8pm"
  Map<String, dynamic>? parseScheduleCommand(String rawMessage) {
    final message = rawMessage.trim();

    // Check for reminder/schedule triggers
    final schedulePatterns = [
      RegExp(
        r'^(?:please\s+)?(?:schedule|remind\s+me\s+to|remember\s+to|add\s+(?:an?\s+)?event|set\s+a\s+reminder\s+for)\s+(.+)$',
        caseSensitive: false,
      ),
    ];

    String? content;
    for (final pattern in schedulePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        content = match.group(1)?.trim();
        break;
      }
    }

    if (content == null) return null;

    // Separate event title and time specification
    // e.g. "call mom tomorrow at 5pm" or "team meeting on Friday at 10am"
    final timeSplits = [
      RegExp(
        r'\s+(?:on|at|for|by)\s+(tomorrow|today|tonight|next\s+\w+|\w+day|\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?)(?:\s+at\s+(.+))?$',
        caseSensitive: false,
      ),
      RegExp(
        r'\s+(tomorrow|today|tonight|next\s+\w+|\w+day)(?:\s+at\s+(.+))?$',
        caseSensitive: false,
      ),
    ];

    String eventTitle = content;
    String dateStr = 'today';
    String? timeStr;

    for (final splitPattern in timeSplits) {
      final splitMatch = splitPattern.firstMatch(content);
      if (splitMatch != null) {
        eventTitle = content.substring(0, splitMatch.start).trim();
        dateStr = splitMatch.group(1)?.trim() ?? 'today';
        timeStr = splitMatch.group(2)?.trim();
        break;
      }
    }

    if (eventTitle.isEmpty) {
      eventTitle = content;
    }

    // Default time to 1 hour from now or 9am tomorrow if no time specified
    final dateTime = _parseDateTime(dateStr, timeStr);
    if (dateTime == null) return null;

    return {'event': eventTitle, 'dateTime': dateTime};
  }

  DateTime? _parseDateTime(String dateStr, String? timeStr) {
    try {
      final now = DateTime.now();
      DateTime date = now;
      final dLower = dateStr.toLowerCase();

      if (dLower.contains('tomorrow')) {
        date = now.add(const Duration(days: 1));
      } else if (dLower.contains('tonight')) {
        date = DateTime(now.year, now.month, now.day, 20, 0);
      } else if (dLower.contains('today')) {
        date = now;
      } else if (dLower.contains('next')) {
        final day = dLower.split(' ').last;
        final days = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        final dayIndex = days.indexOf(day);
        if (dayIndex != -1) {
          final todayIndex = now.weekday - 1; // Monday = 0
          int daysToAdd = (dayIndex - todayIndex + 7) % 7;
          if (daysToAdd == 0) daysToAdd = 7; // Next week
          date = now.add(Duration(days: daysToAdd));
        }
      } else {
        final days = [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ];
        final dayIndex = days.indexOf(dLower);
        if (dayIndex != -1) {
          final todayIndex = now.weekday - 1;
          int daysToAdd = (dayIndex - todayIndex + 7) % 7;
          if (daysToAdd == 0) daysToAdd = 7;
          date = now.add(Duration(days: daysToAdd));
        } else {
          date = DateTime.tryParse(dateStr) ?? now;
        }
      }

      int hour = 9;
      int minute = 0;

      if (timeStr != null && timeStr.isNotEmpty) {
        final cleanedTime = timeStr.trim().toLowerCase();
        final isPm = cleanedTime.contains('pm');
        final isAm = cleanedTime.contains('am');
        final digits = cleanedTime.replaceAll(RegExp(r'[^0-9:]'), '');

        if (digits.contains(':')) {
          final parts = digits.split(':');
          hour = int.tryParse(parts[0]) ?? 9;
          minute = int.tryParse(parts[1]) ?? 0;
        } else {
          hour = int.tryParse(digits) ?? 9;
          minute = 0;
        }

        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
      } else if (dLower.contains('tonight')) {
        hour = 20;
      } else {
        // Default to next hour if scheduled for today
        if (date.day == now.day && date.month == now.month) {
          hour = (now.hour + 1) % 24;
          minute = 0;
        }
      }

      final parsed = DateTime(date.year, date.month, date.day, hour, minute);
      return parsed.isAfter(now) ? parsed : parsed.add(const Duration(days: 1));
    } catch (_) {
      return null;
    }
  }

  /// Store user memory fact
  Future<void> storeMemory(String key, dynamic value) async {
    if (_memoryBox != null) {
      await _memoryBox!.put(key, value);
    }
  }

  /// Retrieve user memory fact
  dynamic getMemory(String key) {
    return _memoryBox?.get(key);
  }

  /// Check if memory consent is given
  bool get memoryConsent =>
      _memoryBox?.get('consent', defaultValue: true) ?? true;

  /// Set memory consent
  Future<void> setMemoryConsent(bool consent) async {
    await storeMemory('consent', consent);
  }
}
