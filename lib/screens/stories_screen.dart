import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../services/ai_service.dart';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FlutterTts _tts = FlutterTts();

  String _userMood = "neutral";
  String _selectedGenre = "Inspirational";
  final TextEditingController _customTopicController = TextEditingController();

  Map<String, String>? _currentStory;
  bool _isGenerating = false;
  bool _isPlayingAudio = false;

  Box? _storiesBox;
  List<Map<String, String>> _favoriteStories = [];

  final List<String> _genres = [
    "Inspirational",
    "Bedtime",
    "Adventure",
    "Sci-Fi",
    "Mystery",
    "Humor",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();
    _initHive();
    _loadMoodAndInitialStory();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  Future<void> _initHive() async {
    if (!Hive.isBoxOpen('saved_stories')) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
      _storiesBox = await Hive.openBox('saved_stories');
    } else {
      _storiesBox = Hive.box('saved_stories');
    }
    _loadFavoriteStories();
  }

  void _loadFavoriteStories() {
    final raw = (_storiesBox?.get('favorites') as List?) ?? [];
    setState(() {
      _favoriteStories = raw
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    });
  }

  Future<void> _toggleFavorite() async {
    if (_currentStory == null || _storiesBox == null) return;
    final title = _currentStory!['title'] ?? '';

    final existingIndex = _favoriteStories.indexWhere(
      (s) => s['title'] == title,
    );
    if (existingIndex >= 0) {
      _favoriteStories.removeAt(existingIndex);
    } else {
      _favoriteStories.insert(0, _currentStory!);
    }

    await _storiesBox!.put('favorites', _favoriteStories);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingIndex >= 0
                ? "Removed from saved stories."
                : "Saved to your story library! ⭐",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool get _isCurrentStoryFavorite {
    if (_currentStory == null) return false;
    final title = _currentStory!['title'] ?? '';
    return _favoriteStories.any((s) => s['title'] == title);
  }

  Future<void> _loadMoodAndInitialStory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMood = prefs.getString("last_mood") ?? "neutral";
    setState(() {
      _userMood = savedMood;
    });

    // Provide default starter story
    _currentStory = {
      "title": "The Whispering Breeze",
      "content":
          "On an ordinary afternoon, Sophie sat near the open window, letting the cool evening air brush past her face. For weeks, she had been running from task to task, feeling like life was a race she couldn't win. But in that quiet minute, listening to the gentle rustle of the trees, she realized: the world was not rushing her. Only her thoughts were.\n\nShe closed her eyes, took a long slow breath, and felt a quiet, grounding peace return to her chest.",
      "mood": "Calm",
      "moral":
          "Peace is not the absence of work; it is the presence of stillness inside.",
      "genre": "Inspirational",
    };
    setState(() {});
  }

  Future<void> _generateNewStory() async {
    // If not Pro and already used 3 story generations, prompt pro
    setState(() {
      _isGenerating = true;
      _stopAudio();
    });

    final story = await AiService.instance.generateStory(
      genre: _selectedGenre,
      mood: _userMood,
      customTopic: _customTopicController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _currentStory = story;
        _isGenerating = false;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      await _stopAudio();
    } else if (_currentStory != null) {
      setState(() => _isPlayingAudio = true);
      final textToRead =
          "${_currentStory!['title']}.\n\n${_currentStory!['content']}\n\nKey Takeaway: ${_currentStory!['moral']}";
      await _tts.speak(textToRead);
    }
  }

  Future<void> _stopAudio() async {
    await _tts.stop();
    if (mounted) setState(() => _isPlayingAudio = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customTopicController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          "Stories & Insights",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          indicatorWeight: 3,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_stories_rounded, size: 20),
              text: "AI Story Studio",
            ),
            Tab(
              icon: Icon(Icons.bookmark_rounded, size: 20),
              text: "Saved Library",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStoryStudioTab(), _buildSavedLibraryTab()],
      ),
    );
  }

  Widget _buildStoryStudioTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Genre Chips
        Text(
          "Choose Genre",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _genres.map((genre) {
              final isSel = _selectedGenre == genre;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(genre),
                  selected: isSel,
                  selectedColor: primary,
                  backgroundColor: isDark
                      ? const Color(0xFF131A2B)
                      : const Color(0xFFE2E8F0),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: GoogleFonts.outfit(
                    color: isSel
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedGenre = genre);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Custom Topic Input (optional)
        TextField(
          controller: _customTopicController,
          decoration: InputDecoration(
            hintText: "Optional topic (e.g. overcoming fear, cozy rainy night)",
            prefixIcon: const Icon(Icons.edit_note),
            suffixIcon: _customTopicController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () =>
                        setState(() => _customTopicController.clear()),
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Generate Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateNewStory,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isGenerating ? "Writing Your Story..." : "Generate AI Story ✨",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Story Display Card
        if (_currentStory != null) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            color: isDark ? const Color(0xFF111728) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${_currentStory!['genre']} • ${_currentStory!['mood']}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlayingAudio
                                  ? Icons.stop_circle_rounded
                                  : Icons.volume_up_rounded,
                              color: _isPlayingAudio
                                  ? Colors.redAccent
                                  : primary,
                            ),
                            tooltip: _isPlayingAudio
                                ? "Stop Audio"
                                : "Listen to Story",
                            onPressed: _toggleAudio,
                          ),
                          IconButton(
                            icon: Icon(
                              _isCurrentStoryFavorite
                                  ? Icons.star
                                  : Icons.star_border,
                              color: _isCurrentStoryFavorite
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            tooltip: "Save to Library",
                            onPressed: _toggleFavorite,
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: "Share Story",
                            onPressed: () {
                              final text =
                                  "${_currentStory!['title']}\n\n${_currentStory!['content']}\n\nTakeaway: ${_currentStory!['moral']}";
                              Share.share(text);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentStory!["title"] ?? "Story",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _currentStory!["content"] ?? "",
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (_currentStory!["moral"] != null &&
                      _currentStory!["moral"]!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentStory!["moral"]!,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSavedLibraryTab() {
    if (_favoriteStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              "No saved stories yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Tap the star icon on any generated story to save it here.",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteStories.length,
      itemBuilder: (context, index) {
        final story = _favoriteStories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              story['title'] ?? 'Story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              story['content'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Color(0xFF667EEA)),
                  onPressed: () {
                    _tts.speak("${story['title']}.\n\n${story['content']}");
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () async {
                    setState(() {
                      _favoriteStories.removeAt(index);
                    });
                    await _storiesBox?.put('favorites', _favoriteStories);
                  },
                ),
              ],
            ),
            onTap: () {
              setState(() {
                _currentStory = story;
                _tabController.animateTo(0);
              });
            },
          ),
        );
      },
    );
  }
}
