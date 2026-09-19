import 'package:flutter/material.dart';
import 'package:myapp/screens/bottom_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:myapp/screens/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _userNameController = TextEditingController(
    text: "Friend",
  );
  String _userGender = "Not set";
  final TextEditingController _aiNameController = TextEditingController(
    text: "Chativio",
  );
  String _aiGender = "Not set";

  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final name = _userNameController.text.trim().isEmpty
        ? "Friend"
        : _userNameController.text.trim();
    await prefs.setBool("isFirstLaunch", false);
    await prefs.setString("userName", name);
    await prefs.setString("userGender", _userGender);
    await prefs.setString("aiName", _aiNameController.text.trim());
    await prefs.setString("aiGender", _aiGender);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  Widget _genderSelector(
    String title,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text("Male"),
          selected: selected == "Male",
          onSelected: (_) => onChanged("Male"),
        ),
        ChoiceChip(
          label: const Text("Female"),
          selected: selected == "Female",
          onSelected: (_) => onChanged("Female"),
        ),
        ChoiceChip(
          label: const Text("Other"),
          selected: selected == "Other",
          onSelected: (_) => onChanged("Other"),
        ),
      ],
    );
  }

  Widget _buildWelcomePage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat, size: 100, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Welcome to Chativio",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your AI companion for chat and mood tracking",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_toy, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "Chat with Your AI Friend",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Engage in meaningful conversations and get personalized responses",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodPage() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mood, size: 100, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Track Your Daily Moods",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Keep a journal of your emotions and reflect on your well-being",
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalizationPage() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 24,
              bottom: 24 + (bottomInset > 0 ? bottomInset : 0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Personalize Your Experience",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text("Let’s set up your AI friend."),
                const SizedBox(height: 30),

                // User Name
                TextFormField(
                  controller: _userNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "Your Name",
                    hintText: "Enter your name (or leave default)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // User Gender
                const Text("Your Gender"),
                const SizedBox(height: 8),
                _genderSelector("User Gender", _userGender, (val) {
                  setState(() => _userGender = val);
                }),
                const SizedBox(height: 25),

                // AI Name
                TextFormField(
                  controller: _aiNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: "AI Friend Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // AI Gender
                const Text("AI Gender"),
                const SizedBox(height: 8),
                _genderSelector("AI Gender", _aiGender, (val) {
                  setState(() => _aiGender = val);
                }),

                const SizedBox(height: 28),

                // Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Let's Start 🚀",
                      style: TextStyle(fontSize: 18, color: Colors.white),
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

  Widget _buildDotsIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? Colors.blue : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          TextButton(
            onPressed: () {
              _pageController.jumpToPage(3);
            },
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        children: [
          _buildWelcomePage(),
          _buildChatPage(),
          _buildMoodPage(),
          _buildPersonalizationPage(),
        ],
      ),
      bottomSheet: _currentPage < 3 ? _buildDotsIndicator() : null,
    );
  }
}
