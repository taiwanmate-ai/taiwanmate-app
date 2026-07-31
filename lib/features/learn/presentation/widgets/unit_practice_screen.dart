// ═══════════════════════════════════════════════════════════════
// UNIT PRACTICE SCREEN
// File: lib/features/learn/presentation/widgets/unit_practice_screen.dart
//
// Điều phối 2-4 bước luyện tập (Flashcard/Nghe/Quiz/Điền từ) theo thứ tự
// KHÓA TUẦN TỰ cho MỘT bộ từ vựng (ví dụ: từ của 1 bài trong Curriculum).
//
// QUAN TRỌNG: File này KHÔNG chứa logic vuốt/chạm/combo/animation nào cả.
// Nó chỉ hiển thị thanh tiến độ + gọi lại đúng widget gốc
// (FlashcardTab, QuizTab, ListenChooseTab, FillBlankTab) đã có sẵn trong
// learn_screen.dart. Mọi trải nghiệm bên trong mỗi bước giữ nguyên 100%.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:chinesemate/features/learn/presentation/screens/learn_screen.dart'
    show FlashcardTab, QuizTab, ListenChooseTab, FillBlankTab;
import 'package:chinesemate/features/learn/presentation/widgets/stroke_practice_screen.dart';    

enum PracticeStepType { flashcard, listen, quiz, fillBlank }

extension _StepMeta on PracticeStepType {
  String get label {
    switch (this) {
      case PracticeStepType.flashcard: return 'Flashcard';
      case PracticeStepType.listen: return 'Nghe';
      case PracticeStepType.quiz: return 'Quiz';
      case PracticeStepType.fillBlank: return 'Điền từ';
    }
  }

  String get emoji {
    switch (this) {
      case PracticeStepType.flashcard: return '🗂️';
      case PracticeStepType.listen: return '🎧';
      case PracticeStepType.quiz: return '📝';
      case PracticeStepType.fillBlank: return '✍️';
    }
  }
}

class UnitPracticeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final String Function(Map<String, dynamic>) getExample;
  final String Function(Map<String, dynamic>) getVocabId;
  final Future<void> Function(String, bool) onUpdateSRS;
  final List<PracticeStepType> steps; // ví dụ: [flashcard, listen] hoặc [quiz, fillBlank]
  final VoidCallback onAllStepsComplete;

  const UnitPracticeScreen({
    super.key,
    required this.words,
    required this.lang,
    required this.getWord,
    required this.getPinyin,
    required this.getMeaning,
    required this.getExample,
    required this.getVocabId,
    required this.onUpdateSRS,
    required this.steps,
    required this.onAllStepsComplete,
  });

  @override
  State<UnitPracticeScreen> createState() => _UnitPracticeScreenState();
}

class _UnitPracticeScreenState extends State<UnitPracticeScreen> {
  int _activeIndex = 0;
  bool _showWriteOffer = false;

  static const _purple = Color(0xFF5B5FEF);
  static const _green = Color(0xFF00C853);
  static const _locked = Color(0xFFD8D8E8);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);

  void _onStepDone() {
    final isLastStep = _activeIndex + 1 >= widget.steps.length;
    // Sau bước "Nghe" (nếu có trong nhóm này), hiện đề nghị luyện viết — CHỈ áp dụng tiếng Trung
    final justFinishedListen = widget.steps[_activeIndex] == PracticeStepType.listen && widget.lang != 'en';
    if (justFinishedListen && !_showWriteOffer) {
      setState(() => _showWriteOffer = true);
      return;
    }
    if (isLastStep) {
      widget.onAllStepsComplete();
    } else {
      setState(() { _activeIndex++; _showWriteOffer = false; });
    }
  }

  void _continueAfterWriteOffer() {
    setState(() => _showWriteOffer = false);
    if (_activeIndex + 1 >= widget.steps.length) {
      widget.onAllStepsComplete();
    } else {
      setState(() => _activeIndex++);
    }
  }

  Widget _buildActiveStepWidget() {
    final type = widget.steps[_activeIndex];
    switch (type) {
      case PracticeStepType.flashcard:
        return FlashcardTab(
          key: ValueKey('flashcard_$_activeIndex'),
          vocabulary: widget.words,
          lang: widget.lang,
          getWord: widget.getWord,
          getPinyin: widget.getPinyin,
          getMeaning: widget.getMeaning,
          getExample: widget.getExample,
          getVocabId: widget.getVocabId,
          isReview: (_) => false,
          getSrsLevel: (_) => 0,
          onStudied: () {},
          onUpdateSRS: widget.onUpdateSRS,
          onComplete: _onStepDone,
        );
      case PracticeStepType.listen:
        return ListenChooseTab(
          key: ValueKey('listen_$_activeIndex'),
          vocabulary: widget.words,
          lang: widget.lang,
          getWord: widget.getWord,
          getPinyin: widget.getPinyin,
          getMeaning: widget.getMeaning,
          getVocabId: widget.getVocabId,
          onUpdateSRS: widget.onUpdateSRS,
          onXpEarned: (_) {},
          onFinished: _onStepDone,
        );
      case PracticeStepType.quiz:
        return QuizTab(
          key: ValueKey('quiz_$_activeIndex'),
          vocabulary: widget.words,
          lang: widget.lang,
          getWord: widget.getWord,
          getPinyin: widget.getPinyin,
          getMeaning: widget.getMeaning,
          getVocabId: widget.getVocabId,
          onUpdateSRS: widget.onUpdateSRS,
          onXpEarned: (_) {},
          onFinished: _onStepDone,
        );
      case PracticeStepType.fillBlank:
        return FillBlankTab(
          key: ValueKey('fillblank_$_activeIndex'),
          vocabulary: widget.words,
          lang: widget.lang,
          getWord: widget.getWord,
          getPinyin: widget.getPinyin,
          getMeaning: widget.getMeaning,
          getExample: widget.getExample,
          getVocabId: widget.getVocabId,
          onUpdateSRS: widget.onUpdateSRS,
          onXpEarned: (_) {},
          onFinished: _onStepDone,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStepTracker(),
        const SizedBox(height: 4),
        Expanded(child: _showWriteOffer ? _buildWriteOfferScreen() : _buildActiveStepWidget()),
      ],
    );
  }

  Widget _buildWriteOfferScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('✍️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Muốn luyện viết thêm không?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textDark),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Luyện viết nét chữ giúp nhớ lâu hơn — hoàn toàn không bắt buộc.',
              style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () async {
                for (final w in widget.words) {
                  final hanzi = widget.getWord(w);
                  final meaning = widget.getMeaning(w);
                  if (hanzi.isEmpty) continue;
                  final result = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => StrokePracticeScreen(hanzi: hanzi, meaning: meaning),
                  ));
                  if (result == 'exit') break; // User bấm Thoát → dừng hẳn vòng lặp
                }
                _continueAfterWriteOffer();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, Color(0xFF4842D6)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Luyện viết ngay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _continueAfterWriteOffer,
            child: const Text('Bỏ qua, học tiếp', style: TextStyle(color: _textGrey, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  // Thanh tiến độ ngang, hiển thị các bước đã xong / đang làm / khóa
  Widget _buildStepTracker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: List.generate(widget.steps.length, (i) {
          final type = widget.steps[i];
          final isDone = i < _activeIndex;
          final isCurrent = i == _activeIndex;
          final color = isDone ? _green : (isCurrent ? _purple : _locked);

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: isDone || isCurrent ? color : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : Text(type.emoji, style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                          color: isDone ? _green : (isCurrent ? _purple : _textGrey),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < widget.steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: isDone ? _green : _locked,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}