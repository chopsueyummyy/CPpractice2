import 'package:flutter/material.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  static void toggleTheme() {
    themeModeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }
}
