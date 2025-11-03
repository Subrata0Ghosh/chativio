import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:myapp/services/nlp_service.dart';
import 'mood_journal_screen.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _memoryConsent = false;

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
      _userName = prefs.getString("user_name") ?? "User";
      _aiName = prefs.getString("ai_name") ?? "Chativio";
      _lastMood = prefs.getString("last_mood") ?? "neutral";
    });
  }

  Future<void> _clearAppData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try { await _chatBox?.clear(); } catch (_) {}
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
        try { await Hive.initFlutter(); } catch (_) {}
        _chatBox = await Hive.openBox('chat');
      } else {
        _chatBox = Hive.box('chat');
      }
      setState(() {
        _notificationsEnabled = (_chatBox?.get('settings_notificationsEnabled', defaultValue: true) as bool?) ?? true;
      });
    } catch (_) {}
  }

  Future<void> _exportChatHistory() async {
    try {
      if (_chatBox == null || !_chatBox!.isOpen) return;
      final messages = _chatBox!.get('messages') as List? ?? [];
      if (messages.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No chat history to export.")),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln("Chativio Chat History - Exported on ${DateTime.now()}");
      buffer.writeln("=" * 50);
      buffer.writeln();

      for (final msg in messages.reversed) {
        final time = msg['time'] ?? '';
        final text = msg.containsKey('user') ? 'You: ${msg['user']}' : 'AI: ${msg['bot']}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile & Settings"),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.05,
          vertical: 20,
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: MediaQuery.of(context).size.width > 600 ? 60 : 45,
              backgroundColor: Colors.blueAccent.withValues(alpha: .2),
              child: Icon(
                Icons.person,
                size: MediaQuery.of(context).size.width > 600 ? 60 : 50,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _userName,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Mood: $_lastMood",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
              ),
            ),
            const SizedBox(height: 30),

            // 🌤 Settings options
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Colors.deepPurple),
              title: const Text("Notifications"),
              subtitle: Text(_notificationsEnabled ? "Enabled" : "Disabled"),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (v) async {
                  setState(() => _notificationsEnabled = v);
                  try { await _chatBox?.put('settings_notificationsEnabled', v); } catch (_) {}
                },
              ),
            ),
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
            ListTile(
              leading: const Icon(Icons.smart_toy, color: Colors.blue),
              title: const Text("AI Name"),
              subtitle: Text(_aiName),
              trailing: const Icon(Icons.edit),
              onTap: () => _editAiNameDialog(),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.green),
              title: const Text("Change Username"),
              subtitle: Text(_userName),
              trailing: const Icon(Icons.edit),
              onTap: () => _editUserNameDialog(),
            ),

            ListTile(
              leading: const Icon(Icons.book, color: Colors.purple),
              title: const Text("Mood Journal"),
              subtitle: const Text("Track your daily moods and notes"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MoodJournalScreen()),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.download, color: Colors.teal),
              title: const Text("Export Chat History"),
              subtitle: const Text("Save or share your chat conversations"),
              onTap: _exportChatHistory,
            ),

            const Divider(height: 40),

            // 🧹 Clear app data
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text("Clear App Data"),
              subtitle: const Text("Erase chat history, memory, and preferences"),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Confirm Clear"),
                    content: const Text(
                        "Are you sure you want to clear all app data? This will delete all chat history and settings."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
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
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✏️ Edit username dialog
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
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("user_name", controller.text.trim());
              setState(() => _userName = controller.text.trim());
              if (!context.mounted) return; 
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ✏️ Edit AI name dialog
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
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString("ai_name", controller.text.trim());
              setState(() => _aiName = controller.text.trim());
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
