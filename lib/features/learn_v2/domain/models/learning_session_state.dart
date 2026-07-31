import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';

/// State thuan cho 1 buoi hoc — danh sach tu, vi tri hien tai, tu nao da luu.
/// KHONG lien quan SRS/Review — chi la 1 phien duyet qua tung tu 1 lan.
class LearningSessionState {
  final List<VocabularyWord> words;
  final int currentIndex;
  final Set<String> savedWordIds;

  const LearningSessionState({
    required this.words,
    this.currentIndex = 0,
    this.savedWordIds = const {},
  });

  bool get isFinished => words.isNotEmpty && currentIndex >= words.length;
  bool get isEmpty => words.isEmpty;

  VocabularyWord? get currentWord =>
      (isFinished || isEmpty) ? null : words[currentIndex];

  /// Vi tri hien thi dang "3 / 20" — 1-based, khong vuot qua tong so
  int get displayPosition =>
      words.isEmpty ? 0 : (currentIndex + 1).clamp(1, words.length);

  int get totalCount => words.length;

  double get progressRatio =>
      words.isEmpty ? 0 : currentIndex / words.length;

  bool isCurrentWordSaved() {
    final word = currentWord;
    if (word == null) return false;
    return savedWordIds.contains(word.vocabularyId);
  }

  LearningSessionState copyWith({
    List<VocabularyWord>? words,
    int? currentIndex,
    Set<String>? savedWordIds,
  }) {
    return LearningSessionState(
      words: words ?? this.words,
      currentIndex: currentIndex ?? this.currentIndex,
      savedWordIds: savedWordIds ?? this.savedWordIds,
    );
  }
}