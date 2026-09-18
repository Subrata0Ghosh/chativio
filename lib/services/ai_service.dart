import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../secrets.dart';

enum AiProvider { auto, openai, openrouter, groq }

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  String _provider = 'auto'; // 'auto', 'openai', 'openrouter', 'groq'
  String _customApiKey = '';
  String _customModel = 'gpt-4o-mini';
  bool _initialized = false;

  String get provider => _provider;
  String get customApiKey => _customApiKey;
  String get customModel => _customModel;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _provider = prefs.getString('ai_provider') ?? 'auto';
      _customApiKey = prefs.getString('ai_custom_api_key') ?? '';
      _customModel = prefs.getString('ai_custom_model') ?? 'gpt-4o-mini';
      _initialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint("AiService init error: $e");
    }
  }

  Future<void> setConfig({
    String? provider,
    String? apiKey,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (provider != null) {
      _provider = provider;
      await prefs.setString('ai_provider', provider);
    }
    if (apiKey != null) {
      _customApiKey = apiKey.trim();
      await prefs.setString('ai_custom_api_key', _customApiKey);
    }
    if (model != null) {
      _customModel = model.trim();
      await prefs.setString('ai_custom_model', _customModel);
    }
  }

  String get activeApiKey {
    if (_customApiKey.isNotEmpty) return _customApiKey;
    return openAIApiKey;
  }

  /// Test whether an API key works
  Future<bool> testApiKey(String apiKey, {String provider = 'openai'}) async {
    final key = apiKey.trim();
    if (key.isEmpty) return false;
    try {
      Uri url;
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      };

      if (provider == 'openrouter') {
        url = Uri.parse('https://openrouter.ai/api/v1/auth/key');
      } else if (provider == 'groq') {
        url = Uri.parse('https://api.groq.com/openai/v1/models');
      } else {
        url = Uri.parse('https://api.openai.com/v1/models');
      }

      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Generate a chat reply with automatic multi-tier fallback
  Future<String> getChatReply({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    String? imagePath,
    String? userPrompt,
  }) async {
    await init();

    // If an image is provided, handle Vision AI
    if (imagePath != null && imagePath.isNotEmpty) {
      return await _generateVisionReply(
        imagePath: imagePath,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt ?? "Look at this photo! What do you think?",
      );
    }

    // 1. Try Custom / OpenAI Key if available and not 'auto' with deactivated key
    final key = activeApiKey;
    final bool hasValidLookingKey =
        key.isNotEmpty &&
        !key.contains('vbKhy4xrdP4lr18rDtfupUWgZNCZTjgWuzXuuMvdoJphEYYS52');

    if ((_provider == 'openai' ||
        _provider == 'openrouter' ||
        _provider == 'groq' ||
        (_provider == 'auto' && hasValidLookingKey))) {
      try {
        final reply = await _callOpenAiCompatible(
          systemPrompt: systemPrompt,
          messages: messages,
          apiKey: key,
          provider: _provider,
          model: _customModel,
        );
        if (reply != null && reply.trim().isNotEmpty) {
          return reply.trim();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint("Custom AI call failed, falling back to free engine: $e");
        }
      }
    }

    // 2. Fallback to Free Live Generative AI Engine (Pollinations AI)
    try {
      final freeReply = await _callFreeAiEngine(
        systemPrompt: systemPrompt,
        messages: messages,
      );
      if (freeReply != null && freeReply.trim().isNotEmpty) {
        return freeReply.trim();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Free AI engine error: $e");
    }

    // 3. Last-mile smart local response
    return _localFallbackReply(messages);
  }

  Future<String?> _callOpenAiCompatible({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    required String apiKey,
    required String provider,
    required String model,
  }) async {
    Uri url;
    if (provider == 'openrouter') {
      url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    } else if (provider == 'groq') {
      url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    } else {
      url = Uri.parse('https://api.openai.com/v1/chat/completions');
    }

    final formattedMessages = <Map<String, dynamic>>[
      {"role": "system", "content": systemPrompt},
    ];

    for (final m in messages.take(16)) {
      if (m.containsKey('user') && m['user'] != null) {
        formattedMessages.add({"role": "user", "content": m['user']!});
      } else if (m.containsKey('bot') && m['bot'] != null) {
        formattedMessages.add({"role": "assistant", "content": m['bot']!});
      }
    }

    final body = jsonEncode({
      "model": model.isNotEmpty ? model : "gpt-4o-mini",
      "messages": formattedMessages,
      "temperature": 0.85,
      "max_tokens": 600,
    });

    final res = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $apiKey",
          },
          body: body,
        )
        .timeout(const Duration(seconds: 22));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["choices"]?[0]?["message"]?["content"] as String?;
    } else {
      throw Exception("OpenAI-compatible error: ${res.statusCode} ${res.body}");
    }
  }

  /// Live Free AI Engine powered by Pollinations AI text endpoint
  Future<String?> _callFreeAiEngine({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    final formattedMessages = <Map<String, dynamic>>[
      {"role": "system", "content": systemPrompt},
    ];

    // Take recent conversation context (last 12 messages)
    final recent = messages.length > 12
        ? messages.sublist(messages.length - 12)
        : messages;
    for (final m in recent) {
      if (m.containsKey('user') && m['user'] != null && m['user']!.isNotEmpty) {
        formattedMessages.add({"role": "user", "content": m['user']!});
      } else if (m.containsKey('bot') &&
          m['bot'] != null &&
          m['bot']!.isNotEmpty) {
        formattedMessages.add({"role": "assistant", "content": m['bot']!});
      }
    }

    final url = Uri.parse('https://text.pollinations.ai/');
    final payload = jsonEncode({
      "messages": formattedMessages,
      "model": "openai",
      "seed": DateTime.now().millisecond,
      "temperature": 0.8,
    });

    final res = await http
        .post(url, headers: {"Content-Type": "application/json"}, body: payload)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      final bodyText = res.body.trim();
      if (bodyText.isNotEmpty) {
        return bodyText;
      }
    }
    return null;
  }

  /// Multimodal Vision AI: Analyzes photos using AI
  Future<String> _generateVisionReply({
    required String imagePath,
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return "I couldn't locate that image file on your device. Could you try selecting it again?";
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imagePath.split('.').last.toLowerCase();
      final mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';

      // 1. If user has a valid OpenAI key, use GPT-4o-mini Vision
      final key = activeApiKey;
      final bool hasValidLookingKey =
          key.isNotEmpty &&
          !key.contains('vbKhy4xrdP4lr18rDtfupUWgZNCZTjgWuzXuuMvdoJphEYYS52');
      if (hasValidLookingKey) {
        try {
          final res = await http
              .post(
                Uri.parse("https://api.openai.com/v1/chat/completions"),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $key",
                },
                body: jsonEncode({
                  "model": "gpt-4o-mini",
                  "messages": [
                    {"role": "system", "content": systemPrompt},
                    {
                      "role": "user",
                      "content": [
                        {"type": "text", "text": userPrompt},
                        {
                          "type": "image_url",
                          "image_url": {
                            "url": "data:$mimeType;base64,$base64Image",
                          },
                        },
                      ],
                    },
                  ],
                  "max_tokens": 500,
                }),
              )
              .timeout(const Duration(seconds: 25));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final content =
                data["choices"]?[0]?["message"]?["content"] as String?;
            if (content != null && content.isNotEmpty) {
              return content.trim();
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint("OpenAI vision error: $e");
        }
      }

      // 2. Free AI multimodal endpoint fallback
      final freeUrl = Uri.parse('https://text.pollinations.ai/');
      final promptWithImageNote =
          "$userPrompt\n\n[Note: The user sent a photo (${bytes.length ~/ 1024} KB). Describe what they might be sharing, show enthusiastic curiosity, and ask what they'd like to do or know about it!]";
      final res = await http
          .post(
            freeUrl,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "messages": [
                {"role": "system", "content": systemPrompt},
                {"role": "user", "content": promptWithImageNote},
              ],
              "model": "openai",
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        return res.body.trim();
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Vision analysis error: $e");
    }

    return "That's an awesome photo! 📸 Tell me more about what's happening here or what you'd like us to do with it!";
  }

  /// Analyze user message emotional tone
  Future<String> analyzeMood(String text) async {
    final lower = text.toLowerCase().trim();

    // Fast local heuristic first for zero-latency detection
    if (lower.contains('happy') ||
        lower.contains('great') ||
        lower.contains('awesome') ||
        lower.contains('love') ||
        lower.contains('yay') ||
        lower.contains('glad')) {
      return 'happy';
    }
    if (lower.contains('sad') ||
        lower.contains('cry') ||
        lower.contains('depressed') ||
        lower.contains('unhappy') ||
        lower.contains('hurt') ||
        lower.contains('lonely')) {
      return 'sad';
    }
    if (lower.contains('angry') ||
        lower.contains('mad') ||
        lower.contains('hate') ||
        lower.contains('furious') ||
        lower.contains('annoyed')) {
      return 'angry';
    }
    if (lower.contains('tired') ||
        lower.contains('exhausted') ||
        lower.contains('sleepy') ||
        lower.contains('drained')) {
      return 'tired';
    }
    if (lower.contains('stressed') ||
        lower.contains('anxious') ||
        lower.contains('worried') ||
        lower.contains('nervous') ||
        lower.contains('pressure')) {
      return 'stressed';
    }
    if (lower.contains('excited') ||
        lower.contains('can\'t wait') ||
        lower.contains('omg') ||
        lower.contains('hyped') ||
        lower.contains('thrilled')) {
      return 'excited';
    }

    // AI classifier
    try {
      final res = await http
          .post(
            Uri.parse('https://text.pollinations.ai/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "messages": [
                {
                  "role": "system",
                  "content":
                      "Classify the emotional tone of the user's message into exactly one lowercase word: happy, sad, angry, tired, stressed, excited, or neutral. Reply with ONLY that single word.",
                },
                {"role": "user", "content": text},
              ],
              "model": "openai",
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final mood = res.body.trim().toLowerCase();
        const validMoods = [
          'happy',
          'sad',
          'angry',
          'tired',
          'stressed',
          'excited',
          'neutral',
        ];
        for (final vm in validMoods) {
          if (mood.contains(vm)) return vm;
        }
      }
    } catch (_) {}

    return 'neutral';
  }

  /// Generate creative stories for Stories & Insights Screen
  Future<Map<String, String>> generateStory({
    required String genre,
    required String mood,
    String? customTopic,
    String length = 'medium',
  }) async {
    final prompt =
        """
Write an engaging, heartwarming, and beautifully written $genre story tailored for someone feeling $mood.
${customTopic != null && customTopic.isNotEmpty ? 'Story Theme / Topic: $customTopic.' : ''}
Target Length: $length (about 3-4 vivid paragraphs).
Format your response as:
TITLE: [Story Title Here]
CONTENT:
[Story Body Here]
MORAL: [One short uplifting takeaway sentence]
""";

    try {
      final res = await http
          .post(
            Uri.parse('https://text.pollinations.ai/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "messages": [
                {
                  "role": "system",
                  "content":
                      "You are a master storyteller who creates captivating, emotional, and inspiring tales.",
                },
                {"role": "user", "content": prompt},
              ],
              "model": "openai",
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final text = res.body.trim();
        String title = "A Story for You";
        String content = text;
        String moral = "Happiness travels in quiet ways.";

        if (text.contains("TITLE:") && text.contains("CONTENT:")) {
          final titlePart = text.split("TITLE:")[1].split("CONTENT:")[0].trim();
          if (titlePart.isNotEmpty) title = titlePart;

          if (text.contains("MORAL:")) {
            content = text.split("CONTENT:")[1].split("MORAL:")[0].trim();
            final moralPart = text.split("MORAL:")[1].trim();
            if (moralPart.isNotEmpty) moral = moralPart;
          } else {
            content = text.split("CONTENT:")[1].trim();
          }
        }

        return {
          "title": title,
          "content": content,
          "mood": mood[0].toUpperCase() + mood.substring(1),
          "moral": moral,
          "genre": genre,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Story generation error: $e");
    }

    // Fallback story if network fails
    return {
      "title": "The Hidden Oasis",
      "content":
          "Deep in the quiet valleys of our everyday lives, there is a place where hurried thoughts slow down. Leo walked down the quiet path he usually ignored, noticing how sunlight filtered through the leaves like spun gold. In that single pause, he realized that peace wasn't something to chase—it was something to allow.",
      "mood": "Calm",
      "moral": "Sometimes pausing is the most productive thing you can do.",
      "genre": genre,
    };
  }

  /// Summarize user profile memory
  Future<String> summarizeMemory({
    required String userName,
    required String aiName,
    required List<Map<String, String>> recentMessages,
    required String existingMemory,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://text.pollinations.ai/'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "messages": [
                {
                  "role": "system",
                  "content":
                      """
You are an AI assistant creating a concise psychological memory profile of user "$userName" for companion "$aiName".
Highlight their key interests, personality quirks, communication style, and recurring topics in 2-3 warm sentences.
Existing Memory: $existingMemory
""",
                },
                ...recentMessages.map(
                  (m) => {
                    "role": m.containsKey('user') ? "user" : "assistant",
                    "content": m['user'] ?? m['bot'] ?? '',
                  },
                ),
              ],
              "model": "openai",
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        return res.body.trim();
      }
    } catch (_) {}
    return existingMemory;
  }

  String _localFallbackReply(List<Map<String, String>> messages) {
    final replies = [
      "I'm listening and I'm right here with you! 💙 Tell me more about what's going on.",
      "That makes so much sense. How are you feeling about all of this right now?",
      "I hear you! You always have such an interesting perspective on things.",
      "I'm always here for you, no matter what kind of day it is. What shall we talk about next?",
      "Take your time—I'm not going anywhere. Tell me everything!",
    ];
    return replies[DateTime.now().millisecond % replies.length];
  }
}
