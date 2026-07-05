import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<Map<String, dynamic>> themeColors = [
  {'name': 'Đỏ (Mặc định)', 'color': Color(0xFFE8334A)},
  {'name': 'Xanh dương', 'color': Color(0xFF3B82F6)},
  {'name': 'Xanh lá', 'color': Color(0xFF10B981)},
  {'name': 'Tím', 'color': Color(0xFF8B5CF6)},
  {'name': 'Cam', 'color': Color(0xFFF59E0B)},
  {'name': 'Hồng', 'color': Color(0xFFEC4899)},
  {'name': 'Xanh ngọc', 'color': Color(0xFF06B6D4)},
];

class ThemeState {
  final Color primaryColor;
  final ThemeMode themeMode;

  const ThemeState({
    this.primaryColor = const Color(0xFFE8334A),
    this.themeMode = ThemeMode.dark,
  });

  ThemeState copyWith({Color? primaryColor, ThemeMode? themeMode}) {
    return ThemeState(
      primaryColor: primaryColor ?? this.primaryColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getString('theme_color');
    final modeValue = prefs.getString('theme_mode');
    state = ThemeState(
      primaryColor: colorValue != null
          ? Color(int.parse(colorValue))
          : const Color(0xFFE8334A),
      themeMode: modeValue == 'light' ? ThemeMode.light : ThemeMode.dark,
    );
  }

  Future<void> setColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_color', color.value.toString());
    state = state.copyWith(primaryColor: color);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
    state = state.copyWith(themeMode: mode);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) => ThemeNotifier(),
);
