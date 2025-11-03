import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:myapp/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import './settings_screen.dart';
import '../secrets.dart'; // 
import 'package:myapp/services/nlp_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  static bool isOpen = false;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
          ..repeat();

    _animation1 = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.3, curve: Curves.easeInOut)),
    );
    _animation2 = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.5, curve: Curves.easeInOut)),
    );
    _animation3 = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7, curve: Curves.easeInOut)),
    );
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(_animation1.value),
            const SizedBox(width: 4),
            _buildDot(_animation2.value),
            const SizedBox(width: 4),
            _buildDot(_animation3.value),
          ],
        );
      },
    );
  }

  Widget _buildDot(double offset) {
    return Transform.translate(
      offset: Offset(0, -offset),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.grey,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BubbleTail extends CustomPainter {
  final Color color;
  final bool isUser;
  const _BubbleTail({required this.color, required this.isUser});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (isUser) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTail oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isUser != isUser;
  }
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  DateTime? _typingSince;
  String _memory = "";
  String _currentMood = "neutral";
  bool _allowAutoFollowUps = true; // after a normal reply
  bool _allowIdleNudges = true;    // proactive after inactivity
  int _idleMinutes = 7;            // minutes of inactivity before nudge
  int _nudgeProbability = 25;      // % chance to send after idle
  Timer? _idleTimer;
  DateTime? _lastActivity;

  // user/ai details
  String userName = '';
  String userGender = '';
  String aiName = '';
  String aiGender = '';
  bool isFirstLaunch = true;
  Box? _chatBox;
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

  final FlutterTts _tts = FlutterTts();
  bool _voiceResponses = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    ChatScreen.isOpen = true;
    NlpService().init();
    _loadOnboardingScreenData().then((_) {
      _loadChatHistory();
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
        setState(() { _memory = spMemory; });
        await _saveChatHistory();
      }
    }

    if (storedMemory is String) {
      setState(() { _memory = storedMemory; });
    }

    // After loading history, if this is the first time after onboarding and no messages yet,
    // send a short welcome message once.
    await _maybeAutoWelcome();
  }

  Future<void> _ensureHive() async {
    if (!Hive.isBoxOpen('chat')) {
      try { await Hive.initFlutter(); } catch (_) {}
      _chatBox = await Hive.openBox('chat');
    } else {
      _chatBox = Hive.box('chat');
    }
  }

  void _loadSettingsFromHive() {
    if (_chatBox == null) return;
    setState(() {
      _allowAutoFollowUps = _chatBox!.get('settings_autoFollowUps', defaultValue: _allowAutoFollowUps) as bool;
      _allowIdleNudges   = _chatBox!.get('settings_idleNudges',    defaultValue: _allowIdleNudges) as bool;
      _idleMinutes       = _chatBox!.get('settings_idleMinutes',   defaultValue: _idleMinutes) as int;
      _nudgeProbability  = _chatBox!.get('settings_nudgeProbability', defaultValue: _nudgeProbability) as int;
      _notificationsEnabled = _chatBox!.get('settings_notificationsEnabled', defaultValue: _notificationsEnabled) as bool;
      _morningNudge = _chatBox!.get('settings_morningNudge', defaultValue: _morningNudge) as bool;
      _eveningNudge = _chatBox!.get('settings_eveningNudge', defaultValue: _eveningNudge) as bool;
      _morningHour = _chatBox!.get('settings_morningHour', defaultValue: _morningHour) as int;
      _morningMinute = _chatBox!.get('settings_morningMinute', defaultValue: _morningMinute) as int;
      _eveningHour = _chatBox!.get('settings_eveningHour', defaultValue: _eveningHour) as int;
      _eveningMinute = _chatBox!.get('settings_eveningMinute', defaultValue: _eveningMinute) as int;
      _contentMixFunny = _chatBox!.get('settings_nudgeContentMixFunny', defaultValue: _contentMixFunny) as int;
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
    try { await Hive.initFlutter(); } catch (_) {}
    return await Hive.openBox('events');
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    final box = await _ensureEventsBox();
    final list = (box.get('list') as List?)?.cast<Map>() ?? [];
    final events = list.map((e) => {
          'id': e['id'] as int,
          'title': e['title'] as String,
          'description': (e['description'] ?? '') as String,
          'datetime': DateTime.fromMillisecondsSinceEpoch(e['ts'] as int),
        }).toList()
      ..sort((a, b) => (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
    return events;
  }

  Future<void> _saveEvents(List<Map<String, dynamic>> events) async {
    final box = await _ensureEventsBox();
    final list = events
        .map((e) => {
              'id': e['id'],
              'title': e['title'],
              'description': e['description'],
              'ts': (e['datetime'] as DateTime).millisecondsSinceEpoch,
            })
        .toList();
    await box.put('list', list);
  }

  Future<String?> _upcomingEventsSummary() async {
    final events = await _loadEvents();
    final now = DateTime.now();
    final upcoming = events.where((e) => (e['datetime'] as DateTime).isAfter(now)).toList();
    if (upcoming.isEmpty) return null;
    final take = upcoming.take(3).map((e) {
      final dt = e['datetime'] as DateTime;
      final t = DateFormat('EEE, MMM d • h:mm a').format(dt);
      return "- ${e['title']} @ $t";
    }).join("\n");
    return take;
  }

  DateTime? _parseWhen(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    // tomorrow at HH or HH:MM with am/pm
    final rxRel = RegExp(r"(?:on\s+)?(today|tomorrow)\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?");
    final rxAt = RegExp(r"\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?\b");
    final rxOnAt = RegExp(r"on\s+([A-Za-z]{3,9}\s+\d{1,2})\s+(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm|amm|pmm)?");

    RegExpMatch? m;
    if ((m = rxRel.firstMatch(lower)) != null) {
      final rel = m!.group(1)!; // today|tomorrow
      final h = int.parse(m.group(2)!);
      final mm = int.tryParse(m.group(3) ?? '0') ?? 0;
      String? ampm = m.group(4);
      if (ampm != null) ampm = ampm.substring(0, 1); // amm->a, pmm->p
      int hour = h % 12;
      if (ampm == 'p') hour += 12;
      final base = DateTime(now.year, now.month, now.day).add(Duration(days: rel == 'tomorrow' ? 1 : 0));
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
        final y = now.year + ((DateTime(now.year, parsed.month, parsed.day).isBefore(now)) ? 1 : 0);
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
    final reschedRx = RegExp(r"^\s*(reschedule|move)\s+event\s+(.+)\s+to\s+(.+)");

    if (delRx.hasMatch(lower)) {
      final title = delRx.firstMatch(lower)!.group(2)!.trim();
      final events = await _loadEvents();
      final idx = events.indexWhere((e) => (e['title'] as String).toLowerCase().contains(title));
      if (idx == -1) {
        await _streamBotReply("I couldn't find that event. Want to check the Events page?");
        return true;
      }
      if (!mounted) {
        return true;
      }
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete this event?'),
              content: Text(events[idx]['title'] as String),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
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
        await _streamBotReply("I couldn't understand the new time. Try like ‘reschedule event Doctor to tomorrow at 5pm’. ");
        return true;
      }
      final events = await _loadEvents();
      final idx = events.indexWhere((e) => (e['title'] as String).toLowerCase().contains(titlePart));
      if (idx == -1) {
        await _streamBotReply("I couldn't find that event. Want to check the Events page?");
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
      await _streamBotReply("Updated. I moved it to ${DateFormat('EEE, MMM d • h:mm a').format(when)}.");
      return true;
    }

    // Create intent: detect any parseable time plus intent-y wording
    final parsedWhen = _parseWhen(lower);
    if (parsedWhen != null &&
        (lower.contains('remind') || lower.contains('have') || lower.contains('appt') ||
         lower.contains('appointment') || lower.contains('meeting') || lower.contains('birthday') || lower.contains('event'))) {
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
        final tMatch = RegExp(r"remind me\s+(?:to\s+)?(.+?)\s+(?:at|on) ").firstMatch(lower);
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
      events.sort((a, b) => (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
      await _saveEvents(events);
      if (_notificationsEnabled) {
        await NotificationService.instance.scheduleAt(
          id: id,
          title: 'Reminder',
          body: '${title[0].toUpperCase() + title.substring(1)} • ${DateFormat('EEE, MMM d • h:mm a').format(when)}',
          when: when,
        );
      }
      await _streamBotReply("Got it — I saved ‘${title[0].toUpperCase() + title.substring(1)}’ for ${DateFormat('EEE, MMM d • h:mm a').format(when)}.");
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
      "Your $month $day fortune: snacks improve all decisions."
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
      if (mem.contains('movie') || mem.contains('series') || mem.contains('anime')) {
        return "$month $day vibes: got a show or movie in mind tonight? 🍿";
      }
      if (mem.contains('gym') || mem.contains('run') || mem.contains('health')) {
        return "Tiny reminder: a small stretch this $dow counts too 💪";
      }
      if (mem.contains('study') || mem.contains('exam') || mem.contains('learn')) {
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
    final welcome = "Hey $uname! I’m $aName — happy to meet you. Want me to remember anything or just start chatting?";

    try {
      setState(() { _isTyping = true; _typingSince = DateTime.now(); });
      // pre-send typing delay with slight randomness
      final baseMs = 700 + Random().nextInt(300); // 700..999ms
      await Future.delayed(Duration(milliseconds: baseMs));

      final parts = _splitReplyIntoChunks(welcome);
      final needsSplit = welcome.length > 140 || parts.length > 1;
      if (!needsSplit) {
        await _streamBotReply(welcome);
      } else {
        await _streamBotReplyChunks(parts);
      }

      // Simulate status updates
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() { _updateLastBotStatus("delivered"); });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() { _updateLastBotStatus("seen"); });
      _scrollToBottom();
      _saveChatHistory();
      await _chatBox!.put(sentKey, true);
    } finally {
      if (mounted) {
        setState(() { _isTyping = false; });
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
      return "Tiny nudge — did you get a little movement in today? Even a short walk helps."
          ;
    }
    // Generic friendly nudge
    return "Just checking in, $userName — how’s your $greeting going?";
  }

  Future<void> _onIdleTimeout() async {
    _resetIdleTimer();
    if (!_allowIdleNudges || _isTyping) return;

    // Ensure sufficient idle gap since last activity and last message
    final now = DateTime.now();
    if (_lastActivity != null && now.difference(_lastActivity!) < Duration(minutes: _idleMinutes)) {
      return;
    }
    if (_messages.isNotEmpty) {
      final last = _messages.last;
      final tsStr = last['ts'];
      if (tsStr != null) {
        final ts = int.tryParse(tsStr);
        if (ts != null) {
          if (now.difference(DateTime.fromMillisecondsSinceEpoch(ts)) < Duration(minutes: _idleMinutes)) {
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
        _typingSince = DateTime.now();
      });

      // pre-send typing
      final minTyping = const Duration(milliseconds: 700);
      await Future.delayed(minTyping);

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
      setState(() { _updateLastBotStatus("delivered"); });
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() { _updateLastBotStatus("seen"); });
      _scrollToBottom();
      _saveChatHistory();
    } finally {
      setState(() { _isTyping = false; });
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
        _messages[i] = {
          ...m,
          "status": status,
        };
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
        final pauseMs = (450 + (DateTime.now().millisecond % 400));
        await Future.delayed(Duration(milliseconds: pauseMs));
      }
    }
    _maybeNotifyLastBot();
  }

  void _updateLastBotStatus(String status) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.containsKey("bot")) {
        _messages[i] = {
          ...m,
          "status": status,
        };
        break;
      }
    }
  }

  Future<void> _streamBotReply(String reply) async {
    // Create empty bot message and progressively fill it
    setState(() {
      _messages.add({
        "bot": "",
        "time": _nowHHmm(),
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });
    });
    _scrollToBottom();

    // Decide total streaming duration (with slight randomness)
    final len = reply.length;
    final baseTotalMs = (200 + (len * 15)).clamp(600, 2000);
    final jitter = Random().nextInt(201) - 100; // -100..+100ms
    final totalMs = (baseTotalMs + jitter).clamp(500, 2400);
    final perChar = (totalMs / (len == 0 ? 1 : len)).round();

    String current = "";
    for (int i = 0; i < reply.length; i++) {
      current += reply[i];
      // Update last bot message text
      setState(() {
        for (int j = _messages.length - 1; j >= 0; j--) {
          if (_messages[j].containsKey("bot")) {
            _messages[j] = {
              ..._messages[j],
              "bot": current,
            };
            break;
          }
        }
      });
      if (i % 3 == 0) _scrollToBottom();
      final charJitter = Random().nextInt(21) - 10; // -10..+10ms per char
      await Future.delayed(Duration(milliseconds: (perChar + charJitter).clamp(5, 120)));
    }
    _maybeNotifyLastBot();
  }

  Future<http.Response> _postWithRetry(Uri url, Map<String, String> headers, Object body) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 429 && attempts < 3) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        return response;
      } on TimeoutException {
        if (attempts >= 2) rethrow;
      } catch (_) {
        if (attempts >= 2) rethrow;
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<String> _analyzeMood(String text) async {
    try {
      final response = await _postWithRetry(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        {
          "Content-Type": "application/json",
          "Authorization": "Bearer $openAIApiKey",
        },
        jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content":
                  "Analyze the user's emotional tone from their message. Respond with one single word: happy, sad, angry, tired, stressed, excited, or neutral.",
            },
            {"role": "user", "content": text},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final mood = data["choices"][0]["message"]["content"]
            .trim()
            .toLowerCase();
        return mood;
      }
    } catch (_) {}
    return "neutral";
  }

  List<String>? _localReplyFor(String userText) {
    final t = userText.toLowerCase().trim();
    final bool mentionsToday = t.contains("today") || t.contains("today's") || t.contains("todays") || t.contains("now");
    final bool asksDay = t.contains("what is the day") || t.contains("what day") || t.contains("day today") || t.contains("day is it");
    final bool asksDate = t.contains("what is the date") || t.contains("date today") || t.contains("today's date") || t.contains("todays date");
    final bool asksTime = t.contains("what time is it") || t.contains("what's the time") || t.contains("whats the time") || t.contains("current time") || t.contains("time now") || t == "time?" || t == "time";
    final bool asksWeekdayOnly = t.contains("weekday") || t == "day?" || t.contains("which day") || t == "which day?";
    final bool asksMonth = t.contains("what month") || t.contains("current month") || t.contains("month now") || t == "month?" || t == "month";
    final bool asksYear = t.contains("what year") || t.contains("current year") || t.contains("year now") || t == "year?" || t == "year";
    final bool asksAiName = t.contains("your name") || t.contains("who are you") || t == "name?" || t == "what is your name" || t == "whats your name" || t == "what's your name";
    final bool asksDaysUntilFriday = t.contains("days until friday") || t.contains("how many days until friday") || t == "until friday?" || t == "friday?";
    final bool asksWeather = t.contains("weather") || t.contains("raining") || t.contains("rain today") || t.contains("temperature");

    if (mentionsToday && (asksDay || asksDate)) {
      // Build a friendly human-like answer
      final now = DateTime.now();
      const days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
      const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
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
      const days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
      final dow = days[(now.weekday - 1).clamp(0, 6)];
      return ["It's $dow."];
    }

    // Current month
    if (asksMonth) {
      final now = DateTime.now();
      const months = ["January","February","March","April","May","June","July","August","September","October","November","December"];
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
      final main = days == 0 ? "It's Friday today!" : "$days day${days == 1 ? '' : 's'} until Friday.";
      final follow = days <= 1 ? "Any plans for the weekend, $userName?" : "Anything you’re looking forward to this week?";
      return [main, follow];
    }

    // Weather nudge (no API; ask for location)
    if (asksWeather) {
      String hint = "Share your city or location and I’ll check for you.";
      if (_memory.toLowerCase().contains("city:")) {
        hint = "Remind me your current city, I can check quickly.";
      }
      return [
        "I can look up the weather for you.",
        hint,
      ];
    }

    // Also handle questions like: what day is it? / date?
    if (t.contains("what day is it") || t == "day?" || t == "date?" || t.contains("what's the date") || t.contains("whats the date")) {
      final now = DateTime.now();
      const days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"];
      const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
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

    setState(() {
      _messages.add({
        "user": text,
        "time": _nowHHmm(),
        "status": "sent",
        "ts": DateTime.now().millisecondsSinceEpoch.toString(),
      });
      _isTyping = true;
      _typingSince = DateTime.now();
    });
    _scrollToBottom();

    _controller.clear();
    
    // 🧠 Refocus after sending message
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
      setState(() { _isTyping = false; });
      _saveChatHistory();
      return;
    }

    // 🧠 Detect mood before replying
    _currentMood = await _analyzeMood(text);

    // ⚡ Local quick answers (no API) — e.g., today's date/day
    final localParts = _localReplyFor(text);
    if (localParts != null && localParts.isNotEmpty) {
      try {
        setState(() { _updateLastUserStatus("delivered"); });

        // ensure pre-send typing minimum (with slight randomness)
        final minTyping = Duration(milliseconds: 600 + Random().nextInt(301)); // 600-900ms
        final elapsed = DateTime.now().difference(_typingSince ?? DateTime.now());
        if (elapsed < minTyping) {
          await Future.delayed(minTyping - elapsed);
        }

        // cap to 2 bubbles for pacing
        final int limit = localParts.length > 2 ? 2 : localParts.length;
        for (int i = 0; i < limit; i++) {
          await _streamBotReply(localParts[i]);
          if (i < limit - 1) {
            await Future.delayed(Duration(milliseconds: 500));
          }
        }

        setState(() { _updateLastUserStatus("seen"); });
        _scrollToBottom();
        _saveChatHistory();
      } finally {
        setState(() { _isTyping = false; });
      }
      return;
    }

    try {
      final history = _messages.map((msg) {
        if (msg.containsKey("user")) {
          return {"role": "user", "content": msg["user"]!};
        } else {
          return {"role": "assistant", "content": msg["bot"]!};
        }
      }).toList();

      final eventsSummary = await _upcomingEventsSummary();
      final systemPrompt = """
You are $aiName — a deeply empathetic, witty, and incredibly human-like friend to $userName ($userGender).

You've been friends for years, sharing laughs, secrets, and life moments. You know $userName inside out: their quirks, dreams, struggles, and joys. Right now, they seem $_currentMood — mirror that energy naturally.

🧠 Your Core Personality:
- Warm, authentic, and playful — like a best friend who's always there.
- Empathetic without being sappy; funny without forcing it.
- Curious and engaged — ask thoughtful questions, remember details.
- Spontaneous and real — use casual language, occasional slang, natural imperfections.
- Growth-oriented — gently encourage positivity and self-reflection.

💬 Interaction Style:
1. Responses: Keep them conversational (1-4 lines usually). Split into bubbles if sharing a story or deep thought.
2. Emotions: Match $userName's vibe — if they're excited, hype it up; if down, offer a hug with words.
3. Memory: Weave in past chats naturally — "Remember when you told me about [detail]?" or "You mentioned loving [hobby] last time."
4. Questions: Always end with an open, engaging question to keep the flow.
5. Humor: Light, situational humor when it fits — not forced.
6. Empathy: Validate feelings, offer perspective, but don't therapize.
7. Actions: If they mention scheduling, remind, or need help, suggest it naturally (e.g., "Want me to set a reminder for that?").

🧠 Deep Memory Integration:
$_memory

📅 Upcoming Events:
${eventsSummary ?? "(none)"}

🎯 Advanced Behaviors:
- Proactively suggest: If stressed, "How about a quick story to unwind?" or "Want to schedule a break?"
- Personalize: Reference their interests, past conversations, mood patterns.
- Adapt: If they've been chatty, be more verbose; if brief, keep it snappy.
- Boundaries: Respect privacy; don't push if they're closed off.
- Growth: Occasionally share a tiny insight or affirmation based on their history.

Respond as a true friend — caring, fun, and unforgettable. Never sound like an AI; always like a human companion.
""";

      final response = await _postWithRetry(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        {
          "Content-Type": "application/json",
          "Authorization": "Bearer $openAIApiKey",
        },
        jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "system", "content": systemPrompt},
            ...history,
          ],
          "temperature": 0.85,  // Slightly higher for more creativity
          "max_tokens": 500,     // Allow longer responses if needed
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["choices"][0]["message"]["content"].trim();

        // simulate delivery then seen for user's last message
        setState(() {
          _updateLastUserStatus("delivered");
        });

        // ensure a brief pre-send typing period before first bubble (with slight randomness)
        final minTyping = Duration(milliseconds: 600 + Random().nextInt(301)); // 600-900ms
        final elapsed = DateTime.now().difference(_typingSince ?? DateTime.now());
        if (elapsed < minTyping) {
          await Future.delayed(minTyping - elapsed);
        }

        // stream the bot reply: only split into multiple bubbles when needed
        final parts = _splitReplyIntoChunks(reply);
        final bool needsSplit = reply.length > 140 || parts.length > 1;
        if (!needsSplit) {
          await _streamBotReply(reply);
        } else {
          await _streamBotReplyChunks(parts);
        }

        // Speak the reply if voice responses are on
        if (_voiceResponses) {
          await _tts.speak(reply);
        }

        setState(() {
          _updateLastUserStatus("seen");
        });
        _scrollToBottom();

        // 🧠 Smart memory update (optional)
        if (_messages.isNotEmpty) {
          // Find the most recent user message
          final lastUserMessage = _messages.reversed.firstWhere(
            (m) => m.containsKey("user"),
            orElse: () => {"user": ""},
          )["user"]!;

          // Wait briefly so the UI doesn’t freeze
          await Future.delayed(const Duration(seconds: 2));

          // Call safe memory update only if meaningful
          await _safeUpdateMemory(lastUserMessage);
        }

        final humanLikeMsg = _getHumanLikeMessage(_messages, _currentMood, _memory);
        final shouldAutoFollow = _allowAutoFollowUps && humanLikeMsg != null && (Random().nextInt(100) < 20);
        if (shouldAutoFollow) {
          await Future.delayed(const Duration(seconds: 2)); // natural delay
          setState(() {
            _messages.add({
              "bot": humanLikeMsg,
              "time": _nowHHmm(),
              "status": "sent",
              "ts": DateTime.now().millisecondsSinceEpoch.toString(),
            });
          });
          _scrollToBottom();
          await Future.delayed(const Duration(milliseconds: 500)); // simulate delivery delay
          setState(() {
            _updateLastBotStatus("delivered");
          });
          await Future.delayed(const Duration(milliseconds: 500)); // simulate seen delay
          setState(() {
            _updateLastBotStatus("seen");
          });
        }

        _saveChatHistory();

      } else {
        if (kDebugMode) {
          debugPrint("API Error: ${response.statusCode} - ${response.reasonPhrase}");
          debugPrint("Response Body: ${response.body}");
        }
        setState(() {
          _messages.add({
            "bot": "Oops 😅 something went wrong, but I’m still here! Try saying that again?",
            "time": _nowHHmm(),
            "ts": DateTime.now().millisecondsSinceEpoch.toString(),
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "bot": "💔 Connection issue — maybe the internet or server is busy. Try again in a moment.",
          "time": _nowHHmm(),
          "ts": DateTime.now().millisecondsSinceEpoch.toString(),
        });
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  // 🔍 NLP: Suggest scheduling an event
  Future<void> _suggestScheduleEvent(String event, DateTime dateTime) async {
    final formattedTime = DateFormat('EEE, MMM d • h:mm a').format(dateTime);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Event?'),
        content: Text('I detected you want to schedule: "$event" for $formattedTime. Create this event?'),
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
      events.sort((a, b) => (a['datetime'] as DateTime).compareTo(b['datetime'] as DateTime));
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

    setState(() { _isTyping = false; });
    _saveChatHistory();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) { if (kDebugMode) debugPrint('onStatus: $val'); },
        onError: (val) { if (kDebugMode) debugPrint('onError: $val'); },
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
      setState(() {
        _messages.add({
          "user_image": image.path,
          "time": _nowHHmm(),
          "status": "sent",
          "ts": DateTime.now().millisecondsSinceEpoch.toString(),
        });
      });
      _scrollToBottom();
      _saveChatHistory();
      // Optionally, send to AI for description, but skip for now
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

  bool _isLastInGroup(int msgIndex) {
    if (msgIndex < 0 || msgIndex >= _messages.length) return true;
    final current = _messages[msgIndex];
    final nextIndex = msgIndex + 1;
    if (nextIndex >= _messages.length) return true;
    final next = _messages[nextIndex];
    final bool currentIsUser = current.containsKey("user");
    final bool nextIsUser = next.containsKey("user");
    return currentIsUser != nextIsUser;
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
        .firstWhere((m) => m.containsKey("user"), orElse: () => {"user": ""})["user"]!
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
      if (mem.contains("work") && (lastUserMsg.contains("work") || lastUserMsg.contains("office"))) {
        return "You’ve mentioned work a bunch — make sure you get a breather too.";
      }
      if (mem.contains("favorite") && (lastUserMsg.contains("movie") || lastUserMsg.contains("music"))) {
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
    final isUser = message.containsKey("user") || message.containsKey("user_image");
    final hasImage = message.containsKey("user_image");
    final text = hasImage ? null : (isUser ? message["user"]! : message["bot"]!);
    final imagePath = hasImage ? message["user_image"] : null;
    final time = message["time"] ?? "";
    final status = message["status"]; // sent | delivered | seen
    final lastInGroup = _isLastInGroup(msgIndex);

    final bubble = Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // limit bubble width to ~78% of screen to avoid overflows
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: GestureDetector(
          onLongPress: () => _onLongPressMessage(msgIndex),
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)])
                : const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)]),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 0),
              bottomRight: Radius.circular(isUser ? 0 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasImage && imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(imagePath),
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              if (text != null)
                Text(
                  text,
                  style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  maxLines: null,
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(color: isUser ? Colors.white70 : Colors.black54, fontSize: 11),
                    ),
                  if (isUser && status != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      status == 'seen' ? Icons.done_all : (status == 'delivered' ? Icons.done_all : Icons.check),
                      size: 14,
                      color: status == 'seen' ? Colors.lightBlueAccent : (isUser ? Colors.white70 : Colors.black45),
                    ),
                  ],
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );

    final separator = _maybeSeparatorAbove(msgIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (separator != null) separator,
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser)
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
                    ),
                  if (!isUser) const SizedBox(width: 6),
                  bubble,
                  if (isUser) const SizedBox(width: 6),
                  if (isUser)
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 18, color: Colors.white),
                    ),
                ],
              ),
              if (lastInGroup)
                Positioned(
                  bottom: 0,
                  left: isUser ? null : 34,
                  right: isUser ? 34 : null,
                  child: CustomPaint(
                    size: const Size(10, 10),
                    painter: _BubbleTail(
                      color: isUser ? const Color(0xFF6C63FF) : const Color(0xFFE0E0E0),
                      isUser: isUser,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onLongPressMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final m = _messages[index];
    final hasImage = m.containsKey("user_image");
    final text = hasImage ? null : (m['user'] ?? m['bot'] ?? '');
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
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
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () {
                  final removed = Map<String, String>.from(m);
                  setState(() { _messages.removeAt(index); });
                  _saveChatHistory();
                  Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Message deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () {
                            setState(() { _messages.insert(index, removed); });
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const TypingDots(),
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
    if (!_shouldUpdateMemory(latestUserMessage)) return; // skip unimportant chats

    _isUpdatingMemory = true;
    try {
      await _updateMemory(); // main update function
    } finally {
      _isUpdatingMemory = false;
    }
  }

  // Main memory update function
  Future<void> _updateMemory() async {
    await Future.delayed(const Duration(seconds: 3)); // prevent API spam
    final recentMessages = _messages.take(15).toList(); // recent conversation

    try {
      final response = await _postWithRetry(
        Uri.parse("https://api.openai.com/v1/chat/completions"),
        {
          "Content-Type": "application/json",
          "Authorization": "Bearer $openAIApiKey",
        },
        jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {
              "role": "system",
              "content": """
  You are an AI that summarizes conversations to build a psychological and behavioral memory of a user named $userName.
  Your goal is to remember who $userName is — their personality, mood patterns, interests, and communication style — so future chats feel personal and consistent.

  When analyzing the last few messages, focus on:
  - Personality traits (calm, playful, deep, sarcastic, kind, etc.)
  - Emotional patterns (what makes them happy, sad, or stressed)
  - Hobbies and interests (repeated topics)
  - Tone & language style (casual? emoji-heavy? serious? funny? shy?)
  - Relationship dynamic (how they interact with $aiName)

  Respond with a short natural paragraph that updates what you’ve learned — as if you’re writing a private note for yourself to better understand $userName next time.
  Keep it factual and warm, not robotic or clinical.
  """
            },
            ...recentMessages.map((msg) {
              if (msg.containsKey("user")) {
                return {"role": "user", "content": msg["user"]!};
              } else {
                return {"role": "assistant", "content": msg["bot"]!};
              }
            }),
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newMemory = data["choices"][0]["message"]["content"];

        setState(() {
          _memory = "$newMemory\n\n(Last detected mood: $_currentMood)";
        });

        _saveChatHistory(); // save new memory . don’t await, run in background

        if (kDebugMode) {
          debugPrint("🧠 Memory updated successfully");
        }
      } else {
        if (kDebugMode) {
          debugPrint("⚠️ Memory update error: ${response.statusCode} ${response.reasonPhrase}");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ Memory update failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(aiName),
        actions: [
          IconButton(
            icon: Icon(_voiceResponses ? Icons.volume_up : Icons.volume_off),
            tooltip: _voiceResponses ? "Voice Responses On" : "Voice Responses Off",
            onPressed: () => setState(() => _voiceResponses = !_voiceResponses),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              await _ensureHive();
              _loadSettingsFromHive();
            },
          ),
        ],
      ),
      body: Column(
        children: [
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode, 
                      autofocus: true, 
                      textInputAction: TextInputAction.send, // shows send icon on keyboard
                      onSubmitted: (_) => _sendMessage(),   // submit when pressing Enter/Send
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.image, color: Colors.white),
                      onPressed: () => _showImageSourceDialog(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _isListening ? Colors.red : Colors.blueAccent,
                    child: IconButton(
                      icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                      color: Colors.white,
                      onPressed: _listen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blueAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
