import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_open_chinese_convert/flutter_open_chinese_convert.dart';

enum HanziMode { traditional, simplified }

class HanziModeNotifier extends StateNotifier<HanziMode> {
  HanziModeNotifier() : super(HanziMode.traditional) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('hanzi_mode');
    state = saved == 'simplified' ? HanziMode.simplified : HanziMode.traditional;
  }

  Future<void> setMode(HanziMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hanzi_mode', mode == HanziMode.simplified ? 'simplified' : 'traditional');
    state = mode;
  }
}

final hanziModeProvider = StateNotifierProvider<HanziModeNotifier, HanziMode>(
  (ref) => HanziModeNotifier(),
);

// Hàm chuyển đổi dùng chung — gọi hàm này ở MỌI nơi hiển thị chữ Hán
Future<String> convertHanzi(String text, HanziMode mode) async {
  if (mode == HanziMode.traditional || text.isEmpty) return text;
  try {
    return await ChineseConverter.convert(text, TW2S());
  } catch (_) {
    return text;
  }
}