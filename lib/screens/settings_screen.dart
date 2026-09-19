import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/subscription_service.dart';
import 'package:myapp/services/natural_voice_service.dart';
import 'package:myapp/screens/premium_screen.dart';
import 'package:myapp/providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box box;
  bool autoFollowUps = true;
  bool idleNudges = true;
  double idleMinutes = 7;
  double nudgeProbability = 25; // percent
  bool notificationsEnabled = true;
  bool morningNudge = false;
  bool eveningNudge = true;
  TimeOfDay morningTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay eveningTime = const TimeOfDay(hour: 19, minute: 0);
  double contentMixFunny = 40; // 0..100 funny bias

  // AI settings
  String _aiProvider = 'auto';
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  bool _obscureApiKey = true;
  bool _isTestingApiKey = false;
  String? _apiTestResult;
  bool _apiTestSuccess = false;

  // Natural Voice Settings
  String _selectedVoicePersona = 'ava';
  double _voiceSpeed = 1.0;
  bool _isPlayingVoiceSample = false;

  @override
  void initState() {
    super.initState();
    _selectedVoicePersona = NaturalVoiceService.instance.currentPersonaId;
    _voiceSpeed = NaturalVoiceService.instance.speechSpeed;
    box = Hive.box('chat');
    autoFollowUps =
        box.get('settings_autoFollowUps', defaultValue: autoFollowUps) as bool;
    idleNudges =
        box.get('settings_idleNudges', defaultValue: idleNudges) as bool;
    idleMinutes =
        (box.get('settings_idleMinutes', defaultValue: idleMinutes.toInt())
                as int)
            .toDouble();
    nudgeProbability =
        (box.get(
                  'settings_nudgeProbability',
                  defaultValue: nudgeProbability.toInt(),
                )
                as int)
            .toDouble();
    notificationsEnabled =
        box.get(
              'settings_notificationsEnabled',
              defaultValue: notificationsEnabled,
            )
            as bool;
    morningNudge =
        box.get('settings_morningNudge', defaultValue: morningNudge) as bool;
    eveningNudge =
        box.get('settings_eveningNudge', defaultValue: eveningNudge) as bool;
    final mh =
        box.get('settings_morningHour', defaultValue: morningTime.hour) as int;
    final mm =
        box.get('settings_morningMinute', defaultValue: morningTime.minute)
            as int;
    final eh =
        box.get('settings_eveningHour', defaultValue: eveningTime.hour) as int;
    final em =
        box.get('settings_eveningMinute', defaultValue: eveningTime.minute)
            as int;
    morningTime = TimeOfDay(hour: mh, minute: mm);
    eveningTime = TimeOfDay(hour: eh, minute: em);
    contentMixFunny =
        (box.get(
                  'settings_nudgeContentMixFunny',
                  defaultValue: contentMixFunny.toInt(),
                )
                as int)
            .toDouble();

    _loadAiSettings();
  }

  Future<void> _loadAiSettings() async {
    await AiService.instance.init();
    setState(() {
      _aiProvider = AiService.instance.provider;
      _apiKeyController.text = AiService.instance.customApiKey;
      _modelController.text = AiService.instance.customModel;
    });
  }

  Future<void> _save() async {
    await box.put('settings_autoFollowUps', autoFollowUps);
    await box.put('settings_idleNudges', idleNudges);
    await box.put('settings_idleMinutes', idleMinutes.toInt());
    await box.put('settings_nudgeProbability', nudgeProbability.toInt());
    await box.put('settings_notificationsEnabled', notificationsEnabled);
    await box.put('settings_morningNudge', morningNudge);
    await box.put('settings_eveningNudge', eveningNudge);
    await box.put('settings_morningHour', morningTime.hour);
    await box.put('settings_morningMinute', morningTime.minute);
    await box.put('settings_eveningHour', eveningTime.hour);
    await box.put('settings_eveningMinute', eveningTime.minute);
    await box.put('settings_nudgeContentMixFunny', contentMixFunny.toInt());

    await AiService.instance.setConfig(
      provider: _aiProvider,
      apiKey: _apiKeyController.text,
      model: _modelController.text,
    );
  }

  Future<void> _testApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _apiTestResult = "Key is empty. Auto free AI engine will be used.";
        _apiTestSuccess = true;
      });
      return;
    }

    setState(() {
      _isTestingApiKey = true;
      _apiTestResult = null;
    });

    final success = await AiService.instance.testApiKey(
      key,
      provider: _aiProvider,
    );

    if (!mounted) return;
    setState(() {
      _isTestingApiKey = false;
      _apiTestSuccess = success;
      _apiTestResult = success
          ? "✅ Connection successful! Key is active."
          : "❌ Connection failed. Check key & network.";
    });
  }

  void _resetDefaults() {
    setState(() {
      autoFollowUps = true;
      idleNudges = true;
      idleMinutes = 7;
      nudgeProbability = 25;
      notificationsEnabled = true;
      morningNudge = false;
      eveningNudge = true;
      morningTime = const TimeOfDay(hour: 9, minute: 0);
      eveningTime = const TimeOfDay(hour: 19, minute: 0);
      contentMixFunny = 40;
      _aiProvider = 'auto';
      _apiKeyController.clear();
      _modelController.text = 'gpt-4o-mini';
      _apiTestResult = null;
    });
    _save();
  }

  @override
  void dispose() {
    if (_isPlayingVoiceSample) {
      NaturalVoiceService.instance.stop();
    }
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Widget _buildThemeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primary,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = SubscriptionService.instance;
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
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _resetDefaults();
            },
            child: Text(
              'RESET',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pro Membership Banner
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sub.isPro
                      ? [const Color(0xFF10B981), const Color(0xFF047857)]
                      : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (sub.isPro ? Colors.green : const Color(0xFF6366F1))
                        .withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    sub.isPro
                        ? Icons.workspace_premium_rounded
                        : Icons.stars_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.isPro
                              ? "Chativio Pro: Active 👑"
                              : "Chativio Free Tier",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          sub.isPro
                              ? "Unlimited messages & all features unlocked"
                              : "${sub.remainingFreeMessages} free messages left today",
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Appearance & Dynamic Dark/Light Theme Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.8,
              ),
            ),
            color: isDark ? const Color(0xFF111728) : Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette_outlined, color: primary),
                      const SizedBox(width: 8),
                      Text(
                        "Appearance & Theme",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      final currentMode = themeProvider.themeModeString;
                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172033)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _buildThemeOption(
                              label: "System",
                              icon: Icons.brightness_auto_rounded,
                              selected: currentMode == 'system',
                              onTap: () => themeProvider.setThemeMode('system'),
                              isDark: isDark,
                              primary: primary,
                            ),
                            _buildThemeOption(
                              label: "Light",
                              icon: Icons.light_mode_rounded,
                              selected: currentMode == 'light',
                              onTap: () => themeProvider.setThemeMode('light'),
                              isDark: isDark,
                              primary: primary,
                            ),
                            _buildThemeOption(
                              label: "Dark",
                              icon: Icons.dark_mode_rounded,
                              selected: currentMode == 'dark',
                              onTap: () => themeProvider.setThemeMode('dark'),
                              isDark: isDark,
                              primary: primary,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // AI Natural Voice Card
          _buildVoiceSettingsCard(isDark, primary),
          const SizedBox(height: 16),

          // AI Engine & API Key Configuration
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology, color: Color(0xFF667EEA)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "AI Engine & Custom API Key",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Chativio works 100% free out of the box. You can also bring your own OpenAI / Groq / OpenRouter key for custom models.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _aiProvider,
                    decoration: const InputDecoration(
                      labelText: "AI Provider",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text(
                          "Auto (Smart Free Fallback)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'openai',
                        child: Text(
                          "Custom OpenAI Key",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'openrouter',
                        child: Text(
                          "OpenRouter (DeepSeek/Claude)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'groq',
                        child: Text(
                          "Groq (Ultra-Fast Llama)",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _aiProvider = val);
                        _save();
                      }
                    },
                  ),
                  if (_aiProvider != 'auto') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: "API Key",
                        hintText: "sk-...",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                      ),
                      onChanged: (_) => _save(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: "Model Name",
                        hintText: "gpt-4o-mini",
                      ),
                      onChanged: (_) => _save(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isTestingApiKey ? null : _testApiKey,
                          icon: _isTestingApiKey
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.network_check, size: 18),
                          label: const Text("Test Connection"),
                        ),
                        if (_apiTestResult != null)
                          Text(
                            _apiTestResult!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _apiTestSuccess
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conversation Follow-ups & Nudges
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Conversation Style & Flow",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile(
                    title: const Text('Auto follow-ups after replies'),
                    subtitle: const Text(
                      'AI occasionally continues the conversation',
                    ),
                    value: autoFollowUps,
                    onChanged: (v) {
                      setState(() => autoFollowUps = v);
                      _save();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Proactive idle nudges'),
                    subtitle: const Text(
                      'Friendly ping after you are inactive',
                    ),
                    value: idleNudges,
                    onChanged: (v) {
                      setState(() => idleNudges = v);
                      _save();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notification Settings
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Reminders & Notifications",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile(
                    title: const Text('Allow notifications'),
                    value: notificationsEnabled,
                    onChanged: (v) {
                      setState(() => notificationsEnabled = v);
                      _save();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Morning nudge'),
                    subtitle: Text('Time: ${morningTime.format(context)}'),
                    value: morningNudge,
                    onChanged: (v) {
                      setState(() => morningNudge = v);
                      _save();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Change morning time'),
                    subtitle: Text(morningTime.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: morningTime,
                      );
                      if (picked != null) {
                        setState(() => morningTime = picked);
                        _save();
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Evening nudge'),
                    subtitle: Text('Time: ${eveningTime.format(context)}'),
                    value: eveningNudge,
                    onChanged: (v) {
                      setState(() => eveningNudge = v);
                      _save();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Change evening time'),
                    subtitle: Text(eveningTime.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: eveningTime,
                      );
                      if (picked != null) {
                        setState(() => eveningTime = picked);
                        _save();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tuning Sliders
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content mix (Humorous → Thoughtful): ${contentMixFunny.toInt()}%',
                  ),
                  Slider(
                    value: contentMixFunny,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${contentMixFunny.toInt()}%',
                    onChanged: (v) => setState(() => contentMixFunny = v),
                    onChangeEnd: (_) => _save(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Idle minutes before check-in: ${idleMinutes.toInt()} min',
                  ),
                  Slider(
                    value: idleMinutes,
                    min: 3,
                    max: 30,
                    divisions: 27,
                    label: '${idleMinutes.toInt()}m',
                    onChanged: (v) => setState(() => idleMinutes = v),
                    onChangeEnd: (_) => _save(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Feedback'),
            onTap: _showHelp,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Clear Chat History',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _clearChat,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will delete all messages and learned memory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString("userName") ?? 'User';
      await box.delete("chatHistory_$userName");
      await box.delete("memory_$userName");
      await box.delete("chatHistory_User");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat history cleared.')));
      }
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About Chativio'),
        content: const Text(
          'Chativio is your personal AI companion, built for meaningful conversation, emotional wellness, daily reminders, and creative storytelling.\n\n'
          'Enjoy free chatting, or upgrade to Chativio Pro for unlimited voice calls, vision analysis, and specialized AI personas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSettingsCard(bool isDark, Color primary) {
    final personas = NaturalVoiceService.availablePersonas;
    final currentPersona = personas.firstWhere(
      (p) => p.id == _selectedVoicePersona,
      orElse: () => personas.first,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      color: isDark ? const Color(0xFF111728) : Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.graphic_eq_rounded, color: primary),
                const SizedBox(width: 8),
                Text(
                  "AI Natural Voice",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "100% Free",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Expressive human conversational voices for live voice calls and stories.",
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),

            // Voice selection chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: personas.map((p) {
                final isSelected = p.id == _selectedVoicePersona;
                return GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedVoicePersona = p.id);
                    await NaturalVoiceService.instance.setPersona(p.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
                          : (isDark
                                ? const Color(0xFF172033)
                                : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? primary : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.gender == 'Female'
                              ? Icons.face_3_rounded
                              : Icons.face_rounded,
                          size: 16,
                          color: isSelected
                              ? primary
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          p.name,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? primary
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "(${p.accent.split(' ').first})",
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? primary.withValues(alpha: 0.8)
                                : (isDark ? Colors.white38 : Colors.black38),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Preview voice audio row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF172033)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlayingVoiceSample
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                      color: primary,
                      size: 32,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      if (_isPlayingVoiceSample) {
                        await NaturalVoiceService.instance.stop();
                        if (mounted) {
                          setState(() => _isPlayingVoiceSample = false);
                        }
                      } else {
                        setState(() => _isPlayingVoiceSample = true);
                        await NaturalVoiceService.instance.speak(
                          "Hello! I am ${currentPersona.name}. It is wonderful to chat with you.",
                          onStart: () {
                            if (mounted) {
                              setState(() => _isPlayingVoiceSample = true);
                            }
                          },
                          onComplete: () {
                            if (mounted) {
                              setState(() => _isPlayingVoiceSample = false);
                            }
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${currentPersona.name} • ${currentPersona.gender}",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _isPlayingVoiceSample
                              ? "Speaking live sample..."
                              : currentPersona.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _isPlayingVoiceSample
                                ? primary
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Speed Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Speech Rate",
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  "${_voiceSpeed.toStringAsFixed(1)}x",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: primary,
                thumbColor: primary,
                overlayColor: primary.withValues(alpha: 0.15),
                trackHeight: 4,
              ),
              child: Slider(
                value: _voiceSpeed,
                min: 0.8,
                max: 1.2,
                divisions: 4,
                onChanged: (val) async {
                  HapticFeedback.selectionClick();
                  setState(() => _voiceSpeed = val);
                  await NaturalVoiceService.instance.setSpeechSpeed(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
