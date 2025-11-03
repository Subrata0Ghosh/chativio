import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';

class StoriesScreen extends StatefulWidget {
  const StoriesScreen({super.key});

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  String _userMood = "neutral"; // default mood
  Map<String, String>? _currentStory;

  // 🧠 Story dataset categorized by mood
  final Map<String, List<Map<String, String>>> _moodStories = {
    "happy": [
      {
        "title": "The Ripple of a Smile",
        "content":
            "Ananya smiled at the chai seller every morning. One day, he said that her smile made his day brighter. Happiness travels quietly — even small acts can light up many hearts.",
        "mood": "Joyful"
      },
      {
        "title": "A Pocketful of Sunshine",
        "content":
            "Every time Mehul felt happy, he’d write down the reason on a small note and keep it in a jar. Later, during tough times, he’d open one at random — his own sunshine in a bottle.",
        "mood": "Grateful"
      },
    ],
    "sad": [
      {
        "title": "The Rainbow After Rain",
        "content":
            "Tanya felt lost after losing her job, but those quiet days helped her rediscover painting — her childhood passion. Sometimes endings are just disguised beginnings.",
        "mood": "Uplifting"
      },
      {
        "title": "The Broken Cup",
        "content":
            "A child broke his favorite cup and cried. His mother glued it together, cracks visible but strong. ‘See,’ she said, ‘even broken things can hold love.’ So can we.",
        "mood": "Healing"
      },
    ],
    "angry": [
      {
        "title": "The Calm River",
        "content":
            "A river never fights the rocks — it flows around them. When you stop resisting, peace flows back into you. Anger burns fast, but calm endures.",
        "mood": "Peaceful"
      },
      {
        "title": "The Pause Button",
        "content":
            "Before reacting, take one breath — it’s your pause button. It can save your words, your peace, and sometimes even a friendship.",
        "mood": "Mindful"
      },
    ],
    "stressed": [
      {
        "title": "The Empty Bench",
        "content":
            "Ravi used to rush all day until one morning, he sat on a park bench doing nothing — and found everything. Sometimes rest is progress.",
        "mood": "Relaxing"
      },
      {
        "title": "The Candle’s Lesson",
        "content":
            "A candle doesn’t light up by burning faster. It shines by burning steadily. Slow down — you’re still glowing.",
        "mood": "Soothing"
      },
    ],
    "neutral": [
      {
        "title": "The Path Ahead",
        "content":
            "Some days are just steady — neither up nor down. That’s life recharging quietly before your next adventure.",
        "mood": "Balanced"
      },
      {
        "title": "The Wanderer",
        "content":
            "Rohan had no plans one weekend, so he wandered aimlessly and found a new café, a new friend, and a new song. Magic often hides in the ordinary.",
        "mood": "Calm"
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadMoodAndStory();
  }

  Future<void> _loadMoodAndStory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMood = prefs.getString("last_mood") ?? "neutral";

    setState(() {
      _userMood = savedMood;
    });

    _loadRandomStoryForMood(savedMood);
  }

  void _loadRandomStoryForMood(String mood) {
    final stories = _moodStories[mood] ?? _moodStories["neutral"]!;
    final random = Random();
    setState(() {
      _currentStory = stories[random.nextInt(stories.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stories & Insights"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "New Story",
            onPressed: () => _loadRandomStoryForMood(_userMood),
          )
        ],
      ),
      body: _currentStory == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                _loadRandomStoryForMood(_userMood);
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Mood selector chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final mood in const [
                        'happy', 'sad', 'angry', 'stressed', 'neutral'
                      ])
                        ChoiceChip(
                          label: Text(mood),
                          selected: _userMood == mood,
                          onSelected: (sel) async {
                            if (!sel) return;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('last_mood', mood);
                            setState(() => _userMood = mood);
                            _loadRandomStoryForMood(mood);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentStory!["title"]!,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentStory!["content"]!,
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 500;
                      return isSmall
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _loadRandomStoryForMood(_userMood),
                                  icon: const Icon(Icons.auto_stories),
                                  label: const Text("Tell Me Another"),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final text =
                                        "${_currentStory!["title"]}\n\n${_currentStory!["content"]}";
                                    Share.share(text);
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Mood: ${_currentStory!["mood"]}",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _loadRandomStoryForMood(_userMood),
                                  icon: const Icon(Icons.auto_stories),
                                  label: const Text("Tell Me Another"),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final text =
                                        "${_currentStory!["title"]}\n\n${_currentStory!["content"]}";
                                    Share.share(text);
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                                const Spacer(),
                                Text(
                                  "Mood: ${_currentStory!["mood"]}",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
