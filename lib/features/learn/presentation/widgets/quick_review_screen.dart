// ═══════════════════════════════════════════════════════════════
// QUICK REVIEW SCREEN
// File: lib/features/learn/presentation/widgets/quick_review_screen.dart
//
// Màn hình full-screen chứa 4 tab con: Flashcard / Quiz / Nghe / Điền từ
// Dùng từ vựng SRS chung (ôn tập hàng ngày), KHÔNG đổi logic bên trong
// 4 widget gốc — chỉ bọc lại thành 1 màn hình riêng có nút Back.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:chinesemate/features/learn/presentation/screens/learn_screen.dart'
    show FlashcardTab, QuizTab, ListenChooseTab, FillBlankTab;

class QuickReviewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> vocabulary;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final String Function(Map<String, dynamic>) getExample;
  final String Function(Map<String, dynamic>) getVocabId;
  final bool Function(Map<String, dynamic>) isReview;
  final int Function(Map<String, dynamic>) getSrsLevel;
  final VoidCallback onStudied;
  final Future<void> Function(String, bool) onUpdateSRS;
  final int initialTabIndex;

  const QuickReviewScreen({
    super.key,
    required this.vocabulary,
    required this.lang,
    required this.getWord,
    required this.getPinyin,
    required this.getMeaning,
    required this.getExample,
    required this.getVocabId,
    required this.isReview,
    required this.getSrsLevel,
    required this.onStudied,
    required this.onUpdateSRS,
    this.initialTabIndex = 0,
  });

  @override
  State<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends State<QuickReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _bg = Color(0xFFF0F4FF);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);
  static const _purple = Color(0xFF5B5FEF);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4, vsync: this, initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('Ôn tập nhanh',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: _purple,
          unselectedLabelColor: _textGrey,
          indicatorColor: _purple,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🃏', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Flashcard')])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('⚡', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Quiz')])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🎧', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Nghe')])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('✍️', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Điền từ')])),
          ],
        ),
      ),
      body: widget.vocabulary.isEmpty
          ? const Center(child: Text('Chưa có từ vựng để ôn tập'))
          : TabBarView(
              controller: _tabController,
              children: [
                FlashcardTab(
                  vocabulary: widget.vocabulary, lang: widget.lang,
                  getWord: widget.getWord, getPinyin: widget.getPinyin,
                  getMeaning: widget.getMeaning, getExample: widget.getExample,
                  getVocabId: widget.getVocabId, isReview: widget.isReview,
                  getSrsLevel: widget.getSrsLevel,
                  onStudied: widget.onStudied, onUpdateSRS: widget.onUpdateSRS,
                ),
                QuizTab(
                  vocabulary: widget.vocabulary, lang: widget.lang,
                  getWord: widget.getWord, getPinyin: widget.getPinyin, getMeaning: widget.getMeaning,
                  getVocabId: widget.getVocabId, onUpdateSRS: widget.onUpdateSRS,
                  onXpEarned: (xp) => widget.onStudied(),
                ),
                ListenChooseTab(
                  vocabulary: widget.vocabulary, lang: widget.lang,
                  getWord: widget.getWord, getPinyin: widget.getPinyin, getMeaning: widget.getMeaning,
                  getVocabId: widget.getVocabId, onUpdateSRS: widget.onUpdateSRS,
                  onXpEarned: (xp) => widget.onStudied(),
                ),
                FillBlankTab(
                  vocabulary: widget.vocabulary, lang: widget.lang,
                  getWord: widget.getWord, getPinyin: widget.getPinyin,
                  getMeaning: widget.getMeaning, getExample: widget.getExample,
                  getVocabId: widget.getVocabId, onUpdateSRS: widget.onUpdateSRS,
                  onXpEarned: (xp) => widget.onStudied(),
                ),
              ],
            ),
    );
  }
}