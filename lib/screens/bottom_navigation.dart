import 'package:flutter/material.dart';
import 'package:myapp/screens/chat_screen.dart';
// import 'package:myapp/screens/events_screen.dart';
// import 'package:myapp/screens/stories_screen.dart';
import 'package:myapp/screens/profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    ChatScreen(),
    // EventsScreen(),
    // StoriesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          // BottomNavigationBarItem(icon: Icon(Icons.event), label: "Events"),
          // BottomNavigationBarItem(icon: Icon(Icons.book), label: "Stories"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
