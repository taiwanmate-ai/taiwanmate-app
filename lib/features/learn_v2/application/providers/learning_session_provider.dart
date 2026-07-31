import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/learn_v2/domain/models/learning_session_state.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';
import 'package:chinesemate/features/learn_v2/data/repositories/vocabulary_repository.dart';
import 'package:chinesemate/features/learn_v2/application/providers/vocabulary_providers.dart';

class LearningSessionNotifier extends StateNotifier<LearningSessionState> {
  final VocabularyRepository _repository;

  LearningSessionNotifier(this._repository)
      : super(const LearningSessionState(words: []));

  /// Bat dau 1 buoi hoc moi voi danh sach tu cho truoc.
  void start(List<VocabularyWord> words) {
    state = LearningSessionState(words: words);
  }

  void next() {
    if (state.currentIndex < state.words.length) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Luu tu hien tai. Nem loi ra ngoai de UI tu quyet dinh hien SnackBar —
  /// KHONG chan luong hoc du luu that bai.
  Future<void> saveCurrentWord(String language) async {
    final word = state.currentWord;
    if (word == null) return;
    if (state.savedWordIds.contains(word.vocabularyId)) return;

    await _repository.saveWord(word: word, language: language);
    state = state.copyWith(savedWordIds: {...state.savedWordIds, word.vocabularyId});
  }
}

/// Provider thu cong — KHONG code-gen, KHONG family (tranh van de equality
/// voi List). Man hinh goi .start(words) trong initState.
final learningSessionProvider =
    StateNotifierProvider.autoDispose<LearningSessionNotifier, LearningSessionState>((ref) {
  final repository = ref.watch(vocabularyRepositoryProvider);
  return LearningSessionNotifier(repository);
});