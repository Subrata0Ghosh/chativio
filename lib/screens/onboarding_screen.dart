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

  final TextEditingController _userNameController = TextEditingController();
  String _userGender = "Not set";
  final TextEditingController _aiNameController = TextEditingController(text: "Chativio");
  String _aiGender = "Not set";

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isFirstLaunch", false);
    await prefs.setString("userName", _userNameController.text.trim());
    await prefs.setString("userGender", _userGender);
    await prefs.setString("aiName", _aiNameController.text.trim());
    await prefs.setString("aiGender", _aiGender);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  Widget _genderSelector(String title, String selected, ValueChanged<String> onChanged) {
    return Row(
      children: [
        ChoiceChip(
          label: const Text("Male"),
          selected: selected == "Male",
          onSelected: (_) => onChanged("Male"),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text("Female"),
          selected: selected == "Female",
          onSelected: (_) => onChanged("Female"),
        ),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text("Other"),
          selected: selected == "Other",
          onSelected: (_) => onChanged("Other"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text(
                  "Welcome to Chativio 👋",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text("Let’s personalize your AI friend experience."),
                const SizedBox(height: 30),

                // User Name
                TextFormField(
                  controller: _userNameController,
                  decoration: const InputDecoration(
                    labelText: "Your Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? "Please enter your name" : null,
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

                const Spacer(),

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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
