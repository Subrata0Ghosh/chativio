import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/services/subscription_service.dart';
import 'package:myapp/screens/premium_screen.dart';

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

  @override
  void initState() {
    super.initState();
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
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sub = SubscriptionService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(onPressed: _resetDefaults, child: const Text('RESET')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pro Membership Banner
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
              if (mounted) setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sub.isPro
                      ? [const Color(0xFF10B981), const Color(0xFF047857)]
                      : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    sub.isPro ? Icons.workspace_premium : Icons.stars,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          sub.isPro
                              ? "Unlimited messages & all features unlocked"
                              : "${sub.remainingFreeMessages} free messages left today",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white70,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

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
}
