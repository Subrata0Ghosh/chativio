
import 'package:flutter/material.dart';
import 'package:myapp/screens/flash_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:myapp/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('chat');
  await NotificationService.instance.init();
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

