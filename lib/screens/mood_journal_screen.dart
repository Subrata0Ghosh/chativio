import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/ai_service.dart';

class MoodJournalScreen extends StatefulWidget {
  const MoodJournalScreen({super.key});

  @override
  State<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends State<MoodJournalScreen> {
  Box? _journalBox;
  List<Map<String, dynamic>> _entries = [];

  final List<Map<String, String>> _moodOptions = [
    {'label': 'Happy', 'emoji': '😊', 'color': '0xFF10B981'},
    {'label': 'Excited', 'emoji': '🎉', 'color': '0xFFEC4899'},
    {'label': 'Calm', 'emoji': '😌', 'color': '0xFF6366F1'},
    {'label': 'Neutral', 'emoji': '😐', 'color': '0xFF64748B'},
    {'label': 'Tired', 'emoji': '😴', 'color': '0xFFF59E0B'},
    {'label': 'Stressed', 'emoji': '😰', 'color': '0xFFF97316'},
    {'label': 'Sad', 'emoji': '😢', 'color': '0xFF3B82F6'},
    {'label': 'Angry', 'emoji': '😠', 'color': '0xFFEF4444'},
  ];

  final List<String> _triggerTags = [
    'Work',
    'Family',
    'Friends',
    'Health',
    'Sleep',
    'Hobby',
    'Weather',
  ];

  String _selectedMood = 'Happy';
  String _selectedEmoji = '😊';
  final Set<String> _selectedTriggers = {};
  final TextEditingController _noteController = TextEditingController();

  bool _isGeneratingInsight = false;
  String? _aiWellnessInsight;

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    if (!Hive.isBoxOpen('mood_journal')) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
      _journalBox = await Hive.openBox('mood_journal');
    } else {
      _journalBox = Hive.box('mood_journal');
    }
    final list = (_journalBox!.get('entries') as List?)?.cast<Map>() ?? [];
    setState(() {
      _entries = list.map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) {
          final da = a['date'] is DateTime
              ? a['date'] as DateTime
              : DateTime.tryParse(a['date'].toString()) ?? DateTime.now();
          final db = b['date'] is DateTime
              ? b['date'] as DateTime
              : DateTime.tryParse(b['date'].toString()) ?? DateTime.now();
          return db.compareTo(da);
        });
      _aiWellnessInsight = _journalBox!.get('cached_insight') as String?;
    });
  }

  Future<void> _saveEntry() async {
    if (_journalBox == null) return;
    final entry = {
      'date': DateTime.now(),
      'mood': _selectedMood,
      'emoji': _selectedEmoji,
      'triggers': _selectedTriggers.toList(),
      'note': _noteController.text.trim(),
    };
    _entries.insert(0, entry);
    await _journalBox!.put('entries', _entries);
    _noteController.clear();
    _selectedTriggers.clear();
    setState(() {});
  }

  Future<void> _generateAiWellnessInsight() async {
    if (_entries.isEmpty) return;

    setState(() => _isGeneratingInsight = true);

    final recentMoods = _entries
        .take(7)
        .map(
          (e) =>
              "${e['mood']} (triggers: ${(e['triggers'] as List?)?.join(', ')})",
        )
        .join('; ');
    final prompt =
        "Recent Mood Logs: $recentMoods. Provide a warm, uplifting, 2-3 sentence psychological wellness insight and one practical tip to support my emotional balance.";

    final reply = await AiService.instance.getChatReply(
      systemPrompt:
          "You are an empathetic emotional wellness and mental health companion. Provide thoughtful, validating, and grounding reflections.",
      messages: [
        {"user": prompt},
      ],
    );

    if (mounted) {
      setState(() {
        _aiWellnessInsight = reply;
        _isGeneratingInsight = false;
      });
      await _journalBox?.put('cached_insight', reply);
    }
  }

  void _showAddDialog() {
    _selectedMood = 'Happy';
    _selectedEmoji = '😊';
    _selectedTriggers.clear();
    _noteController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "How are you feeling right now?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Mood Options Grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _moodOptions.map((opt) {
                    final isSel = _selectedMood == opt['label'];
                    return ChoiceChip(
                      avatar: Text(
                        opt['emoji']!,
                        style: const TextStyle(fontSize: 18),
                      ),
                      label: Text(opt['label']!),
                      selected: isSel,
                      selectedColor: const Color(0xFF667EEA),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : null,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setModalState(() {
                            _selectedMood = opt['label']!;
                            _selectedEmoji = opt['emoji']!;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                const Text(
                  "What influenced this?",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),

                // Triggers Wrap
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _triggerTags.map((tag) {
                    final isSel = _selectedTriggers.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSel,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            _selectedTriggers.add(tag);
                          } else {
                            _selectedTriggers.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Reflect on this moment (optional note)...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667EEA),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _saveEntry();
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "Save Mood Log",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> get _moodDistribution {
    final dist = <String, int>{};
    for (final e in _entries) {
      final m = (e['mood'] ?? 'Neutral') as String;
      dist[m] = (dist[m] ?? 0) + 1;
    }
    return dist;
  }

  @override
  Widget build(BuildContext context) {
    final dist = _moodDistribution;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood & Wellness Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Log Mood",
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weekly Analytics Summary Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Emotional Wellness Overview",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF667EEA,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${_entries.length} Logs",
                          style: const TextStyle(
                            color: Color(0xFF667EEA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_entries.isEmpty) ...[
                    const Text(
                      "Start logging your daily moods to unlock personalized insights and trends!",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ] else ...[
                    // Distribution row
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: dist.entries.map((entry) {
                        final pct = ((entry.value / _entries.length) * 100)
                            .toInt();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${entry.key}: $pct%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // AI Insight Box
                  if (_aiWellnessInsight != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiWellnessInsight!,
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_entries.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingInsight
                            ? null
                            : _generateAiWellnessInsight,
                        icon: _isGeneratingInsight
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.psychology, size: 18),
                        label: Text(
                          _isGeneratingInsight
                              ? "Analyzing Moods..."
                              : "Get AI Wellness Insights ✨",
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            "Recent Entries",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.mood, size: 54, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    const Text("No mood logs yet."),
                    const SizedBox(height: 6),
                    ElevatedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Log First Mood"),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_entries.length, (i) {
              final e = _entries[i];
              final date = e['date'] is DateTime
                  ? e['date'] as DateTime
                  : DateTime.tryParse(e['date'].toString()) ?? DateTime.now();
              final emoji = (e['emoji'] ?? '😐') as String;
              final mood = (e['mood'] ?? 'Neutral') as String;
              final note = (e['note'] ?? '') as String;
              final triggers = (e['triggers'] as List?)?.cast<String>() ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  mood,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d • h:mm a').format(date),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (triggers.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                children: triggers
                                    .map(
                                      (t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(note, style: const TextStyle(fontSize: 14)),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onPressed: () async {
                          setState(() => _entries.removeAt(i));
                          await _journalBox!.put('entries', _entries);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
