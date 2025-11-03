# 💬 Chativio

Chativio is a **free, offline, friend-like chatbot app** built with Flutter.  
It feels like a real friend — chatting naturally, remembering past conversations, reminding you of events, and even telling you stories.  
Powered by AI (OpenAI GPT-4o-mini) with **offline caching** for seamless conversations!

---

## ✨ Features

- 🟦 **AI Chat** → Talk to Chativio like a real friend with natural responses.
- 📅 **Smart Events** → Detects meetings/events from chats and sets reminders.
- 📖 **Stories** → Learn through fun, short stories with responsive design.
- 👤 **Profile** → Manage settings, export chats, and personalization.
- 🌗 **Beautiful Themes** → Light/Dark modes with Material 3, gradients, and animations.
- 🚀 **Offline-First** → Stores chats, responses, and data locally (Hive/SQLite).
- 📸 **Image Sharing** → Send photos in chat for AI description.
- 🎙️ **Voice Input/Output** → Speak to Chativio and hear responses.
- 💾 **Offline Caching** → AI responses cached for offline access.
- 🎨 **Animated UI** → Slide-in bubbles, fade effects, stunning gradients.

---

## 📱 Screenshots

*(Add screenshots here)*

---

## 🛠️ Tech Stack

- **Flutter** (cross-platform UI with Material 3)
- **Dart**
- **Hive / SQLite** (local storage)
- **SharedPreferences** (settings)
- **OpenAI API** (GPT-4o-mini for chat)
- **Speech-to-Text & TTS** (voice features)
- **Provider** (state management)
- **Image Picker** (photo sharing)

---

## ▶️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or higher)
- Android Studio / VS Code with Flutter plugin
- OpenAI API Key (for AI chat)

### Setup
1. **Clone the repo**:
   ```bash
   git clone https://github.com/Subrata0Ghosh/chativio.git
   cd chativio
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Add API Key**:
   - Create `lib/secrets.dart`:
     ```dart
     const String openAIApiKey = 'your-openai-api-key-here';
     ```

4. **Run the app**:
   ```bash
   flutter run
   ```

### Build for Production
```bash
# Android APK
flutter build apk --release

# iOS (on macOS)
flutter build ios --release

# Web
flutter build web --release
```

---

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── providers/
│   └── theme_provider.dart   # Theme management
├── screens/
│   ├── chat_screen.dart      # Main chat UI
│   ├── events_screen.dart    # Events management
│   ├── stories_screen.dart   # Stories reader
│   └── profile_screen.dart   # Settings & profile
├── services/
│   ├── notification_service.dart
│   └── nlp_service.dart      # NLP for events
├── widgets/
│   └── typing_dots.dart      # Typing animation
└── secrets.dart              # API keys (add manually)
```

---

## 🤝 Contributing

Contributions welcome! 🚀

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- OpenAI for GPT models
- Flutter community for amazing framework
- Icons from Lucide & Material Icons

---

*Made with ❤️ by Subrata Ghosh*
