/// learning_mode_provider.dart — 2026-08-20.
///
/// NGUON DUY NHAT cho lua chon "hoc nhu the nao" (zh_vi/zh_only/en_vi/
/// en_only) — DUNG CHUNG cho CA Chat (chat_screen.dart) va Voice
/// (voice_chat_screen.dart). TRUOC DAY chat_screen.dart co 1 bien
/// `_learningMode` CHI luu trong State (khong persist — moi lan mo lai
/// man hinh deu reset ve 'zh_vi' mac dinh, BAT KE user da chon gi truoc
/// do), va Voice hoan toan KHONG co lua chon nao (backend hardcode
/// zh_vi). Provider nay + LearningModeSelectionScreen thay the CA 2 —
/// persist qua SharedPreferences (dung PATTERN GIONG HET
/// hanzi_mode_provider.dart, da proven trong app nay), 1 lan chon dung
/// cho ca 2 tinh nang.
///
/// State la String? — null nghia la CHUA TUNG CHON (dung de Gate man
/// hinh AI Chat quyet dinh co hien LearningModeSelectionScreen lan dau
/// hay khong). loadLearningMode() la ham DOC TRUC TIEP (khong qua
/// Riverpod state) — dung trong FutureBuilder cua Gate de tranh nhap
/// nhang "dang loading" vs "da xac nhan la null" cua StateNotifier.state
/// (state ban dau LUON null truoc khi _load() bat dau xong, khong the
/// phan biet voi "that su chua chon" chi bang gia tri state).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLearningModeKey = 'learning_mode';

const List<String> kValidLearningModes = ['zh_vi', 'zh_only', 'en_vi', 'en_only'];

Future<String?> loadLearningMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(kLearningModeKey);
  return kValidLearningModes.contains(saved) ? saved : null;
}

class LearningModeNotifier extends StateNotifier<String?> {
  LearningModeNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    state = await loadLearningMode();
  }

  Future<void> setMode(String mode) async {
    assert(kValidLearningModes.contains(mode), 'learningMode khong hop le: $mode');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLearningModeKey, mode);
    state = mode;
  }
}

final learningModeProvider = StateNotifierProvider<LearningModeNotifier, String?>(
  (ref) => LearningModeNotifier(),
);
