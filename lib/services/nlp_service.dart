import 'package:intl/intl.dart';
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

  /// Parse a message for scheduling commands like "schedule dentist next Tuesday at 10am"
  Map<String, dynamic>? parseScheduleCommand(String message) {
    final RegExp regExp = RegExp(
      r'schedule\s+(.+?)\s+(?:on\s+|at\s+)?(.+?)(?:\s+at\s+(.+))?$',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(message.toLowerCase());
    if (match == null) return null;

    final event = match.group(1)?.trim();
    final dateStr = match.group(2)?.trim();
    final timeStr = match.group(3)?.trim();

    if (event == null || dateStr == null) return null;

    DateTime? dateTime = _parseDateTime(dateStr, timeStr);
    if (dateTime == null) return null;

    return {
      'event': event,
      'dateTime': dateTime,
    };
  }

  DateTime? _parseDateTime(String dateStr, String? timeStr) {
    // Simple parsing: assume "next Tuesday" or "tomorrow 10am"
    // Use intl for better parsing
    try {
      final now = DateTime.now();
      DateTime date;

      if (dateStr.contains('next')) {
        final day = dateStr.split(' ').last;
        final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        final dayIndex = days.indexOf(day);
        if (dayIndex != -1) {
          final todayIndex = now.weekday - 1; // Monday = 0
          int daysToAdd = (dayIndex - todayIndex + 7) % 7;
          if (daysToAdd == 0) daysToAdd = 7; // Next week
          date = now.add(Duration(days: daysToAdd));
        } else {
          return null;
        }
      } else if (dateStr.contains('tomorrow')) {
        date = now.add(const Duration(days: 1));
      } else {
        // Try parsing as date
        date = DateFormat('yyyy-MM-dd').parse(dateStr) ?? DateTime.tryParse(dateStr) ?? now;
      }

      if (timeStr != null) {
        final time = DateFormat('HH:mm').parse(timeStr) ?? DateFormat('h:mm a').parse(timeStr);
        date = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      }

      return date.isAfter(now) ? date : null;
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
  bool get memoryConsent => _memoryBox?.get('consent', defaultValue: false) ?? false;

  /// Set memory consent
  Future<void> setMemoryConsent(bool consent) async {
    await storeMemory('consent', consent);
  }
}
