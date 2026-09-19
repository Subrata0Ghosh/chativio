import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:myapp/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import './settings_screen.dart';
import 'package:myapp/services/nlp_service.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/subscription_service.dart';
import 'package:myapp/services/persona_service.dart';
import 'package:myapp/services/natural_voice_service.dart';
import 'package:myapp/screens/voice_call_screen.dart';
import 'package:myapp/screens/premium_screen.dart';
import 'package:myapp/widgets/typing_indicator.dart';
import 'package:myapp/widgets/message_bubble.dart';
import 'package:myapp/widgets/chat_input_field.dart';
import 'package:myapp/services/engagement_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static bool isOpen = false;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  String _memory = "";
  String _currentMood = "neutral";
  bool _allowAutoFollowUps = true; // after a normal reply
  bool _allowIdleNudges = true; // proactive after inactivity
  int _idleMinutes = 7; // minutes of inactivity before nudge
  int _nudgeProbability = 25; // % chance to send after idle
  Timer? _idleTimer;
  DateTime? _lastActivity;

  // user/ai details
  String userName = '';
  String userGender = '';
  String aiName = '';
  String aiGender = '';
  bool isFirstLaunch = true;
  Box? _chatBox;
  Box? _cacheBox; // for offline responses
  bool _notificationsEnabled = true;
  bool _morningNudge = false;
  bool _eveningNudge = true;
  int _morningHour = 9;
  int _morningMinute = 0;
  int _eveningHour = 19;
  int _eveningMinute = 0;
  int _contentMixFunny = 40; // percent 0..100

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  final NaturalVoiceService _voiceService = NaturalVoiceService.instance;
  final EngagementService _engagement = EngagementService.instance;
  bool _voiceResponses = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    ChatScreen.isOpen = true;
    NlpService().init();
    _engagement.init().then((_) {
      if (mounted) setState(() {});
    });
    _loadOnboardingScreenData().then((_) {
      _loadChatHistory();
      _engagement.scheduleDailyEngagementNotifications(
        userName: userName,
        aiName: aiName,
      );
    });
    _markActivity();
    _resetIdleTimer();
    // load settings after hive ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureHive();
      _loadSettingsFromHive();
    });
  }

  @override
  void dispose() {
    ChatScreen.isOpen = false;
    _voiceService.stop();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOnboardingScreenData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isFirstLaunch = prefs.getBool("isFirstLaunch") ?? true;
      userName = prefs.getString("userName") ?? 'User';
      userGender = prefs.getString("userGender") ?? '';
      aiName = prefs.getString("aiName") ?? 'Chativio';
      aiGender = prefs.getString("aiGender") ?? '';
    });
    await _ensureHive();
    _loadSettingsFromHive();
  }

  Future<void> _saveChatHistory() async {
    await _ensureHive();
    await _chatBox!.put("chatHistory_$userName", _messages);
    await _chatBox!.put("memory_$userName", _memory);
  }

  Future<void> _loadChatHistory() async {
    await _ensureHive();
    final dynamic storedList = _chatBox!.get("chatHistory_$userName");
    final dynamic storedMemory = _chatBox!.get("memory_$userName");

    if (storedList is List) {
      setState(() {
        _messages.clear();
        for (var msg in storedList) {
          _messages.add(Map<String, String>.from(Map.castFrom(msg as Map)));
        }
      });
      _scrollToBottom();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final encodedHistory = prefs.getString("chatHistory_$userName");
      final spMemory = prefs.getString("memory_$userName");
      if (encodedHistory != null) {
        final decoded = jsonDecode(encodedHistory);
        setState(() {
          _messages.clear();
          for (var msg in decoded) {
            _messages.add(Map<String, String>.from(msg));
          }
        });
        await _saveChatHistory();
        _scrollToBottom();
      }
      if (spMemory != null && spMemory.isNotEmpty) {
        setState(() {
          _memory = spMemory;
        });
        await _saveChatHistory();
      }
    }

    if (storedMemory is String) {
      setState(() {
        _memory = storedMemory;
      });
    }

    // After loading history, if this is the first time after onboarding and no messages yet,
    // send a short welcome message once.
    await _maybeAutoWelcome();
  }

  Future<void> _ensureHive() async {
    if (!Hive.isBoxOpen('chat')) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
      _chatBox = await Hive.openBox('chat');
    } else {
      _chatBox = Hive.box('chat');
    }
    if (!Hive.isBoxOpen('cache')) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
      _cacheBox = await Hive.openBox('cache');
    } else {
      _cacheBox = Hive.box('cache');
    }
  }

  void _loadSettingsFromHive() {
    if (_chatBox == null) return;
    setState(() {
      _allowAutoFollowUps =
          _chatBox!.get(
                'settings_autoFollowUps',
                defaultValue: _allowAutoFollowUps,
              )
              as bool;
      _allowIdleNudges =
          _chatBox!.get('settings_idleNudges', defaultValue: _allowIdleNudges)
              as bool;
      _idleMinutes =
          _chatBox!.get('settings_idleMinutes', defaultValue: _idleMinutes)
              as int;
      _nudgeProbability =
          _chatBox!.get(
                'settings_nudgeProbability',
                defaultValue: _nudgeProbability,
              )
              as int;
      _notificationsEnabled =
          _chatBox!.get(
                'settings_notificationsEnabled',
                defaultValue: _notificationsEnabled,
              )
              as bool;
      _morningNudge =
          _chatBox!.get('settings_morningNudge', defaultValue: _morningNudge)
              as bool;
      _eveningNudge =
          _chatBox!.get('settings_eveningNudge', defaultValue: _eveningNudge)
              as bool;
      _morningHour =
          _chatBox!.get('settings_morningHour', defaultValue: _morningHour)
              as int;
      _morningMinute =
          _chatBox!.get('settings_morningMinute', defaultValue: _morningMinute)
              as int;
      _eveningHour =
          _chatBox!.get('settings_eveningHour', defaultValue: _eveningHour)
              as int;
      _eveningMinute =
          _chatBox!.get('settings_eveningMinute', defaultValue: _eveningMinute)
              as int;
      _contentMixFunny =
          _chatBox!.get(
                'settings_nudgeContentMixFunny',
                defaultValue: _contentMixFunny,
              )
              as int;
    });
    _resetIdleTimer();
    _scheduleOrCancelDailyNudge();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _markActivity() {
    _lastActivity = DateTime.now();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(minutes: _idleMinutes), _onIdleTimeout);
  }

  // =====================
  // Events integration
  // =====================
  Future<Box> _ensureEventsBox() async {
    if (Hive.isBoxOpen('events')) return Hive.box('events');
    try {
      await Hive.initFlutter();
    } catch (_) {}
    return await Hive.openBox('events');
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    final box = await _ensureEventsBox();
    final list = (box.get('list') as List?)?.cast<Map>() ?? [];
    final events =
        list
            .map(
              (e) => {
                'id': e['id'] as int,
                'title': e['title'] as String,
                'description': (e['description'] ?? '') as String,
                'datetime': DateTime.fromMillisecondsSinceEpoch(e['ts'] as int),
              },
            )
            .toList()
          ..sort(
            (a, b) => (a['datetime'] as DateTime).compareTo(
              b['datetime'] as DateTime,
            ),
          );
    return events;
  }

  Future<void> _saveEvents(List<Map<String, dynamic>> events) async {
    final box = await _ensureEventsBox();
    final list = events
        .map(
          (e) => {
            'id': e['id'],
            'title': e['title'],
            'description': e['description'],
            'ts': (e['datetime'] as DateTime).millisecondsSinceEpoch,
          },
        )
        .toList();
    await box.put('list', list);
  }

  Future<String?> _upcomingEventsSummary() async {
    final events = await _loadEvents();
    final now = DateTime.now();
    final upcoming = events
        .where((e) => (e['datetime'] as DateTime).isAfter(now))
        .toList();
    if (upcoming.isEmpty) return null;
    final take = upcoming
        .take(3)
        .map((e) {
          final dt = e['datetime'] as DateTime;
          final t = DateFormat('EEE, MMM d • h:mm a').format(dt);
          return "- ${e['title']} @ $t";
        })
        .join("\n");
    return take;
  }

  DateTime? _parseWhen(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    // tomorrow at HH or HH:MM with am/pm
    final rxRel = RegExp(
      r"(?:on\s+)?(today|tomorrow)\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?",
    );
    final rxAt = RegExp(r"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?\b");
    final rxOnAt = RegExp(
      r"on\s+([A-Za-z]{3,9}\s+\d{1,2})\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?",
    );

    RegExpMatch? m;
    if ((m = rxRel.firstMatch(lower)) != null) {
      final rel = m!.group(1)!; // today|tomorrow
      final h = int.parse(m.group(2)!);
      final mm = int.tryParse(m.group(3) ?? '0') ?? 0;
      String? ampm = m.group(4);
      if (ampm != null) ampm = ampm.substring(0, 1); // amm->a, pmm->p
      int hour = h % 12;
      if (ampm == 'p') hour += 12;
      final base = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: rel == 'tomorrow' ? 1 : 0));
      return DateTime(base.year, base.month, base.day, hour, mm);
    }
    if ((m = rxOnAt.firstMatch(lower)) != null) {
      final dateStr = m!.group(1)!; // e.g., Nov 5
      final h = int.parse(m.group(2)!);
      final mm = int.tryParse(m.group(3) ?? '0') ?? 0;
      String? ampm = m.group(4);
      if (ampm != null) ampm = ampm.substring(0, 1);
      int hour = h % 12;
      if (ampm == 'p') hour += 12;
      try {
        final parsed = DateFormat('MMM d').parse(dateStr);
        final y =
            now.year +
            ((DateTime(now.year, parsed.month, parsed.day).isBefore(now))
                ? 1
                : 0);
        return DateTime(y, parsed.month, parsed.day, hour, mm);
      } catch (_) {}
    }
    if ((m = rxAt.firstMatch(lower)) != null) {
      final h = int.parse(m!.group(1)!);
      final mm = int.tryParse(m.group(2) ?? '0') ?? 0;
      String? ampm = m.group(3);
      if (ampm != null) ampm = ampm.substring(0, 1);
      int hour = h % 12;
      if (ampm == 'p') hour += 12;
      var dt = DateTime(now.year, now.month, now.day, hour, mm);
      if (dt.isBefore(now)) {
        dt = dt.add(const Duration(days: 1));
      }
      return dt;
    }
    return null;
  }

  Future<bool> _handleEventIntent(String text) async {
    final lower = text.toLowerCase();
    // Delete intent: "delete event <title>"
    final delRx = RegExp(r"^\s*(delete|remove)\s+event\s+(.+)");
    final reschedRx = RegExp(
      r"^\s*(reschedule|move)\s+event\s+(.+)\s+to\s+(.+)",
    );

    if (delRx.hasMatch(lower)) {
      final title = delRx.firstMatch(lower)!.group(2)!.trim();
      final events = await _loadEvents();
      final idx = events.indexWhere(
        (e) => (e['title'] as String).toLowerCase().contains(title),
      );
      if (idx == -1) {
        await _streamBotReply(
          "I couldn't find that event. Want to check the Events page?",
        );
        return true;
      }
      if (!mounted) {
        return true;
      }
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete this event?'),
              content: Text(events[idx]['title'] as String),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ??
          false;
      if (!context.mounted) {
        return true;
      }
      if (!confirmed) return true;
      final id = events[idx]['id'] as int;
      events.removeAt(idx);
      await _saveEvents(events);
      await NotificationService.instance.cancelById(id);
      await _streamBotReply("Done. I removed that event.");
      return true;
    }

    if (reschedRx.hasMatch(lower)) {
      final m = reschedRx.firstMatch(lower)!;
      final titlePart = m.group(2)!.trim();
      final whenStr = m.group(3)!.trim();
      final when = _parseWhen(whenStr);
      if (when == null) {
        await _streamBotReply(
          "I couldn't understand the new time. Try like ‘reschedule event Doctor to tomorrow at 5pm’. ",
        );
        return true;
      }
      final events = await _loadEvents();
      final idx = events.indexWhere(
        (e) => (e['title'] as String).toLowerCase().contains(titlePart),
      );
      if (idx == -1) {
        await _streamBotReply(
          "I couldn't find that event. Want to check the Events page?",
        );
        return true;
      }
      events[idx] = {
        'id': events[idx]['id'],
        'title': events[idx]['title'],
        'description': events[idx]['description'],
        'datetime': when,
      };
      await _saveEvents(events);
      final notifOn = _notificationsEnabled;
      await NotificationService.instance.cancelById(events[idx]['id'] as int);
      if (notifOn) {
        await NotificationService.instance.scheduleAt(
          id: events[idx]['id'] as int,
          title: 'Reminder',
          body: "${events[idx]['title']} • ${events[idx]['description']}",
          when: when,
        );
      }
      await _streamBotReply(
        "Updated. I moved it to ${DateFormat('EEE, MMM d • h:mm a').format(when)}.",
      );
      return true;
    }

    // Create intent: detect any parseable time plus intent-y wording
    final parsedWhen = _parseWhen(lower);
    if (parsedWhen != null &&
        (lower.contains('remind') ||
            lower.contains('have') ||
            lower.contains('appt') ||
            lower.contains('appointment') ||
            lower.contains('meeting') ||
            lower.contains('birthday') ||
            lower.contains('event'))) {
      final when = parsedWhen;
      // Title extraction: simple fallback to the original text trimmed
      String title = 'Reminder';
      if (RegExp(r"\bhave\s+(.+?)\s+on\s").hasMatch(lower)) {
        // e.g., have meeting on today 10 am
        final tMatch = RegExp(r"\bhave\s+(.+?)\s+on\s").firstMatch(lower);
        if (tMatch != null) {
          title = tMatch.group(1)!.trim();
        }
      } else if (lower.contains('doctor')) {
        title = 'Doctor Appointment';
      } else if (lower.contains('meeting')) {
        title = 'Meeting';
      } else if (lower.contains('birthday')) {
        title = "Birthday";
      } else {
        // try to extract words before 'at' or 'on'
        final tMatch = RegExp(
          r"remind me\s+(?:to\s+)?(.+?)\s+(?:at|on) ",
        ).firstMatch(lower);
        if (tMatch != null) {
          title = tMatch.group(1)!.trim();
        }
      }
      final id = DateTime.now().microsecondsSinceEpoch % 1000000000;
      final events = await _loadEvents();
      events.add({
        'id': id,
        'title': title[0].toUpperCase() + title.substring(1),
        'description': '',
        'datetime': when,
      });
      events.sort(
        (a, b) =>
            (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime),
      );
      await _saveEvents(events);
      if (_notificationsEnabled) {
        await NotificationService.instance.scheduleAt(
          id: id,
          title: 'Reminder',
          body:
              '${title[0].toUpperCase() + title.substring(1)} • ${DateFormat('EEE, MMM d • h:mm a').format(when)}',
          when: when,
        );
      }
      await _streamBotReply(
        "Got it — I saved ‘${title[0].toUpperCase() + title.substring(1)}’ for ${DateFormat('EEE, MMM d • h:mm a').format(when)}.",
      );
      return true;
    }

    return false;
  }

  Future<void> _scheduleOrCancelDailyNudge() async {
    // Cancel existing schedules (both IDs) before rescheduling
    await NotificationService.instance.cancelDailyNudge(id: 9001);
    await NotificationService.instance.cancelDailyNudge(id: 9002);
    if (!_notificationsEnabled) return;

    final title = aiName.isEmpty ? 'Chativio' : aiName;
    if (_morningNudge) {
      final bodyM = _nudgeContentForNow();
      await NotificationService.instance.scheduleDailyNudge(
        title,
        bodyM,
        hour: _morningHour,
        minute: _morningMinute,
        id: 9001,
      );
    }
    if (_eveningNudge) {
      final bodyE = _nudgeContentForNow();
      await NotificationService.instance.scheduleDailyNudge(
        title,
        bodyE,
        hour: _eveningHour,
        minute: _eveningMinute,
        id: 9002,
      );
    }
  }

  String _nudgeContentForNow() {
    final now = DateTime.now();
    final dow = DateFormat('EEEE').format(now); // e.g. Monday
    final month = DateFormat('MMMM').format(now);
    final day = now.day;
    final mem = _memory.toLowerCase();

    // Funny vs helpful bias by slider
    final roll = Random().nextInt(100);
    final preferFunny = roll < _contentMixFunny;

    final funny = <String>[
      "Fun fact for $dow: honey never spoils 🍯",
      "Random thought for $dow: turtles can breathe through their butts. Nature’s wild. 🐢",
      "Mini‑prompt: describe your day in 3 emojis.",
      "Your $month $day fortune: snacks improve all decisions.",
    ];
    final helpful = <String>[
      "It’s $month $day — perfect for a tiny win. What’s one?",
      "Quick thought: what made you smile today? 🙂",
      "Micro‑nudge: 1 minute of deep breathing can reset your focus.",
    ];

    // Memory-based preferences get priority when not preferring funny
    if (!preferFunny) {
      if (mem.contains('music') || mem.contains('song')) {
        return "It’s $dow already — heard any good songs today? 🎶";
      }
      if (mem.contains('movie') ||
          mem.contains('series') ||
          mem.contains('anime')) {
        return "$month $day vibes: got a show or movie in mind tonight? 🍿";
      }
      if (mem.contains('gym') ||
          mem.contains('run') ||
          mem.contains('health')) {
        return "Tiny reminder: a small stretch this $dow counts too 💪";
      }
      if (mem.contains('study') ||
          mem.contains('exam') ||
          mem.contains('learn')) {
        return "Happy $dow! A 10‑minute review could feel great 📚";
      }
    }

    final pool = preferFunny ? funny : helpful;
    return pool[Random().nextInt(pool.length)];
  }

  Future<void> _maybeAutoWelcome() async {
    await _ensureHive();
    final sentKey = 'welcome_sent_$userName';
    final alreadySent = _chatBox!.get(sentKey, defaultValue: false) as bool;
    if (alreadySent) return;

    // Only send if chat is empty to avoid intruding on existing chats
    if (_messages.isNotEmpty) {
      await _chatBox!.put(sentKey, true);
      return;
    }

    final uname = userName.isEmpty ? 'there' : userName;
    final aName = aiName.isEmpty ? 'Chativio' : aiName;
    final welcome =
        "Hey $uname! I’m $aName — happy to meet you. Want me to remember anything or just start chatting?";

    try {
      setState(() {
        _isTyping = true;
      });
      // pre-send typing delay with slight randomness
      final baseMs = 700 + Random().nextInt(300); // 700..999ms
      await Future.delayed(Duration(milliseconds: baseMs));
      if (!mounted) return;

      final parts = _splitReplyIntoChunks(welcome);
      final needsSplit = welcome.length > 140 || parts.length > 1;
      if (!needsSplit) {
        await _streamBotReply(welcome);
      } else {
        await _streamBotReplyChunks(parts);
      }

      // Simulate status updates
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _updateLastBotStatus("delivered");
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _updateLastBotStatus("seen");
      });
      _scrollToBottom();
      _saveChatHistory();
      await _chatBox!.put(sentKey, true);
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  String _proactiveMessageFromMemory() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? "morning"
        : (hour < 18 ? "afternoon" : "evening");

    // Light personalization using memory keywords
    final m = _memory.toLowerCase();
    if (m.contains("work")) {
      return "Hope your $greeting isn’t too packed with work today. How are you feeling?";
    }
    if (m.contains("study") || m.contains("exam") || m.contains("learn")) {
      return "Quick check-in — how’s studying going this $greeting? Want a tiny break?";
    }
    if (m.contains("music") || m.contains("song")) {
      return "Random thought — heard any good songs lately? I remember you like music 🎶";
    }
    if (m.contains("movie") || m.contains("series") || m.contains("anime")) {
      return "Hey $userName, got any shows or movies in mind for this $greeting?";
    }
    if (m.contains("gym") || m.contains("health") || m.contains("run")) {
      return "Tiny nudge — did you get a little movement in today? Even a short walk helps.";
    }
    // Generic friendly nudge
    return "Just checking in, $userName — how’s your $greeting going?";
  }

  Future<void> _onIdleTimeout() async {
    _resetIdleTimer();
    if (!_allowIdleNudges || _isTyping) return;

    // Ensure sufficient idle gap since last activity and last message
    final now = DateTime.now();
    if (_lastActivity != null &&
        now.difference(_lastActivity!) < Duration(minutes: _idleMinutes)) {
      return;
    }
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      final tsStr = last['ts'];
      if (tsStr != null) {
        final ts = int.tryParse(tsStr);
        if (ts != null) {
          if (now.difference(DateTime.fromMillisecondsSinceEpoch(ts)) <
              Duration(minutes: _idleMinutes)) {
            return;
          }
        }
      }
    }

    // Small probability to avoid feeling spammy
    if (Random().nextInt(100) >= _nudgeProbability) return; // probability gate

    final proactive = _proactiveMessageFromMemory();
    try {
      setState(() {
        _isTyping = true;
      });

      // pre-send typing
      final minTyping = const Duration(milliseconds: 700);
      await Future.delayed(minTyping);
      if (!mounted) return;

      // Stream as single or chunked
      final parts = _splitReplyIntoChunks(proactive);
      final needsSplit = proactive.length > 160 || parts.length > 1;
      if (!needsSplit) {
        await _streamBotReply(proactive);
      } else {
        await _streamBotReplyChunks(parts);
      }

      // Simulate status updates for bot message
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _updateLastBotStatus("delivered");
      });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _updateLastBotStatus("seen");
      });
      _scrollToBottom();
      _saveChatHistory();
    } finally {
      setState(() {
        _isTyping = false;
      });
      _markActivity();
    }
  }

  // ----- Group timestamp helpers -----
  int? _tsOf(Map<String, String> m) {
    final s = m['ts'];
    if (s == null) return null;
    return int.tryParse(s);
  }

  bool _isDifferentDay(int aMs, int bMs) {
    final a = DateTime.fromMillisecondsSinceEpoch(aMs);
    final b = DateTime.fromMillisecondsSinceEpoch(bMs);
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  String _formatDayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    if (that == today) return 'Today';
    final yesterday = today.subtract(const Duration(days: 1));
    if (that == yesterday) return 'Yesterday';
    return DateFormat('EEE, d MMM yyyy').format(d);
  }

  Widget _timestampChip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget? _maybeSeparatorAbove(int msgIndex) {
    if (msgIndex <= 0 || msgIndex >= _messages.length) {
      final ts = _tsOf(_messages[msgIndex]);
      if (ts == null) return null;
      return _timestampChip(_formatDayLabel(ts));
    }
    final currTs = _tsOf(_messages[msgIndex]);
    final prevTs = _tsOf(_messages[msgIndex - 1]);
    if (currTs == null || prevTs == null) return null;
    if (_isDifferentDay(currTs, prevTs)) {
      return _timestampChip(_formatDayLabel(currTs));
    }
    final gap = currTs - prevTs;
    if (gap > const Duration(minutes: 10).inMilliseconds) {
      final d = DateTime.fromMillisecondsSinceEpoch(currTs);
      return _timestampChip(DateFormat('h:mm a').format(d));
    }
    return null;
  }

  String _nowHHmm() {
    final now = DateTime.now();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return "${two(now.hour)}:${two(now.minute)}";
  }

  void _updateLastUserStatus(String status) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.containsKey("user")) {
        _messages[i] = {...m, "status": status};
        break;
      }
    }
  }

  List<String> _splitReplyIntoChunks(String reply) {
    final trimmed = reply.trim();
    if (trimmed.isEmpty) return [];

    final paras = trimmed.split(RegExp(r"\n\s*\n+"));
    List<String> sentences;
    if (paras.length > 1) {
      sentences = paras;
    } else {
      sentences = trimmed.split(RegExp(r"(?<=[.!?])\s+"));
    }

    const int maxLen = 160;
    final List<String> chunks = [];
    String cur = "";
    for (final s in sentences) {
      if (s.isEmpty) continue;
      if (cur.isEmpty) {
        cur = s.trim();
      } else if ((cur.length + 1 + s.length) <= maxLen) {
        cur = "$cur ${s.trim()}";
      } else {
        chunks.add(cur);
        cur = s.trim();
      }
    }
    if (cur.isNotEmpty) chunks.add(cur);
    return chunks;
  }

  Future<void> _streamBotReplyChunks(List<String> chunks) async {
    final int limit = chunks.length > 2 ? 2 : chunks.length; // cap to 2 bubbles
    for (int i = 0; i < limit; i++) {
      final part = chunks[i];
      await _streamBotReply(part);
      if (i < limit - 1) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    _maybeNotifyLastBot();
  }

  void _updateLastBotStatus(String status) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.containsKey("bot")) {
        _messages[i] = {...m, "status": status};
        break;
      }
    }
  }

  Future<void> _streamBotReply(String reply) async {
    if (!mounted) return;
    final int botMsgIndex = _messages.length;
    setState(() {
      _messages.add({
        "bot": "",
        "time": _nowHHmm(),
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });
    });
    _scrollToBottom();

    // Fast, ultra-smooth word streaming
    final words = reply.split(' ');
    if (words.length <= 4) {
      // Short response: render quickly
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          if (botMsgIndex < _messages.length) {
            _messages[botMsgIndex] = {..._messages[botMsgIndex], "bot": reply};
          }
        });
        _scrollToBottom();
      }
      _maybeNotifyLastBot();
      return;
    }

    final buffer = StringBuffer();
    const chunkSize = 2; // Stream 2 words per tick
    for (int i = 0; i < words.length; i += chunkSize) {
      if (!mounted) return;
      final end = (i + chunkSize < words.length) ? i + chunkSize : words.length;
      for (int k = i; k < end; k++) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(words[k]);
      }
      setState(() {
        if (botMsgIndex < _messages.length) {
          _messages[botMsgIndex] = {
            ..._messages[botMsgIndex],
            "bot": buffer.toString(),
          };
        }
      });
      _scrollToBottom();
      await Future.delayed(const Duration(milliseconds: 16));
    }

    // Ensure final exact string
    if (mounted) {
      setState(() {
        if (botMsgIndex < _messages.length) {
          _messages[botMsgIndex] = {..._messages[botMsgIndex], "bot": reply};
        }
      });
      _scrollToBottom();
    }
    _maybeNotifyLastBot();
  }

  Future<String> _analyzeMood(String text) async {
    final mood = await AiService.instance.analyzeMood(text);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("last_mood", mood);
    } catch (_) {}
    return mood;
  }

  List<String>? _localReplyFor(String userText) {
    final t = userText.toLowerCase().trim();
    final bool mentionsToday =
        t.contains("today") ||
        t.contains("today's") ||
        t.contains("todays") ||
        t.contains("now");
    final bool asksDay =
        t.contains("what is the day") ||
        t.contains("what day") ||
        t.contains("day today") ||
        t.contains("day is it");
    final bool asksDate =
        t.contains("what is the date") ||
        t.contains("date today") ||
        t.contains("today's date") ||
        t.contains("todays date");
    final bool asksTime =
        t.contains("what time is it") ||
        t.contains("what's the time") ||
        t.contains("whats the time") ||
        t.contains("current time") ||
        t.contains("time now") ||
        t == "time?" ||
        t == "time";
    final bool asksWeekdayOnly =
        t.contains("weekday") ||
        t == "day?" ||
        t.contains("which day") ||
        t == "which day?";
    final bool asksMonth =
        t.contains("what month") ||
        t.contains("current month") ||
        t.contains("month now") ||
        t == "month?" ||
        t == "month";
    final bool asksYear =
        t.contains("what year") ||
        t.contains("current year") ||
        t.contains("year now") ||
        t == "year?" ||
        t == "year";
    final bool asksAiName =
        t.contains("your name") ||
        t.contains("who are you") ||
        t == "name?" ||
        t == "what is your name" ||
        t == "whats your name" ||
        t == "what's your name";
    final bool asksDaysUntilFriday =
        t.contains("days until friday") ||
        t.contains("how many days until friday") ||
        t == "until friday?" ||
        t == "friday?";
    final bool asksWeather =
        t.contains("weather") ||
        t.contains("raining") ||
        t.contains("rain today") ||
        t.contains("temperature");

    if (mentionsToday && (asksDay || asksDate)) {
      // Build a friendly human-like answer
      final now = DateTime.now();
      const days = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      ];
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final dow = days[(now.weekday - 1).clamp(0, 6)];
      final day = now.day.toString().padLeft(2, '0');
      final mon = months[(now.month - 1).clamp(0, 11)];
      final yr = now.year;

      final main = "It's $dow, $day $mon $yr.";
      final follow = "Got any plans today, $userName?";
      return [main, follow];
    }

    // Weekday only
    if (asksWeekdayOnly) {
      final now = DateTime.now();
      const days = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      ];
      final dow = days[(now.weekday - 1).clamp(0, 6)];
      return ["It's $dow."];
    }

    // Current month
    if (asksMonth) {
      final now = DateTime.now();
      const months = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December",
      ];
      final mon = months[(now.month - 1).clamp(0, 11)];
      final main = "It's $mon.";
      final follow = "Time flies, right $userName?";
      return [main, follow];
    }

    // Current year
    if (asksYear) {
      final yr = DateTime.now().year;
      return ["It's $yr."];
    }

    // AI name / identity
    if (asksAiName) {
      final main = "I'm $aiName — your chat buddy.";
      final follow = "What should I call you today, $userName?";
      return [main, follow];
    }

    // Days until Friday
    if (asksDaysUntilFriday) {
      final now = DateTime.now();
      int d = now.weekday; // Mon=1 .. Sun=7
      int days;
      if (d <= DateTime.friday) {
        days = DateTime.friday - d;
      } else {
        days = 7 - (d - DateTime.friday);
      }
      final main = days == 0
          ? "It's Friday today!"
          : "$days day${days == 1 ? '' : 's'} until Friday.";
      final follow = days <= 1
          ? "Any plans for the weekend, $userName?"
          : "Anything you’re looking forward to this week?";
      return [main, follow];
    }

    // Weather nudge (no API; ask for location)
    if (asksWeather) {
      String hint = "Share your city or location and I’ll check for you.";
      if (_memory.toLowerCase().contains("city:")) {
        hint = "Remind me your current city, I can check quickly.";
      }
      return ["I can look up the weather for you.", hint];
    }

    // Also handle questions like: what day is it? / date?
    if (t.contains("what day is it") ||
        t == "day?" ||
        t == "date?" ||
        t.contains("what's the date") ||
        t.contains("whats the date")) {
      final now = DateTime.now();
      const days = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
      ];
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      final dow = days[(now.weekday - 1).clamp(0, 6)];
      final day = now.day.toString().padLeft(2, '0');
      final mon = months[(now.month - 1).clamp(0, 11)];
      final yr = now.year;
      return ["It's $dow, $day $mon $yr."];
    }

    // Handle local time questions
    if (asksTime) {
      final now = DateTime.now();
      int hour = now.hour;
      final int minute = now.minute;
      final String ampm = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final String mm = minute.toString().padLeft(2, '0');
      final String timeText = "$hour:$mm $ampm";
      final main = "It's $timeText.";
      final follow = "How’s your day going so far, $userName?";
      return [main, follow];
    }

    return null;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (!SubscriptionService.instance.canSendMessage) {
      _showProLimitReachedDialog();
      return;
    }
    await SubscriptionService.instance.recordMessageSent();
    _engagement.recordUserMessage().then((_) {
      if (mounted) setState(() {});
    });

    setState(() {
      _messages.add({
        "user": text,
        "time": _nowHHmm(),
        "status": "sent",
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });
      _isTyping = true;
    });
    _scrollToBottom();

    _controller.clear();

    // 🧠 Refocus after sending message
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_focusNode);

    // 🔍 NLP: Parse for schedule commands
    final scheduleCmd = NlpService().parseScheduleCommand(text);
    if (scheduleCmd != null) {
      final event = scheduleCmd['event'] as String;
      final dateTime = scheduleCmd['dateTime'] as DateTime;
      // Suggest creating the event
      await _suggestScheduleEvent(event, dateTime);
      return; // Stop further processing
    }

    // 📅 Events: intercept create/edit/delete intents from user text
    final handledEvent = await _handleEventIntent(text);
    if (handledEvent) {
      // Already replied and scheduled. Stop further processing.
      setState(() {
        _isTyping = false;
      });
      _saveChatHistory();
      return;
    }

    // 🧠 Detect mood before replying
    _currentMood = await _analyzeMood(text);

    // ⚡ Local quick answers (no API) — e.g., today's date/day
    final localParts = _localReplyFor(text);
    if (localParts != null && localParts.isNotEmpty) {
      try {
        setState(() {
          _updateLastUserStatus("delivered");
        });

        // Snappy local response beat
        await Future.delayed(const Duration(milliseconds: 60));

        // cap to 2 bubbles for pacing
        final int limit = localParts.length > 2 ? 2 : localParts.length;
        for (int i = 0; i < limit; i++) {
          await _streamBotReply(localParts[i]);
          if (i < limit - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        setState(() {
          _updateLastUserStatus("seen");
        });
        _scrollToBottom();
        _saveChatHistory();
      } finally {
        setState(() {
          _isTyping = false;
        });
      }
      return;
    }

    final eventsSummary = await _upcomingEventsSummary();
    final systemPrompt = PersonaService.instance.buildSystemPrompt(
      userName: userName,
      userGender: userGender,
      aiName: aiName,
      currentMood: _currentMood,
      memory: _memory,
      eventsSummary: eventsSummary,
    );

    bool replyReceived = false;

    try {
      final reply = await AiService.instance.getChatReply(
        systemPrompt: systemPrompt,
        messages: _messages,
      );

      if (reply.isNotEmpty) {
        replyReceived = true;
        // Cache the response
        await _cacheBox?.put(text, reply);

        // Update user status
        setState(() {
          _updateLastUserStatus("delivered");
        });

        if (!mounted) return;

        // Stream reply
        final parts = _splitReplyIntoChunks(reply);
        final bool needsSplit = reply.length > 140 || parts.length > 1;
        if (!needsSplit) {
          await _streamBotReply(reply);
        } else {
          await _streamBotReplyChunks(parts);
        }

        // Voice
        if (_voiceResponses) {
          await _voiceService.speak(reply);
        }

        setState(() {
          _updateLastUserStatus("seen");
        });
        _scrollToBottom();

        // Smart memory update
        if (_messages.isNotEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          await _safeUpdateMemory(text);
        }

        final humanLikeMsg = _getHumanLikeMessage(
          _messages,
          _currentMood,
          _memory,
        );
        final shouldAutoFollow =
            _allowAutoFollowUps &&
            humanLikeMsg != null &&
            (Random().nextInt(100) < 20);
        if (shouldAutoFollow) {
          await Future.delayed(const Duration(seconds: 2));
          setState(() {
            _messages.add({
              "bot": humanLikeMsg,
              "time": _nowHHmm(),
              "status": "sent",
              "ts": DateTime.now().millisecondsSinceEpoch.toString(),
            });
          });
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            _updateLastBotStatus("delivered");
          });
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {
            _updateLastBotStatus("seen");
          });
        }

        _saveChatHistory();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Chat Error: $e");
      if (!replyReceived) {
        _showOfflineReply(text);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    }
  }

  void _showOfflineReply(String userText) {
    setState(() {
      final cachedReply = _cacheBox?.get(userText) as String?;
      final offlineReply = cachedReply ?? _offlineReply();
      _messages.add({
        "bot": offlineReply,
        "time": _nowHHmm(),
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });
    });
    _scrollToBottom();
  }

  // 🔍 NLP: Suggest scheduling an event
  Future<void> _suggestScheduleEvent(String event, DateTime dateTime) async {
    final formattedTime = DateFormat('EEE, MMM d • h:mm a').format(dateTime);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Event?'),
        content: Text(
          'I detected you want to schedule: "$event" for $formattedTime. Create this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final id = DateTime.now().microsecondsSinceEpoch % 1000000000;
      final events = await _loadEvents();
      events.add({
        'id': id,
        'title': event,
        'description': '',
        'datetime': dateTime,
      });
      events.sort(
        (a, b) =>
            (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime),
      );
      await _saveEvents(events);
      if (_notificationsEnabled) {
        await NotificationService.instance.scheduleAt(
          id: id,
          title: 'Reminder',
          body: '$event • $formattedTime',
          when: dateTime,
        );
      }
      await _streamBotReply("Got it! I scheduled '$event' for $formattedTime.");
    } else {
      await _streamBotReply("Alright, if you change your mind, just tell me!");
    }

    setState(() {
      _isTyping = false;
    });
    _saveChatHistory();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (kDebugMode) debugPrint('onStatus: $val');
        },
        onError: (val) {
          if (kDebugMode) debugPrint('onError: $val');
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      if (!SubscriptionService.instance.canSendMessage) {
        _showProLimitReachedDialog();
        return;
      }
      await SubscriptionService.instance.recordMessageSent();

      setState(() {
        _messages.add({
          "user_image": image.path,
          "time": _nowHHmm(),
          "status": "sent",
          "ts": DateTime.now().millisecondsSinceEpoch.toString(),
        });
        _isTyping = true;
      });
      _scrollToBottom();
      _saveChatHistory();

      try {
        final systemPrompt = PersonaService.instance.buildSystemPrompt(
          userName: userName,
          userGender: userGender,
          aiName: aiName,
          currentMood: _currentMood,
          memory: _memory,
        );

        final reply = await AiService.instance.getChatReply(
          systemPrompt: systemPrompt,
          messages: _messages,
          imagePath: image.path,
          userPrompt:
              "I just shared this photo with you! Tell me what you think and what you notice about it.",
        );

        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add({
            "bot": reply,
            "time": _nowHHmm(),
            "status": "delivered",
            "ts": DateTime.now().millisecondsSinceEpoch.toString(),
          });
        });
        _scrollToBottom();
        _saveChatHistory();

        if (_voiceResponses) {
          await _voiceService.speak(reply);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isTyping = false);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _offlineReply() {
    final replies = [
      "I'm offline right now, but I'm here with you in spirit! 🌟 What's on your mind?",
      "No internet? No problem! Tell me something fun about your day. 😊",
      "Connection's spotty, but our chat is timeless. How are you feeling today?",
      "Oops, I'm disconnected, but let's pretend we're chatting anyway. Your turn! 🎉",
    ];
    return replies[DateTime.now().millisecond % replies.length];
  }

  void _maybeNotifyLastBot() {
    if (ChatScreen.isOpen) return;
    if (!_notificationsEnabled) return;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.containsKey('bot')) {
        final body = (m['bot'] ?? '').trim();
        if (body.isEmpty) return;
        final preview = body.length > 120 ? '${body.substring(0, 120)}…' : body;
        NotificationService.instance.show(aiName, preview);
        return;
      }
    }
  }

  String? _getHumanLikeMessage(
    List<Map<String, String>> messages,
    String currentMood,
    String memory,
  ) {
    if (messages.isEmpty) return null;
    final lastUserMsg = messages.reversed
        .firstWhere(
          (m) => m.containsKey("user"),
          orElse: () => {"user": ""},
        )["user"]!
        .toLowerCase();
    switch (currentMood) {
      case "sad":
        return "I’m here for you 🫶 Want to talk about it a bit?";
      case "tired":
        return "You’ve been doing a lot — a tiny break might help. How are you holding up?";
      case "angry":
        return "That sounds frustrating 😤 Do you want to vent a little?";
      case "happy":
        return "Love that! 😄 What made you smile just now?";
      case "stressed":
        return "You seem a bit stressed 😌 Anything I can do to lighten it?";
      case "excited":
        return "Haha I can feel the hype 🎉 what’s the plan?";
    }
    final mem = memory.toLowerCase();
    if (mem.isNotEmpty) {
      if (mem.contains("work") &&
          (lastUserMsg.contains("work") || lastUserMsg.contains("office"))) {
        return "You’ve mentioned work a bunch — make sure you get a breather too.";
      }
      if (mem.contains("favorite") &&
          (lastUserMsg.contains("movie") || lastUserMsg.contains("music"))) {
        return "Still into your favorite one? 🎶";
      }
    }
    if (lastUserMsg.contains("tired") || lastUserMsg.contains("sleep")) {
      return "You sound worn out 😴 — want to slow down a bit?";
    }
    if (lastUserMsg.contains("study") || lastUserMsg.contains("learn")) {
      return "Proud of your focus 📚 — what’s next on your list?";
    }
    if (lastUserMsg.contains("alone") || lastUserMsg.contains("bored")) {
      return "I’m here with you 💙 Want to do a quick fun prompt?";
    }
    if (lastUserMsg.contains("thank")) {
      return "You don’t have to thank me 😄 I like chatting with you.";
    }
    if (DateTime.now().millisecond % 10 == 4) {
      return "Chatting with you feels nice 🙂";
    }
    return null;
  }

  Widget _buildMessageAt(int msgIndex) {
    final message = _messages[msgIndex];
    final isUser =
        message.containsKey("user") || message.containsKey("user_image");
    final hasImage = message.containsKey("user_image");
    final text = hasImage
        ? null
        : (isUser ? message["user"]! : message["bot"]!);
    final imagePath = hasImage ? message["user_image"] : null;
    final time = message["time"] ?? "";
    final status = message["status"];

    final separator = _maybeSeparatorAbove(msgIndex);

    return TweenAnimationBuilder<double>(
      key: ValueKey(message["ts"]), // animate per message
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (separator != null) separator,
            Stack(
              clipBehavior: Clip.none,
              children: [
                Row(
                  mainAxisAlignment: isUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isUser) ...[
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.pinkAccent,
                        child: Icon(
                          Icons.smart_toy,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    GestureDetector(
                      onDoubleTap: () => _toggleMessageReaction(msgIndex, "❤️"),
                      child: MessageBubble(
                        text: text,
                        imagePath: imagePath,
                        isUser: isUser,
                        time: time,
                        status: status,
                        onLongPress: () => _onLongPressMessage(msgIndex),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 6),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.purpleAccent,
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                if (message.containsKey("reaction"))
                  Positioned(
                    bottom: -8,
                    right: isUser ? 28 : null,
                    left: isUser ? null : 28,
                    child: GestureDetector(
                      onTap: () => _toggleMessageReaction(msgIndex),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.black12,
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message["reaction"]!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMessageReaction(int index, [String reaction = "❤️"]) {
    HapticFeedback.lightImpact();
    if (index < 0 || index >= _messages.length) return;
    setState(() {
      final current = _messages[index]["reaction"];
      if (current == reaction) {
        _messages[index].remove("reaction");
      } else {
        _messages[index]["reaction"] = reaction;
      }
    });
    _saveChatHistory();
  }

  Future<void> _onLongPressMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final m = _messages[index];
    final hasImage = m.containsKey("user_image");
    final text = hasImage ? null : (m['user'] ?? m['bot'] ?? '');
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Wrap(
            children: [
              // Quick Emoji Reaction Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["❤️", "🔥", "😊", "😂", "👍"].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleMessageReaction(index, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              if (!hasImage) ...[
                ListTile(
                  leading: const Icon(Icons.content_copy),
                  title: const Text('Copy'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: text!));
                    if (!mounted) return;
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.forward),
                  title: const Text('Forward'),
                  onTap: () async {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 50));
                    if (!mounted) return;
                    await Share.share(text!);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.select_all),
                  title: const Text('Select text'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Select text'),
                        content: SelectableText(text!),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  final removed = Map<String, String>.from(m);
                  setState(() {
                    _messages.removeAt(index);
                  });
                  _saveChatHistory();
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Message deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            setState(() {
                              _messages.insert(index, removed);
                            });
                            _saveChatHistory();
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: Color(0xFF6366F1),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161F33) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TypingDots(),
                const SizedBox(width: 8),
                Text(
                  "Thinking...",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 🧠 Smart Memory Update System
  // ===============================

  // Track update state
  bool _isUpdatingMemory = false;

  // Decide if a message is meaningful enough to update memory
  bool _shouldUpdateMemory(String userMessage) {
    final text = userMessage.toLowerCase();

    // ✅ Simple trigger keywords or emotional patterns
    final keywords = [
      "remember",
      "meeting",
      "tomorrow",
      "event",
      "birthday",
      "i like",
      "i love",
      "my favorite",
      "feel",
      "sad",
      "happy",
      "angry",
      "excited",
      "worried",
    ];

    // Return true if any important word appears
    return keywords.any((word) => text.contains(word));
  }

  // Safe wrapper to avoid multiple memory updates at once
  Future<void> _safeUpdateMemory(String latestUserMessage) async {
    if (_isUpdatingMemory) return; // skip if already updating
    if (!_shouldUpdateMemory(latestUserMessage)) {
      return; // skip unimportant chats
    }

    _isUpdatingMemory = true;
    try {
      await _updateMemory(); // main update function
    } finally {
      _isUpdatingMemory = false;
    }
  }

  // Main memory update function
  Future<void> _updateMemory() async {
    try {
      final recentMessages = _messages.take(15).toList();
      final newMemory = await AiService.instance.summarizeMemory(
        userName: userName,
        aiName: aiName,
        recentMessages: recentMessages,
        existingMemory: _memory,
      );

      if (mounted && newMemory.isNotEmpty) {
        setState(() {
          _memory = "$newMemory\n\n(Last detected mood: $_currentMood)";
        });
        _saveChatHistory();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Memory update error: $e");
    }
  }

  void _showProLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Daily Limit Reached",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          "You have reached your free daily AI messages. Upgrade to Chativio Pro for unlimited conversations, voice calls, and all AI personas!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Maybe Later"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            child: const Text(
              "Get Chativio Pro",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startVoiceCall() async {
    final history = await Navigator.push<List<Map<String, String>>>(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          userName: userName,
          userGender: userGender,
          aiName: aiName,
          currentMood: _currentMood,
          memory: _memory,
        ),
      ),
    );

    if (history != null && history.isNotEmpty) {
      setState(() {
        for (final m in history) {
          _messages.add({
            ...m,
            "time": _nowHHmm(),
            "status": "delivered",
            "ts": DateTime.now().millisecondsSinceEpoch.toString(),
          });
        }
      });
      _scrollToBottom();
      _saveChatHistory();
    }
  }

  Widget _buildStreakHeader(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111728) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text("🔥", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                "${_engagement.currentStreak} Day Streak",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 12, color: primary),
                const SizedBox(width: 4),
                Text(
                  "${_engagement.relationshipLevel} • ${_engagement.totalXp} XP",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementStartersBar(bool isDark, Color primary) {
    final starters = _engagement.getDailyStarters();
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: starters.length,
        itemBuilder: (context, index) {
          final starter = starters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: null,
              label: Text(
                starter,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              backgroundColor: isDark
                  ? const Color(0xFF131A2B)
                  : const Color(0xFFE2E8F0),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                _controller.text = starter;
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPersonaBar() {
    final current = PersonaService.instance.currentPersona;
    final isPro = SubscriptionService.instance.isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x800B101E) : const Color(0x99F1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: PersonaService.availablePersonas.map((persona) {
          final isSelected = persona.id == current.id;
          final requiresLock = persona.isProOnly && !isPro;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: Icon(
                requiresLock ? Icons.lock_rounded : persona.icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (requiresLock ? Colors.amber : persona.themeColor),
              ),
              label: Text(
                persona.name,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: persona.themeColor,
              backgroundColor: isDark
                  ? const Color(0xFF131A2B)
                  : const Color(0xFFE2E8F0),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                if (requiresLock) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                } else if (selected) {
                  setState(() {
                    PersonaService.instance.setPersona(persona.id);
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF080B14)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xCC080B14)
            : const Color(0xCCFFFFFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Image.asset("assets/images/logo.png", fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    aiName.isEmpty ? "Chativio" : aiName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Always Active",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone_in_talk_rounded, color: primary),
            tooltip: "Live Voice Call",
            onPressed: () {
              HapticFeedback.lightImpact();
              _startVoiceCall();
            },
          ),
          IconButton(
            icon: Icon(
              SubscriptionService.instance.isPro
                  ? Icons.workspace_premium_rounded
                  : Icons.stars_rounded,
              color: Colors.amber,
            ),
            tooltip: SubscriptionService.instance.isPro
                ? "Chativio Pro Active"
                : "Get Pro",
            onPressed: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            icon: Icon(
              _voiceResponses
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: _voiceResponses
                ? "Voice Responses On"
                : "Voice Responses Off",
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _voiceResponses = !_voiceResponses);
              if (!_voiceResponses) {
                _voiceService.stop();
              }
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _ensureHive();
              _loadSettingsFromHive();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStreakHeader(isDark, primary),
          _buildPersonaBar(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == 0) {
                  return _buildTypingIndicator();
                }
                final logical = _isTyping ? index - 1 : index;
                final originalIdx = _messages.length - 1 - logical;
                return _buildMessageAt(originalIdx);
              },
            ),
          ),
          _buildEngagementStartersBar(isDark, primary),
          ChatInputField(
            controller: _controller,
            focusNode: _focusNode,
            onSendPressed: _sendMessage,
            onImagePressed: _showImageSourceDialog,
            onVoicePressed: _listen,
            isListening: _isListening,
          ),
        ],
      ),
    );
  }
}
