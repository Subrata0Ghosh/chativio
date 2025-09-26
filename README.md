# 💬 Chativio

Chativio is a **free, offline, friend-like chatbot app** built with Flutter.  
It feels like a real friend — chatting naturally, remembering past conversations, reminding you of events, and even telling you stories.  

---

## ✨ Features
- 🟦 **Chat Screen** → Talk to Chativio like a real friend.  
- 📅 **Events** → Detects meetings/events from chats and reminds you.  
- 📖 **Stories** → Learn through fun, short stories.  
- 👤 **Profile** → Manage your app settings and personalization.  
- 🌗 **Dark & Light Themes** → Matches system theme automatically.  
- 🚀 **Offline-first** → Stores chats and data locally (using Hive/SQLite).  

---

## 📱 Screens
- **Splash Screen** → Animated glowing logo  
- **Onboarding** → Shown on first launch only  
- **Home (MainWrapper)** → Bottom navigation with:
  - Chat  
  - Events  
  - Stories  
  - Profile  

---

## 🛠️ Tech Stack
- **Flutter** (cross-platform UI)  
- **Dart**  
- **Hive / SQLite** (local storage)  
- **SharedPreferences** (first-launch check)  

---

## ▶️ Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or higher)
- Android Studio / VS Code with Flutter plugin  

### Run Locally
```bash
# Clone this repository
git clone https://github.com/your-username/chativio.git

# Go into the project folder
cd chativio

# Get dependencies
flutter pub get

# Run the app
flutter run
