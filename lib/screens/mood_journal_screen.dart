import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class MoodJournalScreen extends StatefulWidget {
  const MoodJournalScreen({super.key});

  @override
  State<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends State<MoodJournalScreen> {
  Box? _journalBox;
  List<Map<String, dynamic>> _entries = [];

  final List<String> _moods = ['😊 Happy', '😢 Sad', '😠 Angry', '😰 Stressed', '😐 Neutral', '😴 Tired', '😍 Excited'];
  String _selectedMood = '😐 Neutral';
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    if (!Hive.isBoxOpen('mood_journal')) {
      try { await Hive.initFlutter(); } catch (_) {}
      _journalBox = await Hive.openBox('mood_journal');
    } else {
      _journalBox = Hive.box('mood_journal');
    }
    final list = (_journalBox!.get('entries') as List?)?.cast<Map>() ?? [];
    setState(() {
      _entries = list.map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    });
  }

  Future<void> _saveEntry() async {
    if (_journalBox == null) return;
    final entry = {
      'date': DateTime.now(),
      'mood': _selectedMood,
      'note': _noteController.text.trim(),
    };
    _entries.insert(0, entry);
    await _journalBox!.put('entries', _entries);
    _noteController.clear();
    _selectedMood = '😐 Neutral';
    setState(() {});
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Log Your Mood'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: _selectedMood,
                items: _moods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _selectedMood = v!),
              ),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () {
              _saveEntry();
              Navigator.pop(ctx);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(child: Text('No entries yet. Tap + to add your first mood log!'))
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (ctx, i) {
                final e = _entries[i];
                final date = e['date'] as DateTime;
                return ListTile(
                  leading: Text(e['mood'], style: const TextStyle(fontSize: 24)),
                  title: Text(DateFormat('MMM d, yyyy • h:mm a').format(date)),
                  subtitle: e['note'].isNotEmpty ? Text(e['note']) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      setState(() => _entries.removeAt(i));
                      await _journalBox!.put('entries', _entries);
                    },
                  ),
                );
              },
            ),
    );
  }
}
