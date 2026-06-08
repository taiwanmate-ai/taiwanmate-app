import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math' as math;
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:convert';
import 'package:taiwanmate_ai/features/learn/presentation/widgets/learning_path.dart';

// ─── Design System ────────────────────────────────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const yellow = Color(0xFFFFB300);
  static const yellowLight = Color(0xFFFFF8E1);
  static const purple = Color(0xFF7C4DFF);
  static const purpleLight = Color(0xFFEDE7F6);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── Topic data ───────────────────────────────────────────────
const _topics = [
  {'label': 'Công việc', 'icon': '💼', 'color': 0xFF2979FF},
  {'label': 'Nhà hàng', 'icon': '🍜', 'color': 0xFFFF6B35},
  {'label': 'Bệnh viện', 'icon': '🏥', 'color': 0xFFFF3D57},
  {'label': 'Giao thông', 'icon': '🚌', 'color': 0xFF00C853},
  {'label': 'Mua sắm', 'icon': '🛍️', 'color': 0xFF7C4DFF},
  {'label': 'Tất cả', 'icon': '📚', 'color': 0xFFFFB300},
];

// ═══════════════════════════════════════════════════════════════
// LEARN SCREEN
// ═══════════════════════════════════════════════════════════════
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _vocabulary = [];
  bool _isLoading = true;
  String _lang = 'zh'; // 'zh' hoặc 'en'
  int _dailyGoal = 20;
  int _dailyDone = 0;
  int _totalWords = 0;
  int _reviewDue = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadDailyVocabulary();
    // Thêm vào initState() của LearnScreen
Timer.periodic(const Duration(minutes: 4), (_) async {
  try {
    await Dio().get('https://taiwanmate-backend-production.up.railway.app/health');
  } catch (_) {}
});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyVocabulary() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary/daily?limit=30&lang=$_lang',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final words = List<Map<String, dynamic>>.from(response.data);
      final reviewCount = words.where((w) => w['is_review'] == true).length;
      setState(() {
        _vocabulary = words;
        _reviewDue = reviewCount;
        _totalWords = words.length;
      });
    } catch (e) {
      setState(() => _vocabulary = _sampleWords);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSRS(String vocabularyId, bool known) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary/update-srs',
        data: {'vocabulary_id': vocabularyId, 'known': known},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {}
  }

  final List<Map<String, dynamic>> _sampleWords = [
    {'chinese': '你好', 'pinyin': 'nǐ hǎo', 'vietnamese': 'Xin chào', 'example_zh': '你好，我叫小明。', 'srs_level': 0, 'is_review': false},
    {'chinese': '謝謝', 'pinyin': 'xiè xiè', 'vietnamese': 'Cảm ơn', 'example_zh': '謝謝你的幫助。', 'srs_level': 0, 'is_review': false},
    {'chinese': '朋友', 'pinyin': 'péng yǒu', 'vietnamese': 'Bạn bè', 'example_zh': '他是我的好朋友。', 'srs_level': 0, 'is_review': false},
    {'chinese': '工作', 'pinyin': 'gōng zuò', 'vietnamese': 'Công việc', 'example_zh': '我的工作很忙。', 'srs_level': 0, 'is_review': false},
    {'chinese': '學習', 'pinyin': 'xué xí', 'vietnamese': 'Học tập', 'example_zh': '我每天學習中文。', 'srs_level': 0, 'is_review': false},
    {'chinese': '吃飯', 'pinyin': 'chī fàn', 'vietnamese': 'Ăn cơm', 'example_zh': '我們去吃飯吧。', 'srs_level': 0, 'is_review': false},
    {'chinese': '水', 'pinyin': 'shuǐ', 'vietnamese': 'Nước', 'example_zh': '我要喝水。', 'srs_level': 0, 'is_review': false},
    {'chinese': '台灣', 'pinyin': 'tái wān', 'vietnamese': 'Đài Loan', 'example_zh': '我在台灣工作。', 'srs_level': 0, 'is_review': false},
  ];

  String _getWord(Map<String, dynamic> w) {
  if (_lang == 'en') return w['english'] ?? w['word'] ?? w['chinese'] ?? '';
  return w['chinese'] ?? w['word'] ?? '';
 }
 String _getPinyin(Map<String, dynamic> w) {
  if (_lang == 'en') return w['ipa'] ?? w['pinyin'] ?? '';
  return w['pinyin'] ?? '';
 }
 String _getExample(Map<String, dynamic> w) {
  if (_lang == 'en') return w['example_en'] ?? w['example_zh'] ?? w['example'] ?? '';
  return w['example_zh'] ?? w['example'] ?? '';
 }
  String _getMeaning(Map<String, dynamic> w) => w['vietnamese'] ?? w['meaning'] ?? '';
  String _getVocabId(Map<String, dynamic> w) => w['vocabulary_id']?.toString() ?? w['id']?.toString() ?? '';
  bool _isReview(Map<String, dynamic> w) => w['is_review'] == true;
  int _getSrsLevel(Map<String, dynamic> w) => (w['srs_level'] as num?)?.toInt() ?? 0;

  void _onStudied() => setState(() => _dailyDone = math.min(_dailyDone + 1, _dailyGoal));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildStats(),
          _buildDailyGoal(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _DS.orange))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _vocabulary.isEmpty ? _buildEmpty() : FlashcardTab(
                        vocabulary: _vocabulary,
                        lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin,
                        getMeaning: _getMeaning, getExample: _getExample,
                        getVocabId: _getVocabId, isReview: _isReview,
                        getSrsLevel: _getSrsLevel,
                        onStudied: _onStudied, onUpdateSRS: _updateSRS,
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : QuizTab(
                        vocabulary: _vocabulary,
                        lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin, getMeaning: _getMeaning,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : ListenChooseTab(
                        vocabulary: _vocabulary,
                        lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin, getMeaning: _getMeaning,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : FillBlankTab(
                        vocabulary: _vocabulary,
                        lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin,
                        getMeaning: _getMeaning, getExample: _getExample,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                       LearningPathTab(
                         lang: _lang,
                         onStartLearn: () => _tabController.animateTo(0),
                      ),
                      VocabularyListTab(storage: _storage),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Text('Học tập', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.textDark, letterSpacing: -0.5)),
      const Spacer(),
      // Toggle ngôn ngữ
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () { if (_lang != 'zh') { setState(() => _lang = 'zh'); _loadDailyVocabulary(); } },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _lang == 'zh' ? _DS.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('🇹🇼 中文', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _lang == 'zh' ? Colors.white : _DS.textGrey)),
            ),
          ),
          GestureDetector(
            onTap: () { if (_lang != 'en') { setState(() => _lang = 'en'); _loadDailyVocabulary(); } },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _lang == 'en' ? _DS.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('🇺🇸 English', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _lang == 'en' ? Colors.white : _DS.textGrey)),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _loadDailyVocabulary,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
          child: const Icon(Icons.refresh_rounded, size: 18, color: _DS.textGrey),
        ),
      ),
    ]),
  );

  Widget _buildStats() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Row(children: [
      _buildStatChip('📚 $_totalWords từ hôm nay', _DS.blue, _DS.blueLight),
      const SizedBox(width: 8),
      if (_reviewDue > 0) _buildStatChip('🔄 $_reviewDue cần ôn', _DS.orange, _DS.orangeLight),
    ]),
  );

  Widget _buildStatChip(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
  );

  Widget _buildDailyGoal() {
    final progress = _dailyDone / _dailyGoal;
    final isDone = _dailyDone >= _dailyGoal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone ? _DS.greenLight : _DS.orangeLight,
          borderRadius: BorderRadius.circular(_DS.radiusSm),
        ),
        child: Row(children: [
          Text(isDone ? '🎉' : '🔥', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isDone ? 'Hoàn thành hôm nay!' : 'Mục tiêu hôm nay',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDone ? _DS.green : _DS.orange)),
              Text('$_dailyDone/$_dailyGoal từ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDone ? _DS.green : _DS.orange)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress, minHeight: 6,
                backgroundColor: (isDone ? _DS.green : _DS.orange).withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(isDone ? _DS.green : _DS.orange),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _DS.textGrey,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🃏', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Flashcard')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('⚡', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Quiz')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🎧', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Nghe')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('✍️', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Điền từ')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🗺️', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Lộ trình')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('📝', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Từ đã học')])),
        ],
      ),
    ),
  );

  Widget _buildTopicsTab() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Học theo chủ đề', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 6),
      Text('Từ vựng thực tế cho cuộc sống ở Đài Loan', style: TextStyle(fontSize: 13, color: _DS.textGrey)),
      const SizedBox(height: 16),
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.3,
          ),
          itemCount: _topics.length,
          itemBuilder: (_, i) {
            final t = _topics[i];
            final color = Color(t['color'] as int);
            return GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chủ đề "${t['label']}" sắp ra mắt! 🚀'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(_DS.radius),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Stack(children: [
                  Positioned(right: -8, bottom: -8,
                      child: Text(t['icon'] as String, style: TextStyle(fontSize: 56, color: Colors.white.withOpacity(0.15)))),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(t['icon'] as String, style: const TextStyle(fontSize: 28)),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t['label'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Sắp ra mắt', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
                      ]),
                    ]),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 100, height: 100,
          decoration: const BoxDecoration(color: _DS.orangeLight, shape: BoxShape.circle),
          child: const Center(child: Text('📚', style: TextStyle(fontSize: 48)))),
      const SizedBox(height: 20),
      const Text('Chưa có từ vựng nào', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 8),
      const Text('Dịch văn bản và bấm 🔖 để lưu từ vựng',
          textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, fontSize: 14)),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _loadDailyVocabulary,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]), borderRadius: BorderRadius.circular(20)),
          child: const Text('Tải lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// FLASHCARD TAB
// ═══════════════════════════════════════════════════════════════
class FlashcardTab extends StatefulWidget {
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

  const FlashcardTab({super.key, required this.vocabulary,required this.lang, required this.getWord,
      required this.getPinyin, required this.getMeaning, required this.getExample,
      required this.getVocabId, required this.isReview, required this.getSrsLevel,
      required this.onStudied, required this.onUpdateSRS});

  @override
  State<FlashcardTab> createState() => _FlashcardTabState();
}

class _FlashcardTabState extends State<FlashcardTab> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  late AnimationController _swipeCtrl;
  Offset _dragOffset = Offset.zero;
  bool _dragging = false;
  final Set<int> _known = {};
  final Set<int> _unknown = {};
  final Set<String> _studiedIds = {};

  static const _gradients = [
    [Color(0xFF2979FF), Color(0xFF1565C0)],
    [Color(0xFFE91E8C), Color(0xFFAD1457)],
    [Color(0xFF00C853), Color(0xFF2E7D32)],
    [Color(0xFFFF6B35), Color(0xFFE65100)],
    [Color(0xFF7C4DFF), Color(0xFF4527A0)],
    [Color(0xFFFFB300), Color(0xFFF57F17)],
  ];

  List<Color> get _gradient => _gradients[_currentIndex % _gradients.length];

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(duration: const Duration(milliseconds: 450), vsync: this);
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
    _swipeCtrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() { _flipCtrl.dispose(); _swipeCtrl.dispose(); super.dispose(); }

  void _flip() {
    if (_isFlipped) _flipCtrl.reverse(); else _flipCtrl.forward();
    setState(() => _isFlipped = !_isFlipped);
  }

  void _goNext({bool? isKnown}) {
    final word = widget.vocabulary[_currentIndex];
    final vocabId = widget.getVocabId(word);
    if (isKnown != null && !_studiedIds.contains(vocabId)) {
      _studiedIds.add(vocabId);
      widget.onUpdateSRS(vocabId, isKnown);
      widget.onStudied();
    }
    if (isKnown == true) _known.add(_currentIndex);
    else if (isKnown == false) _unknown.add(_currentIndex);
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.vocabulary.length;
      _isFlipped = false;
      _flipCtrl.reset();
      _dragOffset = Offset.zero;
    });
  }

  void _goPrev() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.vocabulary.length) % widget.vocabulary.length;
      _isFlipped = false;
      _flipCtrl.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.vocabulary[_currentIndex];
    final total = widget.vocabulary.length;
    final isReview = widget.isReview(word);
    final srsLevel = widget.getSrsLevel(word);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Text('${_currentIndex + 1} / $total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isReview ? _DS.orangeLight : _DS.blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(isReview ? '🔄 Ôn tập' : '🆕 Từ mới',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isReview ? _DS.orange : _DS.blue)),
              ),
              const SizedBox(width: 6),
              Row(children: List.generate(5, (i) => Container(
                width: 6, height: 6, margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: i < srsLevel ? _DS.green : _DS.green.withOpacity(0.2)),
              ))),
            ]),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('✅ ${_known.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.green))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _DS.redLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('❌ ${_unknown.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.red))),
            ]),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / total, minHeight: 6,
              backgroundColor: _gradient[0].withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(_gradient[0]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.arrow_back_rounded, size: 13, color: _DS.red.withOpacity(0.6)),
            const SizedBox(width: 4),
            Text('Chưa biết', style: TextStyle(fontSize: 11, color: _DS.red.withOpacity(0.6), fontWeight: FontWeight.w600)),
          ]),
          Text('Vuốt để đánh giá', style: TextStyle(fontSize: 11, color: _DS.textGrey.withOpacity(0.6))),
          Row(children: [
            Text('Đã biết', style: TextStyle(fontSize: 11, color: _DS.green.withOpacity(0.8), fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 13, color: _DS.green.withOpacity(0.8)),
          ]),
        ]),
      ),
      SizedBox(
        height: 260,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: GestureDetector(
            onTap: _flip,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) => setState(() => _dragOffset += Offset(d.delta.dx, 0)),
            onHorizontalDragEnd: (d) {
              if (_dragOffset.dx > 80) _goNext(isKnown: true);
              else if (_dragOffset.dx < -80) _goNext(isKnown: false);
              else setState(() => _dragOffset = Offset.zero);
              setState(() => _dragging = false);
            },
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (_, __) {
                final angle = _flipAnim.value * math.pi;
                final isBack = angle > math.pi / 2;
                final swipeAngle = _dragOffset.dx / 800;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle)
                    ..rotateZ(swipeAngle),
                  child: Stack(children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isBack ? [_gradient[1], _gradient[0]] : [_gradient[0], _gradient[1]],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: _gradient[0].withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -4)],
                      ),
                      child: isBack
                          ? Transform(alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(math.pi),
                              child: _buildBackFace(word))
                          : _buildFrontFace(word),
                    ),
                    if (_dragging && _dragOffset.dx.abs() > 30)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: (_dragOffset.dx > 0 ? _DS.green : _DS.red).withOpacity(0.15),
                            border: Border.all(color: _dragOffset.dx > 0 ? _DS.green : _DS.red, width: 3),
                          ),
                          child: Center(child: Text(
                            _dragOffset.dx > 0 ? '✅ Đã biết!' : '❌ Chưa biết',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                                color: _dragOffset.dx > 0 ? _DS.green : _DS.red),
                          )),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(children: [
          GestureDetector(
            onTap: _goPrev,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
              child: const Icon(Icons.arrow_back_rounded, size: 22, color: _DS.textDark),
            ),
          ),
           const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final word = widget.vocabulary[_currentIndex];
              final text = ShareHelper.buildFlashcardText(
                word: widget.getWord(word),
                pinyin: widget.getPinyin(word),
                meaning: widget.getMeaning(word),
                lang: widget.lang,
              );
              ShareHelper.show(context, text);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FF),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.share_rounded, size: 22, color: Color(0xFF2979FF)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _goNext(isKnown: null),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _gradient),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _gradient[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Tiếp theo', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildFrontFace(Map<String, dynamic> word) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
        child: Text(
          widget.lang == 'en' ? '🇺🇸 Tiếng Anh' : '🇹🇼 Tiếng Trung',
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      
      ),
      const SizedBox(height: 20),
      FittedBox(fit: BoxFit.scaleDown,
          child: Text(widget.getWord(word), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1))),
      const SizedBox(height: 12),
      Text(widget.getPinyin(word), style: const TextStyle(fontSize: 20, color: Colors.white70, fontStyle: FontStyle.italic)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.touch_app_rounded, size: 14, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text('Nhấn để xem nghĩa', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
      ]),
    ]),
  );

  Widget _buildBackFace(Map<String, dynamic> word) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
        child: const Text('Nghĩa tiếng Việt', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 20),
      Text(widget.getMeaning(word),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
          textAlign: TextAlign.center),
      if (widget.getExample(word).isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: Text(widget.getExample(word), textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5)),
        ),
      ],
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// QUIZ TAB
// ═══════════════════════════════════════════════════════════════
class QuizTab extends StatefulWidget {
  final List<Map<String, dynamic>> vocabulary;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final Function(int) onXpEarned;

  const QuizTab({super.key, required this.vocabulary, required this.lang, required this.getWord,
      required this.getPinyin, required this.getMeaning, required this.onXpEarned});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _finished = false;
  late List<Map<String, dynamic>> _shuffled;
  late List<List<String>> _options;
  static const _maxTime = 10;
  int _timeLeft = _maxTime;
  Timer? _timer;
  int _combo = 0;
  int _maxCombo = 0;
  int _lifeline5050 = 2;
  int _lifelineSkip = 2;
  Set<int> _hiddenOptions = {};
  late AnimationController _scorePopCtrl;
  late Animation<double> _scorePopAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _flashCtrl;
  late Animation<Color?> _flashAnim;
  String _scorePopText = '';
  bool _showScorePop = false;
  final List<Map<String, dynamic>> _wrongAnswers = [];

  bool get _isBossRound => _currentIndex == _shuffled.length - 1;
  int get _currentMaxTime => _isBossRound ? 5 : _maxTime;
  double get _comboMultiplier => _combo >= 7 ? 3.0 : _combo >= 5 ? 2.0 : _combo >= 3 ? 1.5 : 1.0;
  String get _comboLabel => _combo >= 7 ? '🔥🔥🔥 x3' : _combo >= 5 ? '🔥🔥 x2' : _combo >= 3 ? '🔥 x1.5' : '';

  @override
  void initState() {
    super.initState();
    _shuffled = List.from(widget.vocabulary)..shuffle();
    _generateOptions();
    _startTimer();
    _scorePopCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scorePopAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _scorePopCtrl, curve: Curves.elasticOut));
    _shakeCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);
    _flashCtrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _flashAnim = ColorTween(begin: Colors.transparent, end: Colors.transparent).animate(_flashCtrl);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scorePopCtrl.dispose();
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _generateOptions() {
    _options = [];
    for (final word in _shuffled) {
      final correct = widget.getMeaning(word);
      final others = widget.vocabulary.where((w) => widget.getMeaning(w) != correct)
          .map((w) => widget.getMeaning(w)).toList()..shuffle();
      final choices = [correct, ...others.take(3)]..shuffle();
      _options.add(choices);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = _currentMaxTime;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_answered) return;
      if (_timeLeft <= 1) { _timer?.cancel(); _onTimeout(); }
      else setState(() => _timeLeft--);
    });
  }

  void _onTimeout() {
    setState(() { _answered = true; _combo = 0; _selectedAnswer = -1; });
    _wrongAnswers.add(_shuffled[_currentIndex]);
    _flashRed();
    HapticFeedback.heavyImpact();
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    _timer?.cancel();
    final correct = widget.getMeaning(_shuffled[_currentIndex]);
    final isCorrect = _options[_currentIndex][index] == correct;
    int baseScore = _isBossRound ? 300 : 100;
    int timeBonus = _timeLeft * (_isBossRound ? 20 : 10);
    final earned = isCorrect ? ((baseScore + timeBonus) * _comboMultiplier).toInt() : 0;
    setState(() {
      _selectedAnswer = index; _answered = true;
      if (isCorrect) {
        _score += earned; _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        _scorePopText = '+$earned'; _showScorePop = true;
      } else { _combo = 0; _wrongAnswers.add(_shuffled[_currentIndex]); }
    });
    if (isCorrect) {
      _flashGreen(); HapticFeedback.lightImpact();
      _scorePopCtrl.forward(from: 0).then((_) => setState(() => _showScorePop = false));
      widget.onXpEarned(earned);
    } else { _flashRed(); _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reset()); HapticFeedback.heavyImpact(); }
  }

  void _flashGreen() {
    _flashAnim = ColorTween(begin: _DS.green.withOpacity(0.15), end: Colors.transparent).animate(_flashCtrl);
    _flashCtrl.forward(from: 0);
  }

  void _flashRed() {
    _flashAnim = ColorTween(begin: _DS.red.withOpacity(0.15), end: Colors.transparent).animate(_flashCtrl);
    _flashCtrl.forward(from: 0);
  }

  void _use5050() {
    if (_lifeline5050 <= 0 || _answered) return;
    final correct = widget.getMeaning(_shuffled[_currentIndex]);
    final wrongIndices = _options[_currentIndex].asMap().entries
        .where((e) => e.value != correct).map((e) => e.key).toList()..shuffle();
    setState(() { _hiddenOptions = {wrongIndices[0], wrongIndices[1]}; _lifeline5050--; });
  }

  void _useSkip() {
    if (_lifelineSkip <= 0 || _answered) return;
    _timer?.cancel();
    setState(() { _lifelineSkip--; _hiddenOptions = {}; });
    _next();
  }

  void _next() {
    _hiddenOptions = {};
    if (_currentIndex + 1 >= _shuffled.length) { setState(() => _finished = true); }
    else { setState(() { _currentIndex++; _selectedAnswer = null; _answered = false; }); _startTimer(); }
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _currentIndex = 0; _score = 0; _selectedAnswer = null;
      _answered = false; _finished = false; _combo = 0; _maxCombo = 0;
      _lifeline5050 = 2; _lifelineSkip = 2; _hiddenOptions = {};
      _wrongAnswers.clear(); _shuffled.shuffle(); _generateOptions();
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    final word = _shuffled[_currentIndex];
    final options = _options[_currentIndex];
    final correct = widget.getMeaning(word);
    final timerRatio = _timeLeft / _currentMaxTime;
    final timerColor = timerRatio > 0.5 ? _DS.green : timerRatio > 0.25 ? _DS.yellow : _DS.red;

    return AnimatedBuilder(
      animation: Listenable.merge([_flashCtrl, _shakeCtrl]),
      builder: (_, __) => Container(
        color: _flashAnim.value,
        child: Transform.translate(
          offset: Offset(_shakeAnim.value * math.sin(_shakeAnim.value * math.pi * 8) * 8, 0),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _DS.yellowLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Text('⭐', style: TextStyle(fontSize: 16)), const SizedBox(width: 4),
                    Text('$_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.yellow))]),
                ),
                const SizedBox(width: 8),
                if (_combo >= 3) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]), borderRadius: BorderRadius.circular(12)),
                  child: Text(_comboLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const Spacer(),
                Text('${_currentIndex + 1}/${_shuffled.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
              ]),
              const SizedBox(height: 12),
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: _timeLeft / _currentMaxTime, minHeight: 8,
                        backgroundColor: timerColor.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(timerColor))),
                Positioned.fill(child: Center(child: Text('$_timeLeft',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: timerColor)))),
              ]),
              const SizedBox(height: 14),
              if (_isBossRound) Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFF3D57), Color(0xFFB71C1C)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: _DS.red.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('👾', style: TextStyle(fontSize: 18)), SizedBox(width: 8),
                  Text('BOSS ROUND — x3 điểm!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
              Stack(children: [
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _isBossRound ? [const Color(0xFFFF3D57), const Color(0xFFB71C1C)] : [_DS.blue, const Color(0xFF1565C0)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: (_isBossRound ? _DS.red : _DS.blue).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Column(children: [
                    Text(_isBossRound ? '⚡ Từ khó nhất — Nghĩa là gì?' : 'Nghĩa của từ này là gì?',
                        style: const TextStyle(fontSize: 13, color: Colors.white70)),
                    const SizedBox(height: 12),
                    FittedBox(fit: BoxFit.scaleDown,
                        child: Text(widget.getWord(word), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, height: 1))),
                    const SizedBox(height: 6),
                    Text(widget.getPinyin(word), style: const TextStyle(fontSize: 18, color: Colors.white60, fontStyle: FontStyle.italic)),
                  ]),
                ),
                if (_showScorePop) Positioned(top: 10, right: 16,
                    child: ScaleTransition(scale: _scorePopAnim,
                        child: Text(_scorePopText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.yellow,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)])))),
              ]),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _buildLifeline(icon: '50/50', count: _lifeline5050, onTap: _use5050, enabled: _lifeline5050 > 0 && !_answered),
                const SizedBox(width: 12),
                _buildLifeline(icon: '⏭️ Bỏ qua', count: _lifelineSkip, onTap: _useSkip, enabled: _lifelineSkip > 0 && !_answered),
              ]),
              const SizedBox(height: 14),
              ...List.generate(options.length, (i) {
                if (_hiddenOptions.contains(i)) return const SizedBox.shrink();
                final isCorrect = options[i] == correct;
                final isSelected = _selectedAnswer == i;
                final isTimeout = _answered && _selectedAnswer == -1;
                Color bgColor = _DS.white; Color borderColor = Colors.grey.shade200; Color textColor = _DS.textDark;
                Widget? trailingIcon;
                if (_answered) {
                  if (isCorrect) { bgColor = _DS.greenLight; borderColor = _DS.green; textColor = _DS.green; trailingIcon = const Icon(Icons.check_circle_rounded, color: _DS.green, size: 22); }
                  else if (isSelected || (isTimeout && isCorrect)) { bgColor = _DS.redLight; borderColor = _DS.red; textColor = _DS.red; trailingIcon = const Icon(Icons.cancel_rounded, color: _DS.red, size: 22); }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _selectAnswer(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor, width: _answered && (isCorrect || isSelected) ? 2 : 1),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                      child: Row(children: [
                        Container(width: 28, height: 28,
                            decoration: BoxDecoration(color: (_answered && isCorrect) ? _DS.green : (_answered && isSelected) ? _DS.red : _DS.bg, borderRadius: BorderRadius.circular(8)),
                            child: Center(child: Text(['A', 'B', 'C', 'D'][i],
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                    color: (_answered && (isCorrect || isSelected)) ? Colors.white : _DS.textGrey)))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(options[i], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor))),
                        if (trailingIcon != null) trailingIcon,
                      ]),
                    ),
                  ),
                );
              }),
              if (_answered) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Text(_currentIndex + 1 >= _shuffled.length ? '🎉 Xem kết quả' : 'Câu tiếp theo →',
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLifeline({required String icon, required int count, required VoidCallback onTap, required bool enabled}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200), opacity: enabled ? 1.0 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _DS.orange.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.orange)),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _DS.orange))),
          ]),
        ),
      ),
    );
  }

  Widget _buildResult() {
    final total = _shuffled.length;
    final correct = total - _wrongAnswers.length;
    final percent = (correct / total * 100).round();
    final emoji = percent >= 80 ? '🏆' : percent >= 50 ? '💪' : '📚';
    final message = percent >= 80 ? 'Xuất sắc!' : percent >= 50 ? 'Khá tốt!' : 'Cần ôn thêm!';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(width: 120, height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle, boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56)))),
        const SizedBox(height: 20),
        Text(message, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.textDark)),
        const SizedBox(height: 6),
        Text('$percent% chính xác', style: const TextStyle(fontSize: 16, color: _DS.textGrey)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatBox('⭐ Điểm', '$_score', _DS.yellow, _DS.yellowLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('✅ Đúng', '$correct/$total', _DS.green, _DS.greenLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('🔥 Combo', '$_maxCombo', _DS.orange, _DS.orangeLight)),
        ]),
        const SizedBox(height: 20),
        if (_wrongAnswers.isNotEmpty) ...[
          const Align(alignment: Alignment.centerLeft,
              child: Text('Câu sai — ôn lại nhé:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.textDark))),
          const SizedBox(height: 10),
          ..._wrongAnswers.map((w) => Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _DS.red.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: _DS.redLight, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(widget.getWord(w), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.red)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.getMeaning(w), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _DS.textDark)),
                Text(widget.getPinyin(w), style: const TextStyle(fontSize: 12, color: _DS.orange, fontStyle: FontStyle.italic)),
              ])),
            ]),
          )),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: () {
            final text = ShareHelper.buildQuizText(
              score: _score,
              correct: total - _wrongAnswers.length,
              total: total,
              maxCombo: _maxCombo,
              lang: widget.lang,
            );
            ShareHelper.show(context, text);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.3)),
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.share_rounded, color: Color(0xFF2979FF), size: 20),
              SizedBox(width: 8),
              Text('Chia sẻ kết quả', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2979FF))),
            ]),
          ),
        ),
        GestureDetector(
          onTap: _restart,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20), SizedBox(width: 8),
                Text('Làm lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// LISTEN & CHOOSE TAB — Nghe TTS → chọn nghĩa đúng
// ═══════════════════════════════════════════════════════════════
class ListenChooseTab extends StatefulWidget {
  final List<Map<String, dynamic>> vocabulary;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final Function(int) onXpEarned;

  const ListenChooseTab({super.key, required this.vocabulary, required this.lang, required this.getWord,
      required this.getPinyin, required this.getMeaning, required this.onXpEarned});

  @override
  State<ListenChooseTab> createState() => _ListenChooseTabState();
}

class _ListenChooseTabState extends State<ListenChooseTab> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  late List<Map<String, dynamic>> _shuffled;
  late List<List<String>> _options;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _answered = false;
  bool _finished = false;
  bool _isPlaying = false;
  bool _hasPlayed = false;
  int _combo = 0;
  int _maxCombo = 0;
  final List<Map<String, dynamic>> _wrongAnswers = [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _shuffled = List.from(widget.vocabulary)..shuffle();
    _generateOptions();
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    // Tự phát âm khi vào
    WidgetsBinding.instance.addPostFrameCallback((_) => _playAudio());
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  void _generateOptions() {
    _options = [];
    for (final word in _shuffled) {
      final correct = widget.getMeaning(word);
      final others = widget.vocabulary.where((w) => widget.getMeaning(w) != correct)
          .map((w) => widget.getMeaning(w)).toList()..shuffle();
      final choices = [correct, ...others.take(3)]..shuffle();
      _options.add(choices);
    }
  }

  Future<void> _playAudio() async {
    if (_isPlaying) return;
    if (!mounted) return;
    setState(() => _isPlaying = true);
    _pulseCtrl.repeat(reverse: true);
    try {
      final token = await _storage.read(key: 'access_token');
      final word = widget.getWord(_shuffled[_currentIndex]);
      print('TTS đọc từ: $word');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60), responseType: ResponseType.bytes));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts',
        data: {'text': word, 'lang': widget.lang == 'en' ? 'en-US' : 'zh-TW', 'slow': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final b64 = base64Encode(response.data as List<int>);
      js.context.callMethod('eval', ['''
        (function() {
          if (window._listenAudio) { window._listenAudio.pause(); }
          var a = new Audio("data:audio/mpeg;base64,$b64");
          a.playbackRate = 0.65;
          window._listenAudio = a;
          setTimeout(function() { a.play(); }, 500);
        })();
      ''']);
      if (mounted) setState(() => _hasPlayed = true);
    } catch (e) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        try {
          await _playAudio();
        } catch (_) {
          setState(() => _hasPlayed = true);
        }
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 4000));
      if (mounted) {
        setState(() => _isPlaying = false);
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    }
  }

  void _selectAnswer(int index) {
    if (_answered || !_hasPlayed) return;
    final correct = widget.getMeaning(_shuffled[_currentIndex]);
    final isCorrect = _options[_currentIndex][index] == correct;
    final earned = isCorrect ? (100 + (_combo * 20)).toInt() : 0;
    setState(() {
      _selectedAnswer = index; _answered = true;
      if (isCorrect) {
        _score += earned; _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
      } else { _combo = 0; _wrongAnswers.add(_shuffled[_currentIndex]); }
    });
    if (isCorrect) { HapticFeedback.lightImpact(); widget.onXpEarned(earned); }
    else HapticFeedback.heavyImpact();
  }

  void _next() {
    if (_currentIndex + 1 >= _shuffled.length) { setState(() => _finished = true); return; }
    setState(() {
      _currentIndex++; _selectedAnswer = null; _answered = false; _hasPlayed = false;
    });
    _playAudio();
  }

  void _restart() {
    setState(() {
      _currentIndex = 0; _score = 0; _selectedAnswer = null;
      _answered = false; _finished = false; _hasPlayed = false;
      _combo = 0; _maxCombo = 0; _wrongAnswers.clear();
      _shuffled.shuffle(); _generateOptions();
    });
    _playAudio();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    final options = _options[_currentIndex];
    final correct = widget.getMeaning(_shuffled[_currentIndex]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Header score
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _DS.purpleLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Text('🎧', style: TextStyle(fontSize: 16)), const SizedBox(width: 4),
              Text('$_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.purple))]),
          ),
          const SizedBox(width: 8),
          if (_combo >= 2) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.purple, Color(0xFF4527A0)]), borderRadius: BorderRadius.circular(12)),
            child: Text('🎵 x$_combo combo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const Spacer(),
          Text('${_currentIndex + 1}/${_shuffled.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_currentIndex + 1) / _shuffled.length, minHeight: 6,
                backgroundColor: _DS.purple.withOpacity(0.15), valueColor: const AlwaysStoppedAnimation<Color>(_DS.purple))),
        const SizedBox(height: 32),

        // Big play button
        GestureDetector(
          onTap: _playAudio,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _isPlaying ? _pulseAnim.value : 1.0,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPlaying
                        ? [const Color(0xFF7C4DFF), const Color(0xFF4527A0)]
                        : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (_isPlaying ? _DS.purple : Colors.grey).withOpacity(0.4),
                    blurRadius: _isPlaying ? 30 : 12, spreadRadius: _isPlaying ? 4 : 0,
                  )],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                      size: 56, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(_isPlaying ? 'Đang phát...' : 'Nhấn để nghe',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Instruction
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: _DS.purpleLight, borderRadius: BorderRadius.circular(20)),
          child: Text(
            _hasPlayed ? 'Bạn vừa nghe từ nào? Chọn nghĩa đúng!' : 'Nhấn nút để nghe từ tiếng Trung',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.purple),
          ),
        ),
        const SizedBox(height: 24),

        // Answer options
        ...List.generate(options.length, (i) {
          final isCorrect = options[i] == correct;
          final isSelected = _selectedAnswer == i;
          Color bgColor = _DS.white; Color borderColor = Colors.grey.shade200; Color textColor = _DS.textDark;
          Widget? trailingIcon;
          if (_answered) {
            if (isCorrect) { bgColor = _DS.greenLight; borderColor = _DS.green; textColor = _DS.green; trailingIcon = const Icon(Icons.check_circle_rounded, color: _DS.green, size: 22); }
            else if (isSelected) { bgColor = _DS.redLight; borderColor = _DS.red; textColor = _DS.red; trailingIcon = const Icon(Icons.cancel_rounded, color: _DS.red, size: 22); }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _selectAnswer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: _answered && (isCorrect || isSelected) ? 2 : 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Row(children: [
                  Container(width: 28, height: 28,
                      decoration: BoxDecoration(color: (_answered && isCorrect) ? _DS.green : (_answered && isSelected) ? _DS.red : _DS.bg, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text(['A', 'B', 'C', 'D'][i],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                              color: (_answered && (isCorrect || isSelected)) ? Colors.white : _DS.textGrey)))),
                  const SizedBox(width: 12),
                  Expanded(child: Text(options[i], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor))),
                  if (trailingIcon != null) trailingIcon,
                ]),
              ),
            ),
          );
        }),

        // Nếu đã trả lời → hiện từ tiếng Trung + nút tiếp theo
        if (_answered) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _DS.purpleLight, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _DS.purple.withOpacity(0.3))),
            child: Row(children: [
              GestureDetector(onTap: _playAudio,
                  child: Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _DS.purple, shape: BoxShape.circle),
                      child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.getWord(_shuffled[_currentIndex]),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _DS.purple)),
                Text(widget.getPinyin(_shuffled[_currentIndex]),
                    style: const TextStyle(fontSize: 14, color: _DS.textGrey, fontStyle: FontStyle.italic)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _next,
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.purple, Color(0xFF4527A0)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.purple.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Text(_currentIndex + 1 >= _shuffled.length ? '🎉 Xem kết quả' : 'Câu tiếp theo →',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildResult() {
    final total = _shuffled.length;
    final correct = total - _wrongAnswers.length;
    final percent = (correct / total * 100).round();
    final emoji = percent >= 80 ? '🏆' : percent >= 50 ? '💪' : '📚';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(width: 120, height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.purple, Color(0xFF4527A0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle, boxShadow: [BoxShadow(color: _DS.purple.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56)))),
        const SizedBox(height: 20),
        Text(percent >= 80 ? 'Tai nghe tốt lắm!' : percent >= 50 ? 'Luyện thêm nhé!' : 'Nghe nhiều hơn nào!',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.textDark)),
        const SizedBox(height: 6),
        Text('$percent% chính xác', style: const TextStyle(fontSize: 16, color: _DS.textGrey)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatBox('🎧 Điểm', '$_score', _DS.purple, _DS.purpleLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('✅ Đúng', '$correct/$total', _DS.green, _DS.greenLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('🎵 Combo', '$_maxCombo', _DS.orange, _DS.orangeLight)),
        ]),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _restart,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.purple, Color(0xFF4527A0)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.purple.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20), SizedBox(width: 8),
                Text('Nghe lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// FILL BLANK TAB — Điền từ vào chỗ trống
// ═══════════════════════════════════════════════════════════════
class FillBlankTab extends StatefulWidget {
  final List<Map<String, dynamic>> vocabulary;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final String Function(Map<String, dynamic>) getExample;
  final Function(int) onXpEarned;

  const FillBlankTab({super.key, required this.vocabulary, required this.lang, required this.getWord,
      required this.getPinyin, required this.getMeaning, required this.getExample, required this.onXpEarned});

  @override
  State<FillBlankTab> createState() => _FillBlankTabState();
}

class _FillBlankTabState extends State<FillBlankTab> {
  late List<Map<String, dynamic>> _shuffled;
  int _currentIndex = 0;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _answered = false;
  bool _isCorrect = false;
  bool _finished = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showHint = false;
  int _hintsUsed = 0;
  final List<Map<String, dynamic>> _wrongAnswers = [];

  @override
  void initState() {
    super.initState();
      _shuffled = List.from(widget.vocabulary)
        .where((w) => widget.getExample(w).isNotEmpty)
        .cast<Map<String, dynamic>>()
        .toList()..shuffle();
    // fallback nếu không đủ từ có ví dụ
    if (_shuffled.length < 3) _shuffled = List.from(widget.vocabulary)..shuffle();
  }

  @override
  void dispose() { _controller.dispose(); _focusNode.dispose(); super.dispose(); }

  // Tạo câu có blank — thay từ cần học bằng ___
  String _buildBlankSentence(Map<String, dynamic> word) {
    final example = widget.getExample(word);
    final chinese = widget.getWord(word);
    if (example.contains(chinese)) {
      return example.replaceFirst(chinese, '___');
    }
    // Nếu câu ví dụ không chứa từ → tạo câu đơn giản
    return widget.lang == 'en'
    ? 'The word is "___, meaning ${widget.getMeaning(word)}."'
    : '這個詞是「___」，意思是 ${widget.getMeaning(word)}。';
  }

  // Gợi ý: hiện pinyin
  String _getHint(Map<String, dynamic> word) => widget.getPinyin(word);

  void _checkAnswer() {
    if (_answered) return;
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    final correct = widget.getWord(_shuffled[_currentIndex]);
    final isCorrect = input == correct;
    final earned = isCorrect ? (100 + (_combo * 15) - (_hintsUsed * 20)).clamp(10, 200) : 0;
    setState(() {
      _answered = true; _isCorrect = isCorrect;
      if (isCorrect) {
        _score += earned; _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
      } else { _combo = 0; _wrongAnswers.add(_shuffled[_currentIndex]); }
    });
    if (isCorrect) { HapticFeedback.lightImpact(); widget.onXpEarned(earned); }
    else HapticFeedback.heavyImpact();
  }

  void _next() {
    if (_currentIndex + 1 >= _shuffled.length) { setState(() => _finished = true); return; }
    setState(() {
      _currentIndex++; _answered = false; _isCorrect = false;
      _showHint = false; _hintsUsed = 0;
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _restart() {
    setState(() {
      _currentIndex = 0; _score = 0; _combo = 0; _maxCombo = 0;
      _answered = false; _isCorrect = false; _finished = false;
      _showHint = false; _hintsUsed = 0; _wrongAnswers.clear();
      _shuffled.shuffle();
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    final word = _shuffled[_currentIndex];
    final blankSentence = _buildBlankSentence(word);
    final correct = widget.getWord(word);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [const Text('✍️', style: TextStyle(fontSize: 16)), const SizedBox(width: 4),
              Text('$_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.green))]),
          ),
          const SizedBox(width: 8),
          if (_combo >= 2) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]), borderRadius: BorderRadius.circular(12)),
            child: Text('🔥 x$_combo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const Spacer(),
          Text('${_currentIndex + 1}/${_shuffled.length}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_currentIndex + 1) / _shuffled.length, minHeight: 6,
                backgroundColor: _DS.green.withOpacity(0.15), valueColor: const AlwaysStoppedAnimation<Color>(_DS.green))),
        const SizedBox(height: 24),

        // Instruction
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(10)),
                  child: const Text('✍️ Điền từ còn thiếu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.green))),
            ]),
            const SizedBox(height: 12),
            // Nghĩa tiếng Việt — gợi ý
            Row(children: [
              const Text('Nghĩa: ', style: TextStyle(fontSize: 13, color: _DS.textGrey, fontWeight: FontWeight.w600)),
              Text(widget.getMeaning(word), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
            ]),
            const SizedBox(height: 12),
            // Câu có blank
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(blankSentence,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _DS.textDark, height: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Hint button
        if (!_answered)
          GestureDetector(
            onTap: () {
              setState(() { _showHint = true; _hintsUsed++; });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: _DS.yellowLight, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _DS.yellow.withOpacity(0.4))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_rounded, size: 16, color: _DS.yellow),
                const SizedBox(width: 6),
                Text(_showHint ? 'Gợi ý: ${_getHint(word)}' : 'Hiện gợi ý (-20đ)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.yellow)),
              ]),
            ),
          ),
        const SizedBox(height: 16),

        // Input field
        if (!_answered)
          Container(
  decoration: BoxDecoration(
    color: Colors.white, borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _DS.green.withOpacity(0.4), width: 2),
    boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
  ),
  child: TextField(
    controller: _controller,
    focusNode: _focusNode,
    autofocus: true,
    cursorColor: _DS.green,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
    textAlign: TextAlign.center,
    decoration: InputDecoration(
      hintText: '輸入答案...',
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      filled: true,
      fillColor: Colors.white,
    ),
    onSubmitted: (_) => _checkAnswer(),
  ),
),

        // Answer feedback
        if (_answered) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCorrect ? _DS.greenLight : _DS.redLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _isCorrect ? _DS.green : _DS.red, width: 2),
            ),
            child: Column(children: [
              Text(_isCorrect ? '🎉 Chính xác!' : '❌ Sai rồi!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _isCorrect ? _DS.green : _DS.red)),
              const SizedBox(height: 8),
              if (!_isCorrect) ...[
                const Text('Đáp án đúng:', style: TextStyle(fontSize: 13, color: _DS.textGrey)),
                const SizedBox(height: 4),
                Text(correct, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _DS.red)),
                Text(widget.getPinyin(word), style: const TextStyle(fontSize: 14, color: _DS.textGrey, fontStyle: FontStyle.italic)),
              ],
            ]),
          ),
        ],

        const SizedBox(height: 16),

        // Buttons
        if (!_answered)
          GestureDetector(
            onTap: _checkAnswer,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_rounded, color: Colors.white, size: 22), SizedBox(width: 8),
                Text('Kiểm tra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          )
        else
          GestureDetector(
            onTap: _next,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Text(_currentIndex + 1 >= _shuffled.length ? '🎉 Xem kết quả' : 'Câu tiếp theo →',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildResult() {
    final total = _shuffled.length;
    final correct = total - _wrongAnswers.length;
    final percent = (correct / total * 100).round();
    final emoji = percent >= 80 ? '🏆' : percent >= 50 ? '💪' : '📚';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(width: 120, height: 120,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle, boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))]),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56)))),
        const SizedBox(height: 20),
        Text(percent >= 80 ? 'Viết quá đỉnh!' : percent >= 50 ? 'Tập viết thêm nhé!' : 'Cần luyện viết nhiều hơn!',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.textDark)),
        const SizedBox(height: 6),
        Text('$percent% chính xác', style: const TextStyle(fontSize: 16, color: _DS.textGrey)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatBox('✍️ Điểm', '$_score', _DS.green, _DS.greenLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('✅ Đúng', '$correct/$total', _DS.blue, _DS.blueLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('🔥 Combo', '$_maxCombo', _DS.orange, _DS.orangeLight)),
        ]),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _restart,
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20), SizedBox(width: 8),
                Text('Làm lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
  Widget _buildStatBox(String label, String value, Color color, Color lightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
  // ═══════════════════════════════════════════════════════════════
// VOCABULARY LIST TAB — Xem lại toàn bộ từ đã học
// ═══════════════════════════════════════════════════════════════
class VocabularyListTab extends StatefulWidget {
  final FlutterSecureStorage storage;
  const VocabularyListTab({super.key, required this.storage});
  @override
  State<VocabularyListTab> createState() => _VocabularyListTabState();
}

class _VocabularyListTabState extends State<VocabularyListTab> {
  List<Map<String, dynamic>> _allWords = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();
  String _filterLevel = 'Tất cả';

  final _levels = ['Tất cả', 'A1', 'A2', 'B1', 'B2', 'C1'];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _allWords = List<Map<String, dynamic>>.from(response.data);
        _filtered = _allWords;
      });
    } catch (e) {
      setState(() => _allWords = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allWords.where((w) {
        final matchLevel = _filterLevel == 'Tất cả' || w['tocfl_level'] == _filterLevel;
        final matchSearch = query.isEmpty ||
            (w['chinese'] ?? '').toLowerCase().contains(query) ||
            (w['vietnamese'] ?? '').toLowerCase().contains(query) ||
            (w['pinyin'] ?? '').toLowerCase().contains(query);
        return matchLevel && matchSearch;
      }).toList();
    });
  }

  void _setLevel(String level) {
    setState(() => _filterLevel = level);
    _applyFilter();
  }

  int _getSrsLevel(Map<String, dynamic> w) => (w['srs_level'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 14, color: _DS.textDark),
            decoration: InputDecoration(
              hintText: 'Tìm từ vựng...',
              hintStyle: TextStyle(color: _DS.textGrey.withOpacity(0.7)),
              prefixIcon: const Icon(Icons.search_rounded, color: _DS.textGrey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? GestureDetector(onTap: () { _searchCtrl.clear(); _applyFilter(); },
                      child: const Icon(Icons.clear_rounded, color: _DS.textGrey, size: 18))
                  : null,
            ),
          ),
        ),
      ),
      // Level filter
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _levels.map((level) => GestureDetector(
            onTap: () => _setLevel(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _filterLevel == level ? _DS.orange : _DS.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _filterLevel == level ? _DS.orange : Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(level, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _filterLevel == level ? Colors.white : _DS.textGrey)),
            ),
          )).toList()),
        ),
      ),
      // Count
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text('${_filtered.length} từ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textGrey)),
          const Spacer(),
          GestureDetector(onTap: _loadAll,
              child: const Icon(Icons.refresh_rounded, size: 18, color: _DS.textGrey)),
        ]),
      ),
      // List
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _DS.orange))
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('📭', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Không tìm thấy từ nào', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _DS.textDark)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final w = _filtered[i];
                      final srs = _getSrsLevel(w);
                      final level = w['tocfl_level']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                        child: Row(children: [
                          // Chinese word
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_DS.orange.withOpacity(0.8), _DS.yellow.withOpacity(0.8)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: FittedBox(fit: BoxFit.scaleDown,
                                child: Text(w['chinese'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)))),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(w['vietnamese'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textDark)),
                            const SizedBox(height: 2),
                            Text(w['pinyin'] ?? '', style: const TextStyle(fontSize: 12, color: _DS.orange, fontStyle: FontStyle.italic)),
                            if ((w['example_zh'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(w['example_zh'], style: const TextStyle(fontSize: 11, color: _DS.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ])),
                          // Right side: level + SRS
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (level.isNotEmpty) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(8)),
                              child: Text(level, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.blue)),
                            ),
                            const SizedBox(height: 6),
                            Row(children: List.generate(5, (j) => Container(
                              width: 5, height: 5, margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(shape: BoxShape.circle,
                                  color: j < srs ? _DS.green : _DS.green.withOpacity(0.2)),
                            ))),
                          ]),
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}
// ═══════════════════════════════════════════════════════════════
// SHARE HELPER — thêm vào cuối learn_screen.dart
// ═══════════════════════════════════════════════════════════════

// ignore: avoid_web_libraries_in_flutter

class ShareHelper {
  /// Share kết quả Quiz
  static String buildQuizText({
    required int score,
    required int correct,
    required int total,
    required int maxCombo,
    required String lang,
  }) {
    final percent = (correct / total * 100).round();
    final emoji = percent >= 80 ? '🏆' : percent >= 50 ? '💪' : '📚';
    final langLabel = lang == 'en' ? 'tiếng Anh' : 'tiếng Trung';
    return '''$emoji Tôi vừa hoàn thành Quiz $langLabel trên TaiwanMate AI!
⭐ Điểm: $score
✅ Đúng: $correct/$total ($percent%)
🔥 Combo cao nhất: $maxCombo
📱 Học $langLabel miễn phí tại: https://taiwanmate-ai.github.io''';
  }

  /// Share từ hay trên Flashcard
  static String buildFlashcardText({
    required String word,
    required String pinyin,
    required String meaning,
    required String lang,
  }) {
    final langLabel = lang == 'en' ? 'tiếng Anh' : 'tiếng Trung';
    return '''📖 Từ $langLabel hay tôi học được hôm nay:
${lang == 'en' ? '🔤' : '🀄'} $word
${lang == 'en' ? '🔊' : '🎵'} $pinyin
🇻🇳 $meaning
📱 Học $langLabel cùng tôi tại TaiwanMate AI: https://taiwanmate-ai.github.io''';
  }

  /// Hiện bottom sheet share
  static void show(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(text: text),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  final String text;
  const _ShareSheet({required this.text});

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _copied = false;

  void _copy() {
    html.window.navigator.clipboard?.writeText(widget.text);
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareFacebook() {
    final encoded = Uri.encodeComponent(widget.text);
    html.window.open(
      'https://www.facebook.com/sharer/sharer.php?u=https://taiwanmate-ai.github.io&quote=$encoded',
      '_blank',
    );
  }

  void _shareTwitter() {
    final encoded = Uri.encodeComponent(widget.text);
    html.window.open(
      'https://twitter.com/intent/tweet?text=$encoded',
      '_blank',
    );
  }

  void _shareLine() {
    final encoded = Uri.encodeComponent(widget.text);
    html.window.open(
      'https://social-plugins.line.me/lineit/share?url=https://taiwanmate-ai.github.io&text=$encoded',
      '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Chia sẻ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
        const SizedBox(height: 16),

        // Preview text
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            widget.text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D2E), height: 1.6),
          ),
        ),
        const SizedBox(height: 20),

        // Share buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // Copy
            Expanded(child: GestureDetector(
              onTap: _copy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _copied ? const Color(0xFFE8F5E9) : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _copied ? const Color(0xFF00C853) : Colors.grey.shade200,
                  ),
                ),
                child: Column(children: [
                  Icon(
                    _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    color: _copied ? const Color(0xFF00C853) : const Color(0xFF8A8FA3),
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _copied ? 'Đã copy!' : 'Copy',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _copied ? const Color(0xFF00C853) : const Color(0xFF8A8FA3),
                    ),
                  ),
                ]),
              ),
            )),
            const SizedBox(width: 10),

            // Facebook
            Expanded(child: GestureDetector(
              onTap: _shareFacebook,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.3)),
                ),
                child: const Column(children: [
                  Text('f', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1877F2))),
                  SizedBox(height: 4),
                  Text('Facebook', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1877F2))),
                ]),
              ),
            )),
            const SizedBox(width: 10),

            // Twitter/X
            Expanded(child: GestureDetector(
              onTap: _shareTwitter,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Column(children: [
                  Text('𝕏', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
                  SizedBox(height: 4),
                  Text('Twitter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
                ]),
              ),
            )),
            const SizedBox(width: 10),

            // LINE
            Expanded(child: GestureDetector(
              onTap: _shareLine,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00C300).withOpacity(0.3)),
                ),
                child: const Column(children: [
                  Text('LINE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00C300))),
                  SizedBox(height: 4),
                  Text('LINE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00C300))),
                ]),
              ),
            )),
          ]),
        ),
        const SizedBox(height: 20),

        // Cancel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Đóng', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF8A8FA3))),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
