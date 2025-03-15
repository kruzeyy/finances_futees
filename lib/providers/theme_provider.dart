import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(Hive.box('settings').get('isDarkMode', defaultValue: false));

  void toggleTheme() {
    state = !state;
    Hive.box('settings').put('isDarkMode', state); // Enregistre le choix dans Hive
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier();
});