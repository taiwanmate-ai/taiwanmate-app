/// Audit "Safari iOS: TTS khong phat am thanh" (2026-09-04) — logic THUAN
/// (khong dung dart:html/dart:js) tach RIENG khoi web_utils_impl.dart de
/// TEST DUOC tren Dart VM binh thuong (web_utils_impl.dart khong the chay
/// trong `flutter test` mac dinh vi import dart:html — chi bien dich duoc
/// khi target la web that).
///
/// web_utils_impl.dart's _getSingletonAudio()/webUnlockAudio() GOI TRUC
/// TIEP class nay de quyet dinh: co nen tao AudioElement THAT moi hay tai
/// su dung cai da co, va da unlock thanh cong chua — dam bao test o day
/// xac nhan DUNG hanh vi production dang chay, khong phai ban sao logic
/// rieng cho test.
library;

class AudioUnlockGate {
  int _elementCreations = 0;
  bool _unlocked = false;

  int get elementCreations => _elementCreations;
  bool get isUnlocked => _unlocked;

  /// True CHI o lan goi DAU TIEN — caller nen thuc su tao AudioElement moi
  /// luc do. Cac lan goi SAU tra ve false (tai su dung element da co san),
  /// du unlock() da thanh cong hay chua.
  bool needsElementCreation() {
    if (_elementCreations > 0) return false;
    _elementCreations++;
    return true;
  }

  /// Danh dau da unlock thanh cong (audio.play() ben trong 1 user gesture
  /// that da resolve, khong bi trinh duyet reject).
  void markUnlocked() {
    _unlocked = true;
  }
}
