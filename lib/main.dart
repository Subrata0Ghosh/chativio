
import 'package:flutter/material.dart';
import 'package:myapp/screens/flash_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:myapp/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';

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
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Chativio',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.theme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

