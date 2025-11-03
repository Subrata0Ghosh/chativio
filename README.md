# 💬 Chativio

<div align="center">

<img src="https://raw.githubusercontent.com/Subrata0Ghosh/chativio/refs/heads/master/assets/images/logo.png" alt="Chativio Logo" width="100" height="100"/>

![Chativio Logo](https://img.shields.io/badge/Chativio-AI%20Chatbot-blue?style=for-the-badge&logo=flutter&logoColor=white)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Stars](https://img.shields.io/github/stars/Subrata0Ghosh/chativio?style=for-the-badge)](https://github.com/Subrata0Ghosh/chativio)

**Your AI Friend, Always Here** 💙
*Powered by Flutter & OpenAI GPT-4o-mini*

[📱 Download APK](#-getting-started) • [🌐 Live Demo](https://your-demo-link.com) • [📖 Documentation](#-features)

---

</div>

## ✨ Features

<table>
  <tr>
    <td align="center">
      <img src="https://img.shields.io/badge/AI%20Chat-🤖-blue?style=flat-square" /><br/>
      <b>Natural Conversations</b><br/>
      Chat like with a real friend using advanced AI
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Offline%20First-📴-green?style=flat-square" /><br/>
      <b>Works Offline</b><br/>
      Cached responses for seamless offline experience
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Voice%20I/O-🎤-purple?style=flat-square" /><br/>
      <b>Speak & Listen</b><br/>
      Voice input and TTS responses
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="https://img.shields.io/badge/Events%20Reminders-📅-orange?style=flat-square" /><br/>
      <b>Smart Scheduling</b><br/>
      Auto-detect and remind about events
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Image%20Sharing-📸-pink?style=flat-square" /><br/>
      <b>Photo Chats</b><br/>
      Send images and get AI descriptions
    </td>
    <td align="center">
      <img src="https://img.shields.io/badge/Dark%20Mode-🌙-black?style=flat-square" /><br/>
      <b>Beautiful Themes</b><br/>
      Material 3 with animations & gradients
    </td>
  </tr>
</table>

### 🎯 Key Highlights

- 🧠 **AI-Powered**: GPT-4o-mini for intelligent responses
- ⚡ **Fast & Smooth**: Optimized animations and caching
- 🔒 **Privacy-First**: All data stored locally
- 🎨 **Stunning UI**: Gradient bubbles, slide-in effects, Material 3
- 📱 **Cross-Platform**: Android, iOS, Web support

---

## 📱 Screenshots

<div align="center">

| Splash Screen                                                                                          | Chat Interface                                                                                     | Events Screen                                                                                         |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| ![Splash](https://raw.githubusercontent.com/Subrata0Ghosh/chativio/master/assets/images/splash_screen.png) | ![Chat](https://raw.githubusercontent.com/Subrata0Ghosh/chativio/master/assets/images/chat_screen.png) | ![Events](https://raw.githubusercontent.com/Subrata0Ghosh/chativio/master/assets/images/event_screen.png) |

*Screenshots of the app in action*

</div>

---

## 🛠️ Tech Stack

<div align="center">

| Component           | Technology                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------- |
| **Framework** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)        |
| **Language**  | ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)                 |
| **AI**        | ![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat&logo=openai&logoColor=white)           |
| **Storage**   | ![Hive](https://img.shields.io/badge/Hive-000000?style=flat&logo=hive&logoColor=white)                 |
| **State**     | ![Provider](https://img.shields.io/badge/Provider-000000?style=flat&logo=flutter&logoColor=white)      |
| **Voice**     | ![Speech](https://img.shields.io/badge/Speech--to--Text-FF6B6B?style=flat&logo=google&logoColor=white) |

</div>

---

## ▶️ Getting Started

### Prerequisites

- ![Flutter](https://img.shields.io/badge/Flutter-3.x+-02569B?style=flat&logo=flutter&logoColor=white)
- ![Android Studio](https://img.shields.io/badge/Android%20Studio-3DDC84?style=flat&logo=android-studio&logoColor=white) or VS Code
- OpenAI API Key (free tier available)

### 🚀 Quick Setup

1. **Clone & Setup** 📥

   ```bash
   git clone https://github.com/Subrata0Ghosh/chativio.git
   cd chativio
   flutter pub get
   ```
2. **Add API Key** 🔑

   ```bash
   # Create lib/secrets.dart
   echo "const String openAIApiKey = 'your-api-key-here';" > lib/secrets.dart
   ```
3. **Run App** ▶️

   ```bash
   flutter run
   ```

### 📦 Build for Production

| Platform              | Command                         |
| --------------------- | ------------------------------- |
| **Android APK** | `flutter build apk --release` |
| **iOS**         | `flutter build ios --release` |
| **Web**         | `flutter build web --release` |

---

## 📂 Project Structure

```
lib/
├── main.dart                 # 🚀 App Entry Point
├── providers/
│   └── theme_provider.dart   # 🎨 Theme Management
├── screens/
│   ├── chat_screen.dart      # 💬 Main Chat UI
│   ├── events_screen.dart    # 📅 Events Management
│   ├── stories_screen.dart   # 📖 Stories Reader
│   ├── flash_screen.dart     # ✨ Splash Screen
│   └── profile_screen.dart   # 👤 Settings & Profile
├── services/
│   ├── notification_service.dart # 🔔 Notifications
│   └── nlp_service.dart      # 🧠 NLP for Events
└── widgets/
    └── typing_dots.dart      # ⌨️ Typing Animation
```

---

## 🤝 Contributing

<div align="center">

We love contributions! 🎉

[![Contributing Guide](https://img.shields.io/badge/Contributing-Guide-blue?style=for-the-badge)](CONTRIBUTING.md)
[![Issues](https://img.shields.io/github/issues/Subrata0Ghosh/chativio?style=for-the-badge)](https://github.com/Subrata0Ghosh/chativio/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=for-the-badge)](https://github.com/Subrata0Ghosh/chativio/pulls)

</div>

1. 🍴 Fork the repo
2. 🌿 Create feature branch: `git checkout -b feature/amazing-feature`
3. 💻 Commit changes: `git commit -m 'Add amazing feature'`
4. 🚀 Push: `git push origin feature/amazing-feature`
5. 🔄 Open Pull Request

---

## 📄 License

<div align="center">

[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**This project is licensed under the MIT License**
*See [LICENSE](LICENSE) file for details*

</div>

---

## 🙏 Acknowledgments

<div align="center">

**Built with ❤️ by [Subrata Ghosh](https://github.com/Subrata0Ghosh)**

*Special thanks to:*

- OpenAI for GPT models 🤖
- Flutter community for amazing framework 🚀
- Material Design for beautiful UI guidelines 🎨

</div>

---

<div align="center">

### 🌟 Show some love!

[![GitHub stars](https://img.shields.io/github/stars/Subrata0Ghosh/chativio?style=social)](https://github.com/Subrata0Ghosh/chativio)
[![GitHub forks](https://img.shields.io/github/forks/Subrata0Ghosh/chativio?style=social)](https://github.com/Subrata0Ghosh/chativio)

**Made with Flutter & Love** 💙

</div>
