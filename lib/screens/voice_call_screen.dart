import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';
import '../services/persona_service.dart';

class VoiceCallScreen extends StatefulWidget {
  final String userName;
  final String userGender;
  final String aiName;
  final String currentMood;
  final String? memory;

  const VoiceCallScreen({
    super.key,
    required this.userName,
    required this.userGender,
    required this.aiName,
    required this.currentMood,
    this.memory,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isSpeechAvailable = false;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool _isMuted = false;

  String _userTranscript = "";
  String _aiTranscript = "";
  int _callDurationSeconds = 0;
  Timer? _callTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<Map<String, String>> _callHistory = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startCallTimer();
    _initVoice();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  Future<void> _initVoice() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isListening && mounted) {
              setState(() => _isListening = false);
              if (_userTranscript.trim().isNotEmpty) {
                _processUserSpeech(_userTranscript.trim());
              }
            }
          }
        },
        onError: (error) {
          if (kDebugMode) debugPrint("Speech error: $error");
          if (mounted) setState(() => _isListening = false);
        },
      );

      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          // Wait a moment then listen for user response
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isMuted) {
              _startListening();
            }
          });
        }
      });

      // Greet the user first
      _greetUser();
    } catch (e) {
      if (kDebugMode) debugPrint("Voice call init error: $e");
    }
  }

  Future<void> _greetUser() async {
    final persona = PersonaService.instance.currentPersona;
    String greeting;
    if (persona.id == 'wellness') {
      greeting =
          "Hello ${widget.userName}. Take a deep breath. I'm right here with you.";
    } else if (persona.id == 'mentor') {
      greeting = "Hey ${widget.userName}! Ready to tackle what's on your mind?";
    } else {
      greeting =
          "Hey ${widget.userName}! Great to hear your voice. What's going on?";
    }

    setState(() {
      _aiTranscript = greeting;
      _isSpeaking = true;
    });

    _callHistory.add({"bot": greeting});
    await _tts.speak(greeting);
  }

  Future<void> _startListening() async {
    if (!_isSpeechAvailable || _isSpeaking || _isThinking || _isMuted) return;

    setState(() {
      _isListening = true;
      _userTranscript = "";
    });

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _userTranscript = result.recognizedWords;
          });
          if (result.finalResult && _userTranscript.trim().isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
            _processUserSpeech(_userTranscript.trim());
          }
        }
      },
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _processUserSpeech(String userText) async {
    if (userText.isEmpty) return;

    _callHistory.add({"user": userText});

    setState(() {
      _isThinking = true;
      _aiTranscript = "...";
    });

    final basePrompt = PersonaService.instance.buildSystemPrompt(
      userName: widget.userName,
      userGender: widget.userGender,
      aiName: widget.aiName,
      currentMood: widget.currentMood,
      memory: widget.memory,
    );
    final systemPrompt =
        "$basePrompt\n\nIMPORTANT: You are in a LIVE VOICE CALL. Keep replies conversational, brief (1-2 sentences max), natural, and clear for text-to-speech.";

    final reply = await AiService.instance.getChatReply(
      systemPrompt: systemPrompt,
      messages: _callHistory,
    );

    _callHistory.add({"bot": reply});

    if (mounted) {
      setState(() {
        _isThinking = false;
        _aiTranscript = reply;
        _isSpeaking = true;
      });

      await _tts.speak(reply);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      _speech.stop();
      _tts.stop();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
    } else {
      _startListening();
    }
  }

  void _endCall() {
    _speech.stop();
    _tts.stop();
    _callTimer?.cancel();
    _pulseController.dispose();
    Navigator.pop(context, _callHistory);
  }

  String _formatCallDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _pulseController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final persona = PersonaService.instance.currentPersona;
    final statusText = _isSpeaking
        ? "Speaking..."
        : (_isThinking
              ? "Thinking..."
              : (_isListening
                    ? "Listening..."
                    : (_isMuted ? "Muted" : "Tap orb to speak")));

    Color orbColor;
    if (_isSpeaking) {
      orbColor = const Color(0xFFF43F5E); // Rose / Pink
    } else if (_isThinking) {
      orbColor = const Color(0xFFF59E0B); // Amber
    } else if (_isListening) {
      orbColor = const Color(0xFF06B6D4); // Cyan
    } else {
      orbColor = persona.themeColor;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            persona.icon,
                            color: persona.themeColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              persona.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatCallDuration(_callDurationSeconds),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                widget.aiName,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                statusText,
                style: GoogleFonts.outfit(
                  color: orbColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              // Animated Glowing Voice Orb
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (!_isSpeaking && !_isThinking) {
                    if (_isListening) {
                      _speech.stop();
                      setState(() => _isListening = false);
                    } else {
                      _startListening();
                    }
                  }
                },
                child: ScaleTransition(
                  scale: (_isListening || _isSpeaking)
                      ? _pulseAnimation
                      : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          orbColor.withValues(alpha: 0.9),
                          orbColor.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.4, 0.7, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: orbColor.withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: orbColor.withValues(alpha: 0.6),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(55),
                          child: Image.asset(
                            "assets/images/onboarding_1.png",
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: orbColor,
                                  child: Icon(
                                    _isListening
                                        ? Icons.mic_rounded
                                        : (_isSpeaking
                                              ? Icons.graphic_eq_rounded
                                              : Icons.smart_toy_rounded),
                                    color: Colors.white,
                                    size: 45,
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Live Transcription Card
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_userTranscript.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.userName,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userTranscript,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: orbColor),
                          const SizedBox(width: 4),
                          Text(
                            widget.aiName,
                            style: TextStyle(color: orbColor, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiTranscript.isNotEmpty
                            ? _aiTranscript
                            : "Listening for you...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bottom Call Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute / Unmute
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _isMuted
                        ? Colors.redAccent
                        : Colors.white12,
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),
                  // End Call
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.red,
                    child: IconButton(
                      icon: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _endCall,
                    ),
                  ),
                  // Push to listen
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _isListening
                        ? Colors.cyan
                        : Colors.white12,
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.hearing : Icons.spatial_audio_off,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_isListening) {
                          _speech.stop();
                          setState(() => _isListening = false);
                        } else {
                          _startListening();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
