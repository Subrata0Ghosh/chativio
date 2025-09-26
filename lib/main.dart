
import 'package:flutter/material.dart';
import 'package:myapp/screens/flash_screen.dart';

void main() {
  runApp(const ChativioApp());
}

class ChativioApp extends StatelessWidget {
  const ChativioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chativio',
      debugShowCheckedModeBanner: false,

      //light theme
      theme: ThemeData(
        brightness:Brightness.light,
        primarySwatch: Colors.blue,

      ),

      //dark theme
      darkTheme:ThemeData(
        brightness: Brightness.dark,
        primarySwatch:Colors.blue,
      ),

      themeMode:ThemeMode.system,

      home: const SplashScreen(),
    );
  }
}

