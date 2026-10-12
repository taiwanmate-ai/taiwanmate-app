/// Chon ngon ngu nhan dien giong noi cho Voice (2026-10-13, Dot 2) — chi hien khi server bao `voice_features.stt_language_selector` (allowlist).
/// Chon 中文/Tiếng Việt/English -> app gui `stt_language` kem audio_end, backend truyen `language` xuong STT va bo qua cong ngon ngu.
/// Nho lua chon cuoi theo tung nguoi dung (SharedPreferences, khoa theo user). Mac dinh: Tu dong.
library;

import 'package:shared_preferences/shared_preferences.dart';

enum VoiceSttLanguage {
  auto('auto', 'Tự động'),
  zh('zh', '中文'),
  vi('vi', 'Tiếng Việt'),
  en('en', 'English');

  const VoiceSttLanguage(this.wire, this.label);
  final String wire;
  final String label;

  static VoiceSttLanguage fromWire(String? value) {
    for (final l in VoiceSttLanguage.values) {
      if (l.wire == value) return l;
    }
    return VoiceSttLanguage.auto;
  }
}

/// Cac lua chon hien thi: Tu dong | 中文 | Tiếng Việt, them English khi bai hoc la tieng Anh (en_vi / en_only) — va server cho phep.
List<VoiceSttLanguage> voiceSttLanguageOptions({required String learningMode, List<String>? serverOptions}) {
  bool allowed(VoiceSttLanguage l) => serverOptions == null || serverOptions.isEmpty || serverOptions.contains(l.wire);
  final opts = <VoiceSttLanguage>[
    VoiceSttLanguage.auto,
    VoiceSttLanguage.zh,
    VoiceSttLanguage.vi,
    if (learningMode.startsWith('en')) VoiceSttLanguage.en,
  ];
  return opts.where(allowed).toList();
}

class VoiceSttLanguageStore {
  const VoiceSttLanguageStore();

  static String keyFor(String? userKey) => 'voice_stt_language_${(userKey == null || userKey.isEmpty) ? 'default' : userKey}';

  /// Doc lua chon cuoi; loi/khong co -> Tu dong. Khong bao gio nem.
  Future<VoiceSttLanguage> load(String? userKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return VoiceSttLanguage.fromWire(prefs.getString(keyFor(userKey)));
    } catch (_) {
      return VoiceSttLanguage.auto;
    }
  }

  Future<void> save(String? userKey, VoiceSttLanguage value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(userKey), value.wire);
    } catch (_) {}
  }
}
