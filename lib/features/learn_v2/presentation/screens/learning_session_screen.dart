import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';
import 'package:chinesemate/features/learn_v2/application/providers/learning_session_provider.dart';
import 'package:chinesemate/features/learn_v2/presentation/widgets/learn_new/session_word_card.dart';
import 'package:chinesemate/features/learn_v2/presentation/widgets/learn_new/session_complete_view.dart';

class LearningSessionScreen extends ConsumerStatefulWidget {
  final List<VocabularyWord> words;
  final String language;

  const LearningSessionScreen({super.key, required this.words, required this.language});

  @override
  ConsumerState<LearningSessionScreen> createState() => _LearningSessionScreenState();
}

class _LearningSessionScreenState extends ConsumerState<LearningSessionScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // ref.read trong initState la an toan (khong nam trong build), khoi tao
    // dung 1 lan khi man hinh mo.
    Future.microtask(() => ref.read(learningSessionProvider.notifier).start(widget.words));
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(learningSessionProvider.notifier).saveCurrentWord(widget.language);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không lưu được từ này. Thử lại sau.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(learningSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: session.isEmpty
            ? const Text('Buổi học')
            : Text('${session.displayPosition} / ${session.totalCount}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!session.isEmpty && !session.isFinished)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: session.progressRatio,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${session.displayPosition} / ${session.totalCount}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                        Text('Còn ${session.totalCount - session.currentIndex} từ',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: session.isEmpty
                  ? const Center(child: Text('Không có từ nào để học.'))
                  : session.isFinished
                      ? SessionCompleteView(
                          totalLearned: session.totalCount,
                          savedCount: session.savedWordIds.length,
                          onBack: () => Navigator.of(context).pop(),
                        )
                      : SessionWordCard(
                          key: ValueKey(session.currentWord!.vocabularyId),
                          word: session.currentWord!,
                          language: widget.language,
                          isSaved: session.isCurrentWordSaved(),
                          isSaving: _isSaving,
                          onSave: _handleSave,
                          onNext: () => ref.read(learningSessionProvider.notifier).next(),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}