import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tzInitialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Ensure timezone database is ready as early as possible
    await _ensureTz();

    // On Android 13+, POST_NOTIFICATIONS permission is runtime; plugin handles it via requestPermission
    try {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}

    _initialized = true;
  }

  Future<void> _ensureTz() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    // Rely on device default; without native timezone package we'll use local
    tz.setLocalLocation(tz.local);
    _tzInitialized = true;
  }

  Future<bool> _ensurePermissionsForScheduling() async {
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final enabled = await androidImpl.areNotificationsEnabled();
        if (enabled == false) {
          await androidImpl.requestNotificationsPermission();
        }
        await androidImpl.requestExactAlarmsPermission();
      }
    } catch (_) {}
    return true;
  }

  tz.TZDateTime _toScheduledTime(DateTime when) {
    // If tz.local is really UTC (common when no native timezone name is set),
    // interpret the provided local DateTime as local wall-clock and convert to the
    // correct absolute instant by using UTC with when.toUtc().
    if (tz.local.name.toUpperCase() == 'UTC') {
      final utcInstant = when.toUtc();
      return tz.TZDateTime.from(utcInstant, tz.UTC);
    }
    return tz.TZDateTime.from(when, tz.local);
  }

  Future<void> show(String title, String body) async {
    if (!_initialized) return;
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for AI chat messages',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _plugin.show(DateTime.now().millisecondsSinceEpoch % 1000000, title, body, details);
  }

  Future<void> triggerTestNow() async {
    if (!_initialized) return;
    try {
      await _ensurePermissionsForScheduling();
      await show('Test Notification', 'This is a test notification.');
    } catch (_) {}
  }

  Future<void> triggerTestInSeconds(int seconds) async {
    if (!_initialized) return;
    await _ensurePermissionsForScheduling();
    await _ensureTz();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminders_high',
      'Event Reminders',
      channelDescription: 'Reminders for your saved events',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    final details = const NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(Duration(seconds: seconds));
    try {
      await _plugin.zonedSchedule(
        DateTime.now().microsecondsSinceEpoch % 1000000000,
        'Test Notification (in $seconds s)',
        'This was scheduled $seconds seconds ago.',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('triggerTestInSeconds error: $e');
      }
    }
  }

  Future<void> scheduleDailyNudge(String title, String body, {int hour = 19, int minute = 0, int id = 9001}) async {
    if (!_initialized) return;
    await _ensurePermissionsForScheduling();
    await _ensureTz();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_nudges',
      'Daily Nudges',
      channelDescription: 'Daily friendly nudges from AI',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final details = const NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('scheduleDailyNudge error: $e');
      }
    }
  }

  Future<void> cancelDailyNudge({int id = 9001}) async {
    await _plugin.cancel(id);
  }

  Future<List<PendingNotificationRequest>> listPending() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const <PendingNotificationRequest>[];
    }
  }

  Future<int> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_initialized) return -1;
    await _ensurePermissionsForScheduling();
    await _ensureTz();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_reminders_high',
      'Event Reminders',
      channelDescription: 'Reminders for your saved events',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    final details = const NotificationDetails(android: androidDetails);
    var scheduled = _toScheduledTime(when);
    final nowTz = tz.TZDateTime.now(scheduled.location);
    if (!scheduled.isAfter(nowTz)) {
      // If computed time is in the past, nudge it slightly to ensure delivery.
      scheduled = nowTz.add(const Duration(seconds: 2));
    }
    final localNow = DateTime.now();
    final localScheduled = DateTime.fromMillisecondsSinceEpoch(scheduled.millisecondsSinceEpoch).toLocal();
    if (kDebugMode) {
      debugPrint('Scheduling event notification id=$id at $scheduled tz=\'${scheduled.location.name}\' (local: $localScheduled, now: $localNow)');
    }
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('scheduleAt error: $e');
      }
      return -1;
    }
  }

  Future<void> cancelById(int id) async {
    await _plugin.cancel(id);
  }
}

