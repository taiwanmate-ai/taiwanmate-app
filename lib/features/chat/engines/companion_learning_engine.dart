/// CompanionLearningEngine — tach logic phan tich loi khoi ChatScreen.
/// Ham thuan (pure function): nhan input, tra ket qua, khong mutate,
/// khong BuildContext, khong setState, khong API, khong async.
class CompanionLearningEngine {
  const CompanionLearningEngine();

  static const List<String> mistakeKeywords = ['sai', 'lỗi', 'không đúng', 'wrong'];
  static final RegExp _newVocabPattern = RegExp(r'\[NEW:([^\]]+)\]');

  /// Tra ve true neu userText nen duoc ghi nhan la loi, dua tren danh sach
  /// mistakes hien tai. KHONG mutate currentMistakes truyen vao.
  bool shouldTrackMistake(List<String> currentMistakes, String userText) {
    final hasKeyword = mistakeKeywords.any((k) => userText.contains(k));
    if (!hasKeyword) return false;
    if (currentMistakes.contains(userText)) return false;
    if (currentMistakes.length >= 10) return false;
    return true;
  }

  /// Ham thuan: trich xuat danh sach tu moi duoc AI danh dau [NEW:...]
  /// trong reply. Tra ve danh sach rong neu khong tim thay gi. Khong
  /// gioi han so luong, khong chong trung lap — giu dung hanh vi goc.
  List<String> extractNewVocab(String reply) {
    final matches = _newVocabPattern.allMatches(reply);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Ham thuan: tra ve so XP thuong ung voi moc sessionMessages, hoac null
  /// neu khong phai moc thuong. Khong mutate, khong UI, khong setState.
  int? getXpRewardForSessionCount(int sessionMessages) {
    switch (sessionMessages) {
      case 5:
        return 10;
      case 10:
        return 25;
      case 20:
        return 50;
      default:
        return null;
    }
  }
}
