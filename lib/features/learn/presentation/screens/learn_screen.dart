import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math' as math;
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'package:chinesemate/core/utils/web_utils.dart';
import 'dart:convert';
import 'package:chinesemate/features/learn/presentation/widgets/learning_path.dart';
import 'package:chinesemate/features/learn/presentation/widgets/journey.dart';
import 'package:chinesemate/core/cache/app_cache.dart';

// ─── Design System ────────────────────────────────────────────
class _DS {
  static const bg = Color(0xFFF0F4FF);
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

class _LearnScreenState extends State<LearnScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _vocabulary = [];
  bool _isLoading = true;
  String _lang = 'zh';
  int _dailyGoal = 20;
  int _dailyDone = 0;
  int _totalWords = 0;
  int _reviewDue = 0;

  // Mood selector
  int _selectedMood = -1;
  static const _moods = [
    {'emoji': '😴', 'label': 'Mệt', 'desc': '5 từ nhẹ', 'tab': 0},
    {'emoji': '⚡', 'label': 'Năng lượng', 'desc': 'Quiz nhanh', 'tab': 1},
    {'emoji': '🎯', 'label': 'Tập trung', 'desc': 'Điền từ', 'tab': 3},
    {'emoji': '🎮', 'label': 'Vui', 'desc': 'Mini game', 'tab': 2},
  ];

  // Survival mode
  bool _survivalMode = false;
  int _survivalTimeLeft = 60;
  int _survivalCorrect = 0;
  Timer? _survivalTimer;

  // Calendar data — 30 ngày
  final List<double> _calendarData = List.generate(30, (i) => 0.0);

  // Yuki message
  String get _meiMessage {
    final h = DateTime.now().hour;
    if (_dailyDone >= _dailyGoal) return 'Tao tự hào mày lắm! Hoàn thành rồi đó 🎉';
    if (h < 10) return 'Dậy rồi à? Học sớm não nhớ lâu hơn đó mày 🧠';
    if (h < 14) return 'Giờ này chưa học à? Tao hỏi thật đó 😤';
    if (h < 20) return 'Còn $_reviewDue từ cần ôn, đừng bỏ qua nha mày!';
    return 'Khuya rồi, học ít thôi rồi ngủ nha! 😴';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadDailyVocabulary();
    _loadCalendarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _survivalTimer?.cancel();
    
    super.dispose();
  }

  Future<void> _loadDailyVocabulary() async {
  setState(() => _isLoading = true);
  try {
    final words = await AppCache.instance.getDailyVocab(lang: _lang);
    final reviewCount = (words ?? []).where((w) => w['is_review'] == true).length;
    if (mounted) setState(() {
      _vocabulary = words ?? _sampleWords;
      _reviewDue = reviewCount;
      _totalWords = _vocabulary.length;
    });
  } catch (_) {
    if (mounted) setState(() => _vocabulary = _sampleWords);
  } finally {
    if (mounted) setState(() => _isLoading = false);
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

  void _loadCalendarData() {
    // Simulate data — trong thực tế load từ storage
    final today = DateTime.now().day;
    for (int i = 0; i < today && i < 30; i++) {
      _calendarData[i] = (i % 3 == 0) ? 1.0 : (i % 3 == 1) ? 0.6 : 0.3;
    }
  }

  void _startSurvivalMode() {
    setState(() {
      _survivalMode = true;
      _survivalTimeLeft = 60;
      _survivalCorrect = 0;
    });
    _survivalTimer?.cancel();
    _survivalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _survivalTimeLeft--);
      if (_survivalTimeLeft <= 0) {
        _survivalTimer?.cancel();
        setState(() => _survivalMode = false);
        _showSurvivalResult();
      }
    });
    _tabController.animateTo(1); // Quiz tab
  }

  void _showSurvivalResult() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚡', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Survival Mode kết thúc!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
            const SizedBox(height: 8),
            Text('Bạn đã đúng $_survivalCorrect từ trong 60 giây!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8A8FA3), fontSize: 14)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { Navigator.pop(dialogCtx); _startSurvivalMode(); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B5FEF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Thử lại', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Đóng', style: TextStyle(color: Color(0xFF8A8FA3))),
            ),
          ]),
        ),
      ),
    );
  }

  final List<Map<String, dynamic>> _sampleWords = [
    {'chinese': '你好', 'pinyin': 'nǐ hǎo', 'vietnamese': 'Xin chào', 'example_zh': '你好，我叫Kai。', 'srs_level': 0, 'is_review': false},
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
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
if (MediaQuery.of(context).size.height > 700) _buildMeiMessage(),
if (MediaQuery.of(context).size.height > 700) _buildMoodSelector(),
_buildDailyRing(),
_buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B5FEF)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _vocabulary.isEmpty ? _buildEmpty() : FlashcardTab(
                        vocabulary: _vocabulary, lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin,
                        getMeaning: _getMeaning, getExample: _getExample,
                        getVocabId: _getVocabId, isReview: _isReview,
                        getSrsLevel: _getSrsLevel,
                        onStudied: _onStudied, onUpdateSRS: _updateSRS,
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : QuizTab(
                        vocabulary: _vocabulary, lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin, getMeaning: _getMeaning,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : ListenChooseTab(
                        vocabulary: _vocabulary, lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin, getMeaning: _getMeaning,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                      _vocabulary.isEmpty ? _buildEmpty() : FillBlankTab(
                        vocabulary: _vocabulary, lang: _lang,
                        getWord: _getWord, getPinyin: _getPinyin,
                        getMeaning: _getMeaning, getExample: _getExample,
                        onXpEarned: (xp) => _onStudied(),
                      ),
                      LearningPathTab(lang: _lang, onStartLearn: () => _tabController.animateTo(0)),
                      JourneyTab(lang: _lang),
                      VocabularyListTab(storage: _storage, lang: _lang),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A4E),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(children: [
        Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hành trình học tập',
                style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            SizedBox(height: 2),
            Text('Học tập', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          ]),
          const Spacer(),

          // Survival Mode button
          GestureDetector(
            onTap: _startSurvivalMode,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3D57).withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF3D57).withOpacity(0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _survivalMode
                    ? Text('⏱ $_survivalTimeLeft',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFF3D57)))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('⚡', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 4),
                        Text('60s', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFF3D57))),
                      ]),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          // Language toggle
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () { if (_lang != 'zh') { setState(() => _lang = 'zh'); _loadDailyVocabulary(); } },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _lang == 'zh' ? const Color(0xFF5B5FEF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('🇹🇼 中文',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _lang == 'zh' ? Colors.white : Colors.white54)),
                ),
              ),
              GestureDetector(
                onTap: () { if (_lang != 'en') { setState(() => _lang = 'en'); _loadDailyVocabulary(); } },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _lang == 'en' ? const Color(0xFF2979FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text('🇺🇸 EN',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _lang == 'en' ? Colors.white : Colors.white54)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loadDailyVocabulary,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Yuki MESSAGE ──────────────────────────────────────────
  Widget _buildMeiMessage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEDFE)),
          boxShadow: [BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF5B5FEF), Color(0xFF3B3FA8)]),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('美', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yuki', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF5B5FEF))),
            const SizedBox(height: 2),
            Text(_meiMessage, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E))),
          ])),
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFF00C853), shape: BoxShape.circle),
          ),
        ]),
      ),
    );
  }

  // ── MOOD SELECTOR ─────────────────────────────────────────
  Widget _buildMoodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Mood hôm nay?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8A8FA3))),
        ),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _moods.length,
            itemBuilder: (_, i) {
              final m = _moods[i];
              final isSelected = _selectedMood == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMood = isSelected ? -1 : i);
                  if (!isSelected) _tabController.animateTo(m['tab'] as int);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF5B5FEF) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? const Color(0xFF5B5FEF) : const Color(0xFFEEEDFE)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(m['emoji'] as String, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
  '${m['label']} · ${m['desc']}',
  style: TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700,
    color: isSelected ? Colors.white : const Color(0xFF1A1D2E),
  ),
),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── DAILY RING + CALENDAR ─────────────────────────────────
  Widget _buildDailyRing() {
    final progress = _dailyDone / _dailyGoal;
    final isDone = _dailyDone >= _dailyGoal;
    final ringColor = isDone
        ? const Color(0xFF00C853)
        : progress > 0.6
            ? const Color(0xFFFFD166)
            : const Color(0xFF5B5FEF);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).size.height > 700 ? 10 : 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          // Circular ring
          SizedBox(
            width: 60, height: 60,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 6,
                  backgroundColor: ringColor.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
              ),
              Text(isDone ? '🎉' : '$_dailyDone',
                  style: TextStyle(fontSize: isDone ? 20 : 16, fontWeight: FontWeight.w900, color: ringColor)),
            ]),
          ),
          const SizedBox(width: 14),

          // Stats
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isDone ? 'Hoàn thành hôm nay! 🎊' : 'Mục tiêu hôm nay',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: isDone ? const Color(0xFF00C853) : const Color(0xFF1A1D2E))),
            const SizedBox(height: 4),
            Text('$_dailyDone / $_dailyGoal từ · $_reviewDue cần ôn',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8FA3))),
            const SizedBox(height: 6),

            // 30-day calendar mini
            Row(children: List.generate(30, (i) {
              final val = _calendarData[i];
              Color dotColor;
              if (val >= 0.8) dotColor = const Color(0xFF00C853);
              else if (val >= 0.4) dotColor = const Color(0xFFFFD166);
              else if (val > 0) dotColor = const Color(0xFF5B5FEF).withOpacity(0.4);
              else dotColor = Colors.grey.shade200;

              final isToday = i == DateTime.now().day - 1;
              return Container(
                width: isToday ? 7 : 5,
                height: isToday ? 7 : 5,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: const Color(0xFF5B5FEF), width: 1.5) : null,
                ),
              );
            }),
            ),
            const SizedBox(height: 2),
            const Text('30 ngày qua', style: TextStyle(fontSize: 9, color: Color(0xFF8A8FA3))),
          ])),
        ]),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────
  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: const Color(0xFF5B5FEF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8A8FA3),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🃏', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Flashcard')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('⚡', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Quiz')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🎧', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Nghe')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('✍️', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Điền từ')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🗺️', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Lộ trình')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('🎯', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Hành trình')])),
          Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text('📝', style: TextStyle(fontSize: 13)), SizedBox(width: 4), Text('Từ đã học')])),
        ],
      ),
    ),
  );

  // ── EMPTY STATE ───────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 200, height: 200,
          child: Image.asset('assets/images/Studying-rafiki.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 16),

        // Thư từ tương lai
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEDFE)),
              boxShadow: [BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              const Text('📬', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              const Text('Thư từ bạn 6 tháng sau',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF5B5FEF))),
              const SizedBox(height: 6),
              Text(
                '"Này, tao của 6 tháng trước. Hôm nay tao đã nói chuyện được với sếp Đài Loan mà không cần phiên dịch. Bắt đầu từ hôm nay đi!"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5, fontStyle: FontStyle.italic),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: _loadDailyVocabulary,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5B5FEF), Color(0xFF3B3FA8)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Bắt đầu hành trình', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ]),
          ),
        ),
      ]),
    );
  }
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
        height: MediaQuery.of(context).size.height * 0.22,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: GestureDetector(
            onTap: _flip,
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (d) => setState(() => _dragOffset += Offset(d.delta.dx, 0)),
            onHorizontalDragEnd: (d) {
              if (_dragOffset.dx > 120) _goNext(isKnown: true);
              else if (_dragOffset.dx < -120) _goNext(isKnown: false);
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
      // Nút Chưa biết / Đã biết — backup cho vuốt
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _goNext(isKnown: false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _DS.redLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _DS.red.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❌', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('Chưa biết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.red)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _goNext(isKnown: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _DS.greenLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _DS.green.withOpacity(0.4)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('✅', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('Đã biết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.green)),
                ]),
              ),
            ),
          ),
        ]),
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
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          widget.getWord(word),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white,
height: 1.2, fontFamily: 'NotoSansTC',),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        widget.getPinyin(word),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Colors.white70, fontStyle: FontStyle.italic),
      ),
      const SizedBox(height: 12),
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
          style:  TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.white,
height: 1.2, fontFamily: 'NotoSansTC',),
          textAlign: TextAlign.center),
      if (widget.getExample(word).isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: Text(widget.getExample(word), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5, fontFamily: 'NotoSansTC',)),
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
              const SizedBox(height: 6),
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: _timeLeft / _currentMaxTime, minHeight: 8,
                        backgroundColor: timerColor.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(timerColor))),
                Positioned.fill(child: Center(child: Text('$_timeLeft',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: timerColor)))),
              ]),
              const SizedBox(height: 8),
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
                    const SizedBox(height: 6),
                    FittedBox(fit: BoxFit.scaleDown,
                        child: Text(widget.getWord(word), style: const TextStyle(fontSize: 28,
fontWeight: FontWeight.w500, color: Colors.white, height: 1))),
                    const SizedBox(height: 2),
                    Text(widget.getPinyin(word), style: const TextStyle(fontSize: 14, color: Colors.white60, fontStyle: FontStyle.italic)),
                  ]),
                ),
                if (_showScorePop) Positioned(top: 10, right: 16,
                    child: ScaleTransition(scale: _scorePopAnim,
                        child: Text(_scorePopText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.yellow,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)])))),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _buildLifeline(icon: '50/50', count: _lifeline5050, onTap: _use5050, enabled: _lifeline5050 > 0 && !_answered),
                const SizedBox(width: 12),
                _buildLifeline(icon: '⏭️ Bỏ qua', count: _lifelineSkip, onTap: _useSkip, enabled: _lifelineSkip > 0 && !_answered),
              ]),
              const SizedBox(height: 14),
               ...List.generate((options.length / 2).ceil(), (rowIndex) {
                final leftIndex = rowIndex * 2;
                final rightIndex = leftIndex + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildAnswerOption(leftIndex, options, correct)),
                        const SizedBox(width: 10),
                        if (rightIndex < options.length)
                          Expanded(child: _buildAnswerOption(rightIndex, options, correct))
                        else
                          const Expanded(child: SizedBox()),
                      ],
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

  Widget _buildAnswerOption(int i, List<String> options, String correct) {
    if (_hiddenOptions.contains(i)) {
      // Ô bị ẩn bởi 50:50 → giữ chỗ trống để lưới không vỡ
      return const SizedBox.shrink();
    }
    final isCorrect = options[i] == correct;
    final isSelected = _selectedAnswer == i;
    final isTimeout = _answered && _selectedAnswer == -1;
    Color bgColor = _DS.white;
    Color borderColor = Colors.grey.shade200;
    Color textColor = _DS.textDark;
    Widget? trailingIcon;
    if (_answered) {
      if (isCorrect) {
        bgColor = _DS.greenLight;
        borderColor = _DS.green;
        textColor = _DS.green;
        trailingIcon = const Icon(Icons.check_circle_rounded, color: _DS.green, size: 20);
      } else if (isSelected || (isTimeout && isCorrect)) {
        bgColor = _DS.redLight;
        borderColor = _DS.red;
        textColor = _DS.red;
        trailingIcon = const Icon(Icons.cancel_rounded, color: _DS.red, size: 20);
      }
    }
    return GestureDetector(
      onTap: () => _selectAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: _answered && (isCorrect || isSelected) ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: (_answered && isCorrect) ? _DS.green : (_answered && isSelected) ? _DS.red : _DS.bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(['A', 'B', 'C', 'D'][i],
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    color: (_answered && (isCorrect || isSelected)) ? Colors.white : _DS.textGrey))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(options[i],
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))),
          if (trailingIcon != null) trailingIcon,
        ]),
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
      webEval('''
  (function() {
    if (window._listenAudio) { window._listenAudio.pause(); }
    var a = new Audio("data:audio/mpeg;base64,$b64");
    a.playbackRate = ${widget.lang == 'en' ? 0.9 : 1.0};
    window._listenAudio = a;
    setTimeout(function() { a.play(); }, 500);
  })();
''');
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
        const SizedBox(height: 6),

        // Big play button
        GestureDetector(
          onTap: _playAudio,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _isPlaying ? _pulseAnim.value : 1.0,
              child: Container(
                width: 80, height: 80,
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
                      size: 40, color: Colors.white),
                  const SizedBox(height: 2),
                  Text(_isPlaying ? 'Đang phát...' : 'Nhấn để nghe',
                      style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Instruction
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(color: _DS.purpleLight, borderRadius: BorderRadius.circular(20)),
          child: Text(
            _hasPlayed
                ? 'Bạn vừa nghe từ nào? Chọn nghĩa đúng!'
                : widget.lang == 'en'
                    ? 'Nhấn nút để nghe từ tiếng Anh'
                    : 'Nhấn nút để nghe từ tiếng Trung',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.purple),
          ),
        ),
        const SizedBox(height: 6),

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
  int _currentRound = 0;
  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  bool _answered = false;
  bool _finished = false;
  bool _isLoadingParagraph = false;

  // Dữ liệu đoạn văn hiện tại
  String _paragraph = '';
  List<Map<String, dynamic>> _blanks = []; // [{index, word, meaning}]
  List<TextEditingController> _controllers = [];
  List<FocusNode> _focusNodes = [];
  List<bool?> _results = []; // null=chưa, true=đúng, false=sai
  List<bool> _showHints = [];
  int _hintsUsed = 0;

  // Tổng số rounds = vocabulary.length / 3 (làm tròn lên)
  int get _totalRounds => (widget.vocabulary.length / 3).ceil().clamp(1, 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNextParagraph());
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _loadNextParagraph() async {
    setState(() { _isLoadingParagraph = true; _paragraph = ''; _blanks = []; });

    // Chọn ngẫu nhiên 3 từ từ vocabulary
    final shuffled = List.from(widget.vocabulary)..shuffle();
    final selected = shuffled.take(3).toList();
    final wordList = selected.map((w) => {
      'word': widget.getWord(w),
      'meaning': widget.getMeaning(w),
    }).toList();

    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary/fill-blank-paragraph',
        data: {'word_list': wordList, 'lang': widget.lang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final paragraph = response.data['paragraph'] as String? ?? '';
      final blanksRaw = response.data['blanks'] as List? ?? [];
      final blanks = blanksRaw.map((b) => Map<String, dynamic>.from(b)).toList();

      // Khởi tạo controllers + focusNodes + results
      for (final c in _controllers) c.dispose();
      for (final f in _focusNodes) f.dispose();
      _controllers = List.generate(blanks.length, (_) => TextEditingController());
      _focusNodes = List.generate(blanks.length, (_) => FocusNode());
      _results = List.filled(blanks.length, null);
      _showHints = List.filled(blanks.length, false);
      _hintsUsed = 0;

      setState(() {
        _paragraph = paragraph;
        _blanks = blanks;
        _answered = false;
      });
    } catch (e) {
      // Fallback đơn giản nếu lỗi
      setState(() { _paragraph = '載入失敗，請重試。'; _blanks = []; });
    } finally {
      setState(() => _isLoadingParagraph = false);
    }
  }

  void _checkAnswer() {
    if (_answered || _blanks.isEmpty) return;
    int correctCount = 0;
    final newResults = <bool?>[];
    for (int i = 0; i < _blanks.length; i++) {
      final input = _controllers[i].text.trim();
      final correct = _blanks[i]['word'] as String;
      final isCorrect = input == correct;
      newResults.add(isCorrect);
      if (isCorrect) correctCount++;
    }
    final earned = (correctCount * 50 - _hintsUsed * 10).clamp(0, 200);
    setState(() {
      _results = newResults;
      _answered = true;
      _score += earned;
      if (correctCount == _blanks.length) {
        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
      } else {
        _combo = 0;
      }
    });
    if (correctCount == _blanks.length) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  void _next() {
    if (_currentRound + 1 >= _totalRounds) {
      setState(() => _finished = true);
      return;
    }
    setState(() { _currentRound++; _answered = false; });
    _loadNextParagraph();
  }

  void _restart() {
    setState(() {
      _currentRound = 0; _score = 0; _combo = 0;
      _maxCombo = 0; _answered = false; _finished = false;
    });
    _loadNextParagraph();
  }

  // Build đoạn văn với [1],[2],[3] highlight màu
  Widget _buildParagraph() {
    if (_paragraph.isEmpty) return const SizedBox.shrink();
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\[(\d+)\]');
    int last = 0;
    for (final match in regex.allMatches(_paragraph)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: _paragraph.substring(last, match.start),
          style:  TextStyle(fontSize: 16, color: _DS.textDark, height: 1.8, fontFamily: 'NotoSansTC'),
        ));
      }
      final idx = int.tryParse(match.group(1) ?? '1')! - 1;
      final result = idx < _results.length ? _results[idx] : null;
      final color = result == null ? _DS.orange : result == true ? _DS.green : _DS.red;
      spans.add(TextSpan(
        text: ' [${match.group(1)}] ',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, height: 1.8),
      ));
      last = match.end;
    }
    if (last < _paragraph.length) {
      spans.add(TextSpan(
        text: _paragraph.substring(last),
        style: TextStyle(fontSize: 16, color: _DS.textDark, height: 1.8, fontFamily: 'NotoSansTC'),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text('✍️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text('$_score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.green)),
            ]),
          ),
          const SizedBox(width: 8),
          if (_combo >= 2) Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]), borderRadius: BorderRadius.circular(12)),
            child: Text('🔥 x$_combo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const Spacer(),
          Text('${_currentRound + 1}/$_totalRounds', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (_currentRound + 1) / _totalRounds, minHeight: 6,
            backgroundColor: _DS.green.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(_DS.green),
          ),
        ),
        const SizedBox(height: 16),

        // Đoạn văn
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: _isLoadingParagraph
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [
                    CircularProgressIndicator(color: _DS.green, strokeWidth: 2),
                    SizedBox(height: 8),
                    Text('AI đang tạo bài tập...', style: TextStyle(fontSize: 12, color: _DS.textGrey)),
                  ]),
                ))
              : _buildParagraph(),
        ),
        const SizedBox(height: 16),

        // Input cho từng blank
        if (!_isLoadingParagraph && _blanks.isNotEmpty) ...[
          const Text('Điền từ còn thiếu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
          const SizedBox(height: 10),
          ..._blanks.asMap().entries.map((entry) {
            final i = entry.key;
            final blank = entry.value;
            final result = i < _results.length ? _results[i] : null;
            final borderColor = result == null
                ? _DS.green.withOpacity(0.4)
                : result == true ? _DS.green : _DS.red;
            final bgColor = result == null
                ? Colors.white
                : result == true ? _DS.greenLight : _DS.redLight;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: result == true ? _DS.green : result == false ? _DS.red : _DS.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                  ),
                  const SizedBox(width: 8),
                  Text(blank['meaning'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
                  const Spacer(),
                  // Nút gợi ý pinyin
                  if (!_answered) GestureDetector(
                    onTap: () {
                      setState(() { _showHints[i] = true; _hintsUsed++; });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _DS.yellowLight, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        _showHints[i] ? (widget.getPinyin(_blanks[i]['word'] != null
                            ? widget.vocabulary.firstWhere((w) => widget.getWord(w) == _blanks[i]['word'], orElse: () => {})
                            : {})) : '💡 -10đ',
                        style: const TextStyle(fontSize: 11, color: _DS.yellow, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_answered && result == false) ...[
                    const SizedBox(width: 8),
                    Text('→ ${blank['word']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _DS.red, fontFamily: 'NotoSansTC')),
                  ],
                ]),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    enabled: !_answered,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: result == true ? _DS.green : result == false ? _DS.red : Colors.black,
                      fontFamily: 'NotoSansTC',
                    ),
                    decoration: InputDecoration(
                      hintText: '輸入[${i + 1}]...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: bgColor,
                    ),
                    onSubmitted: (_) {
                      if (i < _focusNodes.length - 1) {
                        _focusNodes[i + 1].requestFocus();
                      } else {
                        _checkAnswer();
                      }
                    },
                  ),
                ),
              ]),
            );
          }).toList(),
        ],
        const SizedBox(height: 16),

        // Nút kiểm tra / tiếp theo
        if (!_isLoadingParagraph && _blanks.isNotEmpty)
          !_answered
              ? GestureDetector(
                  onTap: _checkAnswer,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Text('Kiểm tra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                )
              : GestureDetector(
                  onTap: _next,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Text(
                      _currentRound + 1 >= _totalRounds ? '🎉 Xem kết quả' : 'Bài tiếp theo →',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildResult() {
    final emoji = _score >= 400 ? '🏆' : _score >= 200 ? '💪' : '📚';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 56))),
        ),
        const SizedBox(height: 20),
        Text(_score >= 400 ? 'Xuất sắc!' : _score >= 200 ? 'Khá tốt!' : 'Cần luyện thêm!',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.textDark)),
        const SizedBox(height: 6),
        Text('Tổng $_totalRounds bài tập', style: const TextStyle(fontSize: 16, color: _DS.textGrey)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _buildStatBox('✍️ Điểm', '$_score', _DS.green, _DS.greenLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('🔥 Combo', '$_maxCombo', _DS.orange, _DS.orangeLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatBox('💡 Gợi ý', '$_hintsUsed', _DS.yellow, _DS.yellowLight)),
        ]),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _restart,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_DS.green, Color(0xFF2E7D32)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: _DS.green.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Làm lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, Color lightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}
  // ═══════════════════════════════════════════════════════════════
// VOCABULARY LIST TAB — Xem lại toàn bộ từ đã học
// ═══════════════════════════════════════════════════════════════
// PATCH cho VocabularyListTab trong learn_screen.dart
// Thay class VocabularyListTab + _VocabularyListTabState bằng code này

class VocabularyListTab extends StatefulWidget {
  final FlutterSecureStorage storage;
  final String lang;
  const VocabularyListTab({super.key, required this.storage, required this.lang});
  @override
  State<VocabularyListTab> createState() => _VocabularyListTabState();
}

class _VocabularyListTabState extends State<VocabularyListTab>
    with AutomaticKeepAliveClientMixin {   // ← THÊM keep-alive
  @override
  bool get wantKeepAlive => true;          // ← GIỮ state khi chuyển tab

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary?lang=${widget.lang}',
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
            (w['english'] ?? '').toLowerCase().contains(query) ||
            (w['vietnamese'] ?? '').toLowerCase().contains(query) ||
            (w['pinyin'] ?? '').toLowerCase().contains(query) ||
            (w['ipa'] ?? '').toLowerCase().contains(query);
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
    super.build(context); // ← BẮT BUỘC khi dùng AutomaticKeepAliveClientMixin
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
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
                  ? GestureDetector(
                      onTap: () { _searchCtrl.clear(); _applyFilter(); },
                      child: const Icon(Icons.clear_rounded, color: _DS.textGrey, size: 18))
                  : null,
            ),
          ),
        ),
      ),
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text('${_filtered.length} từ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textGrey)),
          const Spacer(),
          GestureDetector(
            onTap: _loadAll,
            child: const Icon(Icons.refresh_rounded, size: 18, color: _DS.textGrey),
          ),
        ]),
      ),
      Expanded(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _DS.orange))
            : _filtered.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('📭', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('Không tìm thấy từ nào',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _DS.textDark)),
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
                        decoration: BoxDecoration(
                          color: _DS.white,
                          borderRadius: BorderRadius.circular(_DS.radiusSm),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Row(children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_DS.orange.withOpacity(0.8), _DS.yellow.withOpacity(0.8)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: FittedBox(fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.lang == 'en'
                                      ? (w['english'] ?? w['chinese'] ?? '')
                                      : (w['chinese'] ?? ''),
                                  style: TextStyle(
                                    fontSize: widget.lang == 'en' ? 13 : 22,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: 'NotoSansTC',
                                  ),
                                ))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(w['vietnamese'] ?? '',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textDark)),
                            const SizedBox(height: 2),
                            Text(
                              widget.lang == 'en' ? (w['ipa'] ?? '') : (w['pinyin'] ?? ''),
                              style: const TextStyle(fontSize: 12, color: _DS.orange, fontStyle: FontStyle.italic),
                            ),
                            Builder(builder: (_) {
                              final example = widget.lang == 'en'
                                  ? (w['example_en'] ?? '')
                                  : (w['example_zh'] ?? '');
                              if (example.isEmpty) return const SizedBox.shrink();
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const SizedBox(height: 4),
                                Text(example,
                                    style: const TextStyle(fontSize: 11, color: _DS.textGrey),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]);
                            }),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            if (level.isNotEmpty) Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(8)),
                              child: Text(level,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.blue)),
                            ),
                            const SizedBox(height: 6),
                            Row(children: List.generate(5, (j) => Container(
                              width: 5, height: 5, margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: j < srs ? _DS.green : _DS.green.withOpacity(0.2),
                              ),
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
    return '''$emoji Tôi vừa hoàn thành Quiz $langLabel trên ChineseMate AI!
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
📱 Học $langLabel cùng tôi tại ChineseMate AI: https://taiwanmate-ai.github.io''';
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
    webCopyText(widget.text);
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _shareFacebook() {
    final encoded = Uri.encodeComponent(widget.text);
    webOpenUrl('https://www.facebook.com/sharer/sharer.php?u=https://taiwanmate-ai.github.io&quote=$encoded');}

  void _shareTwitter() {
    final encoded = Uri.encodeComponent(widget.text);
    webOpenUrl('https://twitter.com/intent/tweet?text=$encoded');}

  void _shareLine() {
    final encoded = Uri.encodeComponent(widget.text);
    webOpenUrl('https://social-plugins.line.me/lineit/share?url=https://taiwanmate-ai.github.io&text=$encoded');}

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

