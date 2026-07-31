import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart';
import 'unit_practice_screen.dart';

class _CurDS {
  static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const teal = Color(0xFF00B894);
  static const tealDark = Color(0xFF00806A);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const amber = Color(0xFFFFB300);
  static const amberLight = Color(0xFFFFF8E1);
  static const gold = Color(0xFFF5A623);
}

const _curBaseUrl = 'https://taiwanmate-backend-production.up.railway.app/api/v1/curriculum';

enum _CurStage { pickLang, levelList, unitList, unitDetail, practice, complete }

class CurriculumTab extends StatefulWidget {
  const CurriculumTab({super.key});
  @override
  State<CurriculumTab> createState() => _CurriculumTabState();
}

class _CurriculumTabState extends State<CurriculumTab> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  _CurStage _stage = _CurStage.pickLang;
  bool _loading = false;
  String? _errorMsg;

  String? _language;
  List<Map<String, dynamic>> _levels = [];
  String? _selectedLevel;
  List<Map<String, dynamic>> _units = [];
  Map<String, dynamic>? _unitDetail;

  int _practiceStep = 0; // 0: ôn nhanh, 1: từ mới, 2: ngữ pháp, 3: quiz
  int _wordIndex = 0;
  bool _showMeaning = false;
  int _quizIndex = 0;
  int? _quizSelected;
  List<Map<String, dynamic>> _quizPool = [];

  Future<Options> get _authOptions async {
    final token = await _storage.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _pickLanguage(String lang) async {
    setState(() { _language = lang; _loading = true; _errorMsg = null; });
    try {
      final res = await _dio.get('$_curBaseUrl/$lang/levels', options: await _authOptions);
      setState(() {
        _levels = List<Map<String, dynamic>>.from(res.data['levels']);
        _stage = _CurStage.levelList;
        _loading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi tải danh sách cấp độ'; _loading = false; });
    }
  }

  Future<void> _pickLevel(String level) async {
    setState(() { _selectedLevel = level; _loading = true; _errorMsg = null; });
    try {
      final res = await _dio.get('$_curBaseUrl/$_language/$level/units', options: await _authOptions);
      setState(() {
        _units = List<Map<String, dynamic>>.from(res.data['units']);
        _stage = _CurStage.unitList;
        _loading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi tải danh sách bài học'; _loading = false; });
    }
  }

  Future<void> _openUnit(Map<String, dynamic> unit) async {
    if (unit['status'] == 'locked') return;
    if (unit['is_vip_locked'] == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen()));
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final res = await _dio.get('$_curBaseUrl/unit/${unit['unit_id']}', options: await _authOptions);
      setState(() {
        _unitDetail = res.data;
        _stage = _CurStage.unitDetail;
        _loading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi tải nội dung bài học'; _loading = false; });
    }
  }

  void _startPractice() {
    final reviewWords = List<Map<String, dynamic>>.from(_unitDetail!['review_words'] ?? []);
    setState(() {
      _practiceStep = reviewWords.isNotEmpty ? 0 : 1;
      _stage = _CurStage.practice;
    });
  }

  void _nextWord() {
    final words = List<Map<String, dynamic>>.from(_unitDetail!['words']);
    if (_wordIndex < words.length - 1) {
      setState(() { _wordIndex++; _showMeaning = false; });
    } else {
      final hasGrammar = _unitDetail!['grammar'] != null;
      setState(() { _practiceStep = hasGrammar ? 2 : 3; });
    }
  }

  List<String> _quizOptions(Map<String, dynamic> correct) {
    final others = _quizPool.where((w) => w['id'] != correct['id']).toList()..shuffle();
    final opts = [correct['meaning'], ...others.take(3).map((w) => w['meaning'])];
    opts.shuffle();
    return List<String>.from(opts);
  }

  void _selectQuizAnswer(int index, String answer, String correctMeaning) {
    if (_quizSelected != null) return;
    setState(() => _quizSelected = index);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_quizIndex < _quizPool.length - 1) {
        setState(() { _quizIndex++; _quizSelected = null; });
      } else {
        _completeUnit();
      }
    });
  }

  Future<void> _completeUnit() async {
    setState(() => _loading = true);
    try {
      final res = await _dio.post('$_curBaseUrl/unit/${_unitDetail!['unit_id']}/complete', options: await _authOptions);
      setState(() {
        _unitDetail!['_nextUnitId'] = res.data['next_unit_id'];
        _unitDetail!['_levelCompleted'] = res.data['level_completed'];
        _stage = _CurStage.complete;
        _loading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi lưu tiến độ'; _loading = false; });
    }
  }

  void _backToUnitList() {
    setState(() { _stage = _CurStage.unitList; });
    _pickLevel(_selectedLevel!);
  }

  void _resetAll() {
    setState(() {
      _stage = _CurStage.pickLang;
      _language = null;
      _levels = [];
      _selectedLevel = null;
      _units = [];
      _unitDetail = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _CurDS.teal));
    switch (_stage) {
      case _CurStage.pickLang: return _buildPickLang();
      case _CurStage.levelList: return _buildLevelList();
      case _CurStage.unitList: return _buildUnitList();
      case _CurStage.unitDetail: return _buildUnitDetail();
      case _CurStage.practice: return _buildPractice();
      case _CurStage.complete: return _buildComplete();
    }
  }

  Widget _buildPickLang() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      const Text('📚', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 12),
      const Text('Lộ trình học', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _CurDS.textDark)),
      const SizedBox(height: 6),
      const Text('Học tuần tự theo chủ đề, đúng chuẩn CEFR/TOCFL',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _CurDS.textGrey)),
      const SizedBox(height: 28),
      _buildLangCard('zh', '🇹🇼', 'Tiếng Trung', '5 cấp độ · 59 buổi học'),
      const SizedBox(height: 12),
      _buildLangCard('en', '🇺🇸', 'Tiếng Anh', '6 cấp độ · 60 buổi học'),
    ]),
  );

  Widget _buildLangCard(String lang, String flag, String title, String sub) => GestureDetector(
    onTap: () => _pickLanguage(lang),
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _CurDS.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CurDS.teal.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _CurDS.textDark)),
          Text(sub, style: const TextStyle(fontSize: 11, color: _CurDS.textGrey)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _CurDS.teal),
      ]),
    ),
  );

  Widget _buildLevelList() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      _buildBackButton(_resetAll),
      const SizedBox(height: 16),
      ..._levels.map((l) {
        final total = l['total_units'] as int;
        final completed = l['completed_units'] as int;
        return GestureDetector(
          onTap: () => _pickLevel(l['level']),
          child: Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _CurDS.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _CurDS.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(l['level'], style: const TextStyle(fontWeight: FontWeight.w900, color: _CurDS.teal))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cấp ${l['level']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _CurDS.textDark)),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: total > 0 ? completed / total : 0, minHeight: 5,
                        backgroundColor: _CurDS.teal.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation(_CurDS.teal))),
                const SizedBox(height: 2),
                Text('$completed/$total buổi', style: const TextStyle(fontSize: 11, color: _CurDS.textGrey)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _CurDS.textGrey),
            ]),
          ),
        );
      }),
    ]),
  );

  Widget _buildUnitList() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      _buildBackButton(() => setState(() => _stage = _CurStage.levelList)),
      const SizedBox(height: 8),
      Text('Cấp $_selectedLevel', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _CurDS.textDark)),
      const SizedBox(height: 16),
      ..._units.map((u) {
        final locked = u['status'] == 'locked';
        final vipLocked = u['is_vip_locked'] == true;
        final completed = u['status'] == 'completed';
        return GestureDetector(
          onTap: () => _openUnit(u),
          child: Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: locked ? Colors.grey.shade100 : _CurDS.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: completed ? _CurDS.green.withOpacity(0.3) : Colors.grey.shade200),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: completed ? _CurDS.greenLight : (vipLocked ? _CurDS.amberLight : _CurDS.teal.withOpacity(0.1)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  completed ? Icons.check_rounded : (locked || vipLocked ? Icons.lock_rounded : Icons.play_arrow_rounded),
                  size: 16, color: completed ? _CurDS.green : (vipLocked ? _CurDS.amber : _CurDS.teal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(u['topic_vi'], style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: locked ? _CurDS.textGrey : _CurDS.textDark,
              ))),
              if (vipLocked) const Text('⭐', style: TextStyle(fontSize: 14)),
            ]),
          ),
        );
      }),
    ]),
  );

  Widget _buildUnitDetail() {
    final u = _unitDetail!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildBackButton(_backToUnitList),
        const SizedBox(height: 16),
        Text(u['topic_translated'] ?? '', style: const TextStyle(fontSize: 13, color: _CurDS.textGrey)),
        Text(u['topic_vi'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _CurDS.textDark)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _CurDS.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('⏱ ~${u['estimated_minutes']} phút · ${(u['words'] as List).length} từ mới',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CurDS.teal)),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _CurDS.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Text(u['intro_text'] ?? '', style: const TextStyle(fontSize: 14, color: _CurDS.textDark, height: 1.6)),
        ),
        const SizedBox(height: 16),
        _buildSessionGoals(u),
        const SizedBox(height: 24),
        _buildCta('Bắt đầu buổi học', _startPractice),
      ]),
    );
  }
  Widget _buildSessionGoals(Map<String, dynamic> u) {
    final wordCount = (u['words'] as List).length;
    final hasGrammar = u['grammar'] != null;
    final goals = <String>[
      'Học $wordCount từ vựng mới',
      if (hasGrammar) 'Nắm 1 điểm ngữ pháp: ${u['grammar']['title'] ?? ''}',
      'Luyện tập qua Quiz và Điền từ',
    ];
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _CurDS.teal.withOpacity(0.06), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('🎯 Mục tiêu buổi học', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _CurDS.tealDark)),
        const SizedBox(height: 8),
        ...goals.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  ', style: TextStyle(fontSize: 13, color: _CurDS.teal, fontWeight: FontWeight.w800)),
            Expanded(child: Text(g, style: const TextStyle(fontSize: 13, color: _CurDS.textDark, height: 1.4))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildPractice() {
    switch (_practiceStep) {
      case 0: return _buildReviewStep();
      case 1: return _buildWordsPracticeGroup();
      case 2: return _buildGrammarStep();
      default: return _buildQuizPracticeGroup();
    }
  }

  Widget _buildReviewStep() {
    final reviewWords = List<Map<String, dynamic>>.from(_unitDetail!['review_words'] ?? []);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildProgressDots(0),
        const SizedBox(height: 20),
        const Text('🔄 Ôn nhanh buổi trước', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _CurDS.textDark)),
        const SizedBox(height: 16),
        ...reviewWords.map((w) => Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _CurDS.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Expanded(child: Text(w['word'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _CurDS.textDark))),
            Text(w['meaning'] ?? '', style: const TextStyle(fontSize: 13, color: _CurDS.textGrey)),
          ]),
        )),
        const SizedBox(height: 10),
        _buildWeakTopicReminder(),
        const SizedBox(height: 20),
        _buildCta('Tiếp tục', () => setState(() => _practiceStep = 1)),
      ]),
    );
  }

  Map<String, dynamic>? _weakTopic;
  bool _weakTopicLoaded = false;

  Future<void> _loadWeakTopic() async {
    if (_weakTopicLoaded) return;
    _weakTopicLoaded = true;
    try {
      final res = await _dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/mastery/next-action',
        options: await _authOptions,
      );
      if (mounted && res.data['has_suggestion'] == true) {
        setState(() => _weakTopic = res.data);
      }
    } catch (e) {}
  }

  Widget _buildWeakTopicReminder() {
    if (!_weakTopicLoaded) {
      _loadWeakTopic();
    }
    if (_weakTopic == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _CurDS.amberLight, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Text('💡', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bạn đang yếu chủ đề này', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A6D00))),
          Text(_weakTopic!['label'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _CurDS.textDark)),
        ])),
      ]),
    );
  }

  

  Widget _buildGrammarStep() {
    final g = _unitDetail!['grammar'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildProgressDots(2),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _CurDS.amberLight, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📖 ${g['title'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF8A6D00))),
            const SizedBox(height: 10),
            Text(g['explanation'] ?? '', style: const TextStyle(fontSize: 13, color: _CurDS.textDark, height: 1.6)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Text(g['formula'] ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _CurDS.tealDark)),
            ),
            const SizedBox(height: 12),
            ...List<String>.from(g['examples'] ?? []).map((ex) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $ex', style: const TextStyle(fontSize: 13, color: _CurDS.textDark)),
            )),
            if (g['common_mistake'] != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('⚠️ ${g['common_mistake']}', style: const TextStyle(fontSize: 12, color: Color(0xFF993C1D), height: 1.5)),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _buildCta('Luyện tập', () => setState(() => _practiceStep = 3)),
      ]),
    );
  }

  
  Widget _buildComplete() {
    final levelCompleted = _unitDetail!['_levelCompleted'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 30),
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [_CurDS.green, Color(0xFF00A344)]), shape: BoxShape.circle),
          child: const Center(child: Text('🎉', style: TextStyle(fontSize: 44))),
        ),
        const SizedBox(height: 20),
        Text(levelCompleted ? 'Hoàn thành cấp $_selectedLevel!' : 'Hoàn thành buổi học!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _CurDS.textDark)),
        const SizedBox(height: 24),
        _buildCta(levelCompleted ? 'Về danh sách cấp độ' : 'Buổi tiếp theo →', () {
          if (levelCompleted) {
            setState(() => _stage = _CurStage.levelList);
            _pickLanguage(_language!);
          } else {
            _backToUnitList();
          }
        }),
      ]),
    );
  }

  static const _stepLabels = ['Ôn tập', 'Từ mới', 'Ngữ pháp', 'Luyện tập'];

  Widget _buildProgressDots(int current) => Column(children: [
    Row(
      children: List.generate(4, (i) => Expanded(
        child: Container(
          height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i <= current ? _CurDS.teal : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      )),
    ),
    const SizedBox(height: 6),
    Row(
      children: List.generate(4, (i) => Expanded(
        child: Text(_stepLabels[i], textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                color: i <= current ? _CurDS.teal : _CurDS.textGrey)),
      )),
    ),
  ]);

  Widget _buildBackButton(VoidCallback onTap) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      onTap: onTap,
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_back_rounded, size: 18, color: _CurDS.textGrey),
        SizedBox(width: 4),
        Text('Quay lại', style: TextStyle(fontSize: 13, color: _CurDS.textGrey)),
      ]),
    ),
  );

  Widget _buildCta(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_CurDS.teal, _CurDS.tealDark]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _CurDS.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
    ),
  );
  String _cGetWord(Map<String, dynamic> w) => w['word']?.toString() ?? '';
  String _cGetPinyin(Map<String, dynamic> w) => w['pinyin_or_ipa']?.toString() ?? '';
  String _cGetMeaning(Map<String, dynamic> w) => w['meaning']?.toString() ?? '';
  String _cGetExample(Map<String, dynamic> w) => w['example']?.toString() ?? '';
  String _cGetVocabId(Map<String, dynamic> w) => w['id']?.toString() ?? '';

  Future<void> _cUpdateSRS(String vocabularyId, bool known) async {
    if (vocabularyId.isEmpty) return;
    try {
      final token = await _storage.read(key: 'access_token');
      await _dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary/update-srs',
        data: {'vocabulary_id': vocabularyId, 'known': known},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  Widget _buildWordsPracticeGroup() {
    final words = List<Map<String, dynamic>>.from(_unitDetail!['words']);
    return UnitPracticeScreen(
      key: ValueKey('words_${_unitDetail!['unit_id']}'),
      words: words,
      lang: _language!,
      getWord: _cGetWord, getPinyin: _cGetPinyin, getMeaning: _cGetMeaning,
      getExample: _cGetExample, getVocabId: _cGetVocabId, onUpdateSRS: _cUpdateSRS,
      steps: const [PracticeStepType.flashcard, PracticeStepType.listen],
      onAllStepsComplete: () {
        final hasGrammar = _unitDetail!['grammar'] != null;
        setState(() => _practiceStep = hasGrammar ? 2 : 3);
      },
    );
  }

  Widget _buildQuizPracticeGroup() {
    final words = List<Map<String, dynamic>>.from(_unitDetail!['words']);
    return UnitPracticeScreen(
      key: ValueKey('quiz_${_unitDetail!['unit_id']}'),
      words: words,
      lang: _language!,
      getWord: _cGetWord, getPinyin: _cGetPinyin, getMeaning: _cGetMeaning,
      getExample: _cGetExample, getVocabId: _cGetVocabId, onUpdateSRS: _cUpdateSRS,
      steps: const [PracticeStepType.quiz, PracticeStepType.fillBlank],
      onAllStepsComplete: _completeUnit,
    );
  }
}