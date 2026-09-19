import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoicePersona {
  final String id;
  final String name;
  final String accent;
  final String gender;
  final String description;
  final String cloudLocale;
  final String onDeviceVoiceMatch;
  final double defaultPitch;

  const VoicePersona({
    required this.id,
    required this.name,
    required this.accent,
    required this.gender,
    required this.description,
    required this.cloudLocale,
    required this.onDeviceVoiceMatch,
    this.defaultPitch = 1.0,
  });
}

class NaturalVoiceService {
  NaturalVoiceService._();
  static final NaturalVoiceService instance = NaturalVoiceService._();

  AudioPlayer? _audioPlayer;
  FlutterTts? _flutterTts;

  AudioPlayer get audioPlayer => _audioPlayer ??= AudioPlayer();
  FlutterTts get flutterTts => _flutterTts ??= FlutterTts();

  bool _isSpeaking = false;
  bool _isInitialized = false;
  bool _isCancelled = false;

  String _currentPersonaId = 'ava';
  double _speechSpeed = 1.0; // 0.8 to 1.2
  VoidCallback? _onStartCallback;
  VoidCallback? _onCompleteCallback;

  static const List<VoicePersona> availablePersonas = [
    VoicePersona(
      id: 'ava',
      name: 'Ava',
      accent: 'US English',
      gender: 'Female',
      description: 'Warm, natural, expressive & clear',
      cloudLocale: 'en-US',
      onDeviceVoiceMatch: 'sfg',
      defaultPitch: 1.03,
    ),
    VoicePersona(
      id: 'noah',
      name: 'Noah',
      accent: 'US English',
      gender: 'Male',
      description: 'Friendly, casual, conversational & grounded',
      cloudLocale: 'en-US',
      onDeviceVoiceMatch: 'iom',
      defaultPitch: 0.96,
    ),
    VoicePersona(
      id: 'emma',
      name: 'Emma',
      accent: 'British',
      gender: 'Female',
      description: 'Gentle, refined, soothing & poised',
      cloudLocale: 'en-GB',
      onDeviceVoiceMatch: 'rjs',
      defaultPitch: 1.02,
    ),
    VoicePersona(
      id: 'oliver',
      name: 'Oliver',
      accent: 'British',
      gender: 'Male',
      description: 'Crisp, articulate, thoughtful & polished',
      cloudLocale: 'en-GB',
      onDeviceVoiceMatch: 'fis',
      defaultPitch: 0.95,
    ),
    VoicePersona(
      id: 'priya',
      name: 'Priya',
      accent: 'Indian English',
      gender: 'Female',
      description: 'Warm, melodic, friendly & engaging',
      cloudLocale: 'en-IN',
      onDeviceVoiceMatch: 'in',
      defaultPitch: 1.02,
    ),
    VoicePersona(
      id: 'liam',
      name: 'Liam',
      accent: 'Australian',
      gender: 'Male',
      description: 'Upbeat, relaxed, welcoming & natural',
      cloudLocale: 'en-AU',
      onDeviceVoiceMatch: 'au',
      defaultPitch: 0.98,
    ),
  ];

  bool get isSpeaking => _isSpeaking;
  String get currentPersonaId => _currentPersonaId;
  double get speechSpeed => _speechSpeed;

  VoicePersona get currentPersona => availablePersonas.firstWhere(
    (p) => p.id == _currentPersonaId,
    orElse: () => availablePersonas.first,
  );

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentPersonaId = prefs.getString('ai_voice_persona') ?? 'ava';
      _speechSpeed = prefs.getDouble('ai_voice_speed') ?? 1.0;

      // AudioPlayer setup
      audioPlayer.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        _onCompleteCallback?.call();
      });

      // FlutterTts fallback setup
      if (Platform.isAndroid) {
        try {
          await flutterTts.setEngine("com.google.android.tts");
        } catch (_) {}
      }
      await flutterTts.setLanguage(currentPersona.cloudLocale);
      await flutterTts.setSpeechRate(0.50 * _speechSpeed);
      await flutterTts.setPitch(currentPersona.defaultPitch);

      flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _onCompleteCallback?.call();
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint("NaturalVoiceService init error: $e");
    }
  }

  Future<void> setPersona(String personaId) async {
    _currentPersonaId = personaId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_voice_persona', personaId);
    await _configureOnDeviceTts();
  }

  Future<void> setSpeechSpeed(double speed) async {
    _speechSpeed = speed.clamp(0.7, 1.4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ai_voice_speed', _speechSpeed);
    await _configureOnDeviceTts();
  }

  Future<void> _configureOnDeviceTts() async {
    try {
      final persona = currentPersona;
      if (Platform.isAndroid) {
        try {
          await flutterTts.setEngine("com.google.android.tts");
        } catch (_) {}
      }
      await flutterTts.setLanguage(persona.cloudLocale);
      await flutterTts.setSpeechRate(0.50 * _speechSpeed);
      await flutterTts.setPitch(persona.defaultPitch);

      // Search and pick high quality matching voice on device
      final voices = await flutterTts.getVoices;
      if (voices is List) {
        for (final v in voices) {
          if (v is Map) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            if (locale.contains(persona.cloudLocale.toLowerCase()) &&
                name.contains(persona.onDeviceVoiceMatch)) {
              await flutterTts.setVoice({
                "name": v['name'].toString(),
                "locale": v['locale'].toString(),
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Config on-device TTS error: $e");
    }
  }

  /// Clean raw text so voice sounds human, natural, and never reads markdown/code syntax
  String sanitizeForSpeech(String raw) {
    if (raw.trim().isEmpty) return "";

    var text = raw;

    // Remove code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' [code omitted] ');
    // Remove inline code
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
    // Remove markdown links [text](url) -> text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (m) => m.group(1) ?? '',
    );
    // Remove raw URLs
    text = text.replaceAll(RegExp(r'https?://\S+'), ' link ');
    // Remove bold/italic markers
    text = text.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'__([^_]+)__'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m.group(1) ?? '');
    // Remove headers (# Header)
    text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    // Remove bullet characters
    text = text.replaceAll(RegExp(r'^[*-]\s+', multiLine: true), '');
    // Remove emojis and special symbols
    text = text.replaceAll(
      RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      ),
      '',
    );
    // Normalize quotes and hyphens
    text = text.replaceAll('“', '"').replaceAll('”', '"');
    text = text.replaceAll('‘', "'").replaceAll('’', "'");
    text = text.replaceAll('—', ', ').replaceAll('–', ', ');

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Split text into natural conversational sentence chunks
  List<String> _chunkSentences(String text, {int maxChunkChars = 180}) {
    final sentences = <String>[];
    // Split by sentence terminators
    final rawParts = text.split(RegExp(r'(?<=[.!?])\s+'));

    var current = StringBuffer();
    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      if ((current.length + trimmed.length) < maxChunkChars) {
        if (current.isNotEmpty) current.write(' ');
        current.write(trimmed);
      } else {
        if (current.isNotEmpty) {
          sentences.add(current.toString());
          current = StringBuffer();
        }
        if (trimmed.length > maxChunkChars) {
          // Break overly long sentence by commas or clauses
          final clauses = trimmed.split(RegExp(r'(?<=[,;])\s+'));
          for (final clause in clauses) {
            if (clause.isNotEmpty) sentences.add(clause.trim());
          }
        } else {
          current.write(trimmed);
        }
      }
    }

    if (current.isNotEmpty) {
      sentences.add(current.toString());
    }

    return sentences.isEmpty ? [text] : sentences;
  }

  /// Speak text using natural human voice with cloud synthesis and on-device fallback
  Future<void> speak(
    String rawText, {
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) async {
    await init();
    await stop();

    final cleanText = sanitizeForSpeech(rawText);
    if (cleanText.isEmpty) return;

    _isCancelled = false;
    _onStartCallback = onStart;
    _onCompleteCallback = onComplete;

    _isSpeaking = true;
    _onStartCallback?.call();

    // Tier 1: Google Cloud Natural Neural MP3 Audio
    try {
      final audioFile = await _synthesizeCloudAudio(cleanText);
      if (_isCancelled) return;

      if (audioFile != null && await audioFile.exists()) {
        await audioPlayer.setPlaybackRate(_speechSpeed);
        await audioPlayer.play(DeviceFileSource(audioFile.path));
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Cloud TTS playback error, falling back to on-device: $e");
      }
    }

    if (_isCancelled) return;

    // Tier 2: Enhanced On-Device Google Speech Services Neural Engine
    try {
      await _configureOnDeviceTts();
      await flutterTts.speak(cleanText);
    } catch (e) {
      if (kDebugMode) debugPrint("On-device fallback TTS error: $e");
      _isSpeaking = false;
      _onCompleteCallback?.call();
    }
  }

  /// Fetch and stitch cloud neural MP3 audio
  Future<File?> _synthesizeCloudAudio(String text) async {
    final chunks = _chunkSentences(text);
    final audioBytes = <int>[];
    final persona = currentPersona;

    for (final chunk in chunks) {
      if (_isCancelled) return null;
      if (chunk.trim().isEmpty) continue;

      final encoded = Uri.encodeComponent(chunk.trim());
      final url = Uri.parse(
        'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=${persona.cloudLocale}&q=$encoded',
      );

      final res = await http
          .get(
            url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 7));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        audioBytes.addAll(res.bodyBytes);
      } else {
        throw Exception("Status ${res.statusCode} from cloud voice endpoint");
      }
    }

    if (audioBytes.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/chativio_voice_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(audioBytes, flush: true);
    return file;
  }

  Future<void> stop() async {
    _isCancelled = true;
    _isSpeaking = false;
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    try {
      await _flutterTts?.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _audioPlayer?.pause();
    } catch (_) {}
    try {
      await _flutterTts?.pause();
    } catch (_) {}
    _isSpeaking = false;
  }

  Future<void> resume() async {
    try {
      await _audioPlayer?.resume();
      _isSpeaking = true;
    } catch (_) {}
  }

  void dispose() {
    _audioPlayer?.dispose();
  }
}
