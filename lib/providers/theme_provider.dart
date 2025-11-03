import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get theme => _isDarkMode ? _darkTheme : _lightTheme;

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blueAccent,
    brightness: Brightness.light,
    primary: Colors.blueAccent,
    secondary: Colors.purpleAccent,
    tertiary: Colors.tealAccent,
    surface: Colors.white,
    onSurface: Colors.black87,
    surfaceContainerHighest: Colors.blue.shade50,
  );

  static final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blueAccent,
    brightness: Brightness.dark,
    primary: Colors.blueAccent,
    secondary: Colors.purpleAccent,
    tertiary: Colors.tealAccent,
    surface: Colors.grey.shade900,
    onSurface: Colors.white,
    surfaceContainerHighest: Colors.grey.shade800,
  );

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _lightColorScheme,
    scaffoldBackgroundColor: _lightColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: _lightColorScheme.primaryContainer,
      foregroundColor: _lightColorScheme.onPrimaryContainer,
      elevation: 4,
      shadowColor: _lightColorScheme.shadow,
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shadowColor: _lightColorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shadowColor: _lightColorScheme.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(color: _lightColorScheme.onSurface, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: _lightColorScheme.onSurface),
      bodyMedium: TextStyle(color: _lightColorScheme.onSurfaceVariant),
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: _darkColorScheme,
    scaffoldBackgroundColor: _darkColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: _darkColorScheme.primaryContainer,
      foregroundColor: _darkColorScheme.onPrimaryContainer,
      elevation: 4,
      shadowColor: _darkColorScheme.shadow,
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shadowColor: _darkColorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shadowColor: _darkColorScheme.shadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(color: _darkColorScheme.onSurface, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: _darkColorScheme.onSurface),
      bodyMedium: TextStyle(color: _darkColorScheme.onSurfaceVariant),
    ),
  );

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }
}
