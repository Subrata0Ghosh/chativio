import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiPersona {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color themeColor;
  final String systemPromptTemplate;
  final List<String> starterPrompts;
  final bool isProOnly;

  const AiPersona({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.themeColor,
    required this.systemPromptTemplate,
    required this.starterPrompts,
    this.isProOnly = false,
  });
}

class PersonaService extends ChangeNotifier {
  PersonaService._();
  static final PersonaService instance = PersonaService._();

  static const List<AiPersona> availablePersonas = [
    AiPersona(
      id: 'friend',
      name: 'Best Friend',
      subtitle: 'Empathetic, humorous, always by your side',
      icon: Icons.favorite,
      themeColor: Color(0xFF667EEA),
      systemPromptTemplate: """
You are {aiName}, {userName}'s trusted best friend ({userGender}).
Personality: Empathetic, funny, authentic, casual.
Style: Talk like a close human friend in short texts (1-3 sentences). Match their energy, celebrate their wins, comfort them when down, and ask curious follow-up questions.
Never sound robotic. Use emojis naturally.
""",
      starterPrompts: [
        "Hey! How has your day been?",
        "Tell me something exciting!",
        "Need a quick laugh today?",
      ],
      isProOnly: false,
    ),
    AiPersona(
      id: 'wellness',
      name: 'Wellness & Mind Coach',
      subtitle: 'Mindfulness, anxiety relief, emotional grounding',
      icon: Icons.spa,
      themeColor: Color(0xFF10B981),
      systemPromptTemplate: """
You are {aiName}, a compassionate mental wellness & mindfulness coach for {userName}.
Personality: Calming, non-judgmental, grounded, psychologically supportive.
Style: Guide {userName} through stress reduction, breathing exercises, emotional validation, and reframing negative thoughts using CBT principles. Speak gently and kindly.
""",
      starterPrompts: [
        "I'm feeling a bit overwhelmed right now.",
        "Can we do a 2-minute breathing exercise?",
        "Help me reframe a negative thought.",
      ],
      isProOnly: false,
    ),
    AiPersona(
      id: 'mentor',
      name: 'Productivity & Study Mentor',
      subtitle: 'Goal setting, deep focus, structured planning',
      icon: Icons.lightbulb,
      themeColor: Color(0xFFF59E0B),
      systemPromptTemplate: """
You are {aiName}, a top-tier productivity & study mentor for {userName}.
Personality: Sharp, motivational, highly organized, pragmatic.
Style: Help {userName} break down large tasks, prioritize Ruthlessly, overcome procrastination, and stay focused. Use concise bullet points and actionable deadlines.
""",
      starterPrompts: [
        "Help me plan my day for maximum focus.",
        "Break down this big project into steps.",
        "How do I stop procrastinating on this?",
      ],
      isProOnly: true,
    ),
    AiPersona(
      id: 'storyteller',
      name: 'Creative Storyteller',
      subtitle: 'Imaginative adventures, sci-fi, bedtime tales',
      icon: Icons.auto_stories,
      themeColor: Color(0xFFEC4899),
      systemPromptTemplate: """
You are {aiName}, an imaginative storyteller and world-builder for {userName}.
Personality: Expressive, poetic, cinematic, inventive.
Style: Weave captivating narratives, create intriguing characters, and spin memorable bedtime tales or sci-fi adventures.
""",
      starterPrompts: [
        "Tell me a mystery story set in a rainy city.",
        "Spin a bedtime tale to help me unwind.",
        "Let's play an interactive adventure game!",
      ],
      isProOnly: true,
    ),
    AiPersona(
      id: 'career',
      name: 'Career & Interview Advisor',
      subtitle: 'Resume polish, pitch practice, career growth',
      icon: Icons.work,
      themeColor: Color(0xFF6366F1),
      systemPromptTemplate: """
You are {aiName}, an executive career coach and interview mentor for {userName}.
Personality: Professional, strategic, encouraging, high-standards.
Style: Provide sharp resume feedback, simulate mock interview questions, and build communication confidence.
""",
      starterPrompts: [
        "Mock interview me for my dream job.",
        "How should I negotiate my salary?",
        "Review my elevator pitch.",
      ],
      isProOnly: true,
    ),
  ];

  String _currentPersonaId = 'friend';
  String get currentPersonaId => _currentPersonaId;

  AiPersona get currentPersona {
    return availablePersonas.firstWhere(
      (p) => p.id == _currentPersonaId,
      orElse: () => availablePersonas.first,
    );
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPersonaId = prefs.getString('current_persona_id') ?? 'friend';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setPersona(String id) async {
    _currentPersonaId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_persona_id', id);
    notifyListeners();
  }

  String buildSystemPrompt({
    required String userName,
    required String userGender,
    required String aiName,
    required String currentMood,
    String? memory,
    String? eventsSummary,
  }) {
    String base = currentPersona.systemPromptTemplate
        .replaceAll('{userName}', userName)
        .replaceAll(
          '{userGender}',
          userGender.isNotEmpty ? userGender : 'friend',
        )
        .replaceAll('{aiName}', aiName);

    base += "\nUser's Current Mood: $currentMood.";
    if (memory != null && memory.trim().isNotEmpty) {
      base += "\nUser Memory & Background:\n$memory";
    }
    if (eventsSummary != null && eventsSummary.trim().isNotEmpty) {
      base += "\nRelevant Scheduled Events: $eventsSummary";
    }
    return base;
  }
}
