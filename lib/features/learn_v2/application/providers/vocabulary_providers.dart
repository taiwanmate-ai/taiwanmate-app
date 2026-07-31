import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/learn_v2/data/repositories/vocabulary_repository.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';

/// Repository provider — thu cong, khong code-gen.
/// Thay the @riverpod VocabularyRepository vocabularyRepository(...) truoc do.
final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  return VocabularyRepositoryImpl();
});

/// State ngon ngu dang chon cho Tab Hoc moi — thu cong bang StateProvider.
/// Thay the @riverpod class SelectedLearnLanguage truoc do.
final selectedLearnLanguageProvider = StateProvider<String>((ref) => 'zh');

/// Danh sach tu moi — thu cong bang FutureProvider.autoDispose.
/// Tu dong goi lai khi selectedLearnLanguageProvider doi gia tri (nho ref.watch).
/// Thay the @riverpod Future<List<VocabularyWord>> newWords(...) truoc do.
final newWordsProvider = FutureProvider.autoDispose<List<VocabularyWord>>((ref) async {
  final language = ref.watch(selectedLearnLanguageProvider);
  final repository = ref.watch(vocabularyRepositoryProvider);
  return repository.getNewWords(language: language);
});