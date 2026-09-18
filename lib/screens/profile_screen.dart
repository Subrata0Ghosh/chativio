import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/nlp_service.dart';
import '../services/subscription_service.dart';
import '../services/persona_service.dart';
import '../providers/theme_provider.dart';
import 'mood_journal_screen.dart';
import 'premium_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _userName = "User";
  String _aiName = "Chativio";
  String _lastMood = "neutral";
  Box? _chatBox;
  bool _notificationsEnabled = true;
  bool _memoryConsent = true;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initHiveAndLoadSettings();
    _initMemoryConsent();
  }

  Future<void> _initMemoryConsent() async {
    await NlpService().init();
    setState(() {
      _memoryConsent = NlpService().memoryConsent;
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName =
          prefs.getString("userName") ?? prefs.getString("user_name") ?? "User";
      _aiName =
          prefs.getString("aiName") ?? prefs.getString("ai_name") ?? "Chativio";
      _lastMood = prefs.getString("last_mood") ?? "neutral";
      _profileImagePath = prefs.getString("profile_image_path");
    });
  }

  Future<void> _clearAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await _chatBox?.clear();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("All app data cleared successfully!"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _initHiveAndLoadSettings() async {
    try {
      if (!Hive.isBoxOpen('chat')) {
        try {
          await Hive.initFlutter();
        } catch (_) {}
        _chatBox = await Hive.openBox('chat');
      } else {
        _chatBox = Hive.box('chat');
      }
      setState(() {
        _notificationsEnabled =
            (_chatBox?.get('settings_notificationsEnabled', defaultValue: true)
                as bool?) ??
            true;
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("profile_image_path", pickedFile.path);
      setState(() {
        _profileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _exportChatHistory() async {
    try {
      if (_chatBox == null || !_chatBox!.isOpen) {
        if (!Hive.isBoxOpen('chat')) {
          _chatBox = await Hive.openBox('chat');
        } else {
          _chatBox = Hive.box('chat');
        }
      }

      final dynamic raw =
          _chatBox?.get('chatHistory_$_userName') ?? _chatBox?.get('messages');
      List messages = [];
      if (raw is List) {
        messages = raw;
      }

      if (messages.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No chat history to export yet.")),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln(
        "Chativio Chat History - Exported on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
      );
      buffer.writeln("User: $_userName | Companion: $_aiName");
      buffer.writeln("=" * 50);
      buffer.writeln();

      for (final rawMsg in messages) {
        final msg = Map<String, dynamic>.from(rawMsg as Map);
        final time = msg['time'] ?? '';
        final text = msg.containsKey('user')
            ? '$_userName: ${msg['user']}'
            : '$_aiName: ${msg['bot']}';
        buffer.writeln('[$time] $text');
        buffer.writeln();
      }

      await Share.share(buffer.toString(), subject: 'Chativio Chat History');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to export chat history.")),
        );
      }
    }
  }

  void _showPersonaDialog() {
    final current = PersonaService.instance.currentPersona;
    final isPro = SubscriptionService.instance.isPro;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select AI Persona"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: PersonaService.availablePersonas.map((p) {
              final isSelected = p.id == current.id;
              final isLocked = p.isProOnly && !isPro;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: p.themeColor.withValues(alpha: 0.2),
                  child: Icon(p.icon, color: p.themeColor),
                ),
                title: Row(
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock, size: 14, color: Colors.amber),
                    ],
                  ],
                ),
                subtitle: Text(
                  p.subtitle,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (isLocked) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  } else {
                    setState(() {
                      PersonaService.instance.setPersona(p.id);
                    });
                  }
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = SubscriptionService.instance;
    final currentPersona = PersonaService.instance.currentPersona;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: 10,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blueAccent.withValues(alpha: .2),
                      backgroundImage: _profileImagePath != null
                          ? FileImage(File(_profileImagePath!))
                          : null,
                      child: _profileImagePath == null
                          ? const Icon(
                              Icons.person,
                              size: 55,
                              color: Colors.blue,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF667EEA),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Mood: $_lastMood",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Chativio Pro Subscription Card
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
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (sub.isPro ? Colors.green : Colors.purple)
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sub.isPro ? Icons.workspace_premium : Icons.stars,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.isPro
                                  ? "Chativio Pro Active 👑"
                                  : "Upgrade to Chativio Pro",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub.isPro
                                  ? "All premium personas & unlimited chats enabled"
                                  : "Unlimited chats, voice calls & vision AI",
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

              const SizedBox(height: 16),

              // AI Persona Selector Tile
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: currentPersona.themeColor.withValues(
                    alpha: 0.2,
                  ),
                  child: Icon(
                    currentPersona.icon,
                    color: currentPersona.themeColor,
                  ),
                ),
                title: const Text("Companion Persona"),
                subtitle: Text(
                  "${currentPersona.name} • ${currentPersona.subtitle}",
                ),
                trailing: const Icon(Icons.swap_horiz),
                onTap: _showPersonaDialog,
              ),

              // Notifications
              ListTile(
                leading: const Icon(
                  Icons.notifications_active,
                  color: Colors.deepPurple,
                ),
                title: const Text("Notifications"),
                subtitle: Text(_notificationsEnabled ? "Enabled" : "Disabled"),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    try {
                      await _chatBox?.put('settings_notificationsEnabled', v);
                    } catch (_) {}
                  },
                ),
              ),

              // Memory Consent
              ListTile(
                leading: const Icon(Icons.memory, color: Colors.orange),
                title: const Text("Memory Consent"),
                subtitle: const Text("Allow AI to remember personal details"),
                trailing: Switch(
                  value: _memoryConsent,
                  onChanged: (v) async {
                    setState(() => _memoryConsent = v);
                    await NlpService().setMemoryConsent(v);
                  },
                ),
              ),

              // Theme Mode
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(
                      Icons.brightness_6,
                      color: Colors.amber,
                    ),
                    title: const Text("Theme Mode"),
                    subtitle: Text(
                      _getThemeModeText(themeProvider.themeModeString),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showThemeDialog(context, themeProvider),
                  );
                },
              ),

              // AI Name
              ListTile(
                leading: const Icon(Icons.smart_toy, color: Colors.blue),
                title: const Text("AI Name"),
                subtitle: Text(_aiName),
                trailing: const Icon(Icons.edit),
                onTap: () => _editAiNameDialog(),
              ),

              // Change Username
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.green),
                title: const Text("Change Username"),
                subtitle: Text(_userName),
                trailing: const Icon(Icons.edit),
                onTap: () => _editUserNameDialog(),
              ),

              // Mood Journal
              ListTile(
                leading: const Icon(Icons.book, color: Colors.purple),
                title: const Text("Mood Journal"),
                subtitle: const Text("Track your daily moods and notes"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MoodJournalScreen()),
                ),
              ),

              // Export Chat History
              ListTile(
                leading: const Icon(Icons.download, color: Colors.teal),
                title: const Text("Export Chat History"),
                subtitle: const Text("Save or share your chat conversations"),
                onTap: _exportChatHistory,
              ),

              const Divider(height: 30),

              // Clear App Data
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Clear App Data"),
                subtitle: const Text(
                  "Erase chat history, memory, and preferences",
                ),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Confirm Clear"),
                      content: const Text(
                        "Are you sure you want to clear all app data? This will delete all chat history and settings.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          child: const Text("Clear"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _clearAppData();
                    setState(() {
                      _userName = "User";
                      _aiName = "Chativio";
                      _lastMood = "neutral";
                      _profileImagePath = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeModeText(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      default:
        return 'System';
    }
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) {
        String selected = themeProvider.themeModeString;
        return AlertDialog(
          title: const Text('Choose Theme Mode'),
          content: StatefulBuilder(
            builder: (context, setState) => SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', icon: Icon(Icons.light_mode)),
                ButtonSegment(value: 'dark', icon: Icon(Icons.dark_mode)),
                ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.brightness_auto),
                ),
              ],
              selected: {selected},
              onSelectionChanged: (Set<String> selection) {
                setState(() => selected = selection.first);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await themeProvider.setThemeMode(selected);
                if (!context.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editUserNameDialog() async {
    final controller = TextEditingController(text: _userName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Your Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Enter new name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("userName", newName);
              await prefs.setString("user_name", newName);
              setState(() => _userName = newName);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _editAiNameDialog() async {
    final controller = TextEditingController(text: _aiName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change AI Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Enter new AI name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("aiName", newName);
              await prefs.setString("ai_name", newName);
              setState(() => _aiName = newName);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
