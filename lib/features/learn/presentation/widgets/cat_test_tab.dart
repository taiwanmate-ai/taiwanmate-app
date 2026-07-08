import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart';

class _CatDS {
  static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const yellowLight = Color(0xFFFFF8E1);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

const _baseUrl = 'https://taiwanmate-backend-production.up.railway.app/api/v1/cat-test';

const _genreLabels = {
  'dialogue': '💬 Hội thoại',
  'notice': '📢 Thông báo',
  'ad': '📰 Quảng cáo',
  'article': '📄 Bài viết',
  'letter': '✉️ Thư/Email',
};

enum _Stage { pickType, loading, intro, question, feedback, result }

class CatTestTab extends StatefulWidget {
  const CatTestTab({super.key});
  @override
  State<CatTestTab> createState() => _CatTestTabState();
}

class _CatTestTabState extends State<CatTestTab> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  bool? _isVip; // null = đang kiểm tra
  _Stage _stage = _Stage.pickType;

  @override
  void initState() {
    super.initState();
    _checkVip();
  }

  Future<void> _checkVip() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final res = await _dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/quota',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() => _isVip = res.data['is_vip'] == true);
    } catch (_) {
      if (mounted) setState(() => _isVip = false);
    }
  }
  String? _testType;
  bool _hasResumable = false;
  Map<String, dynamic>? _resumeData;

  String? _sessionId;
  Map<String, dynamic>? _currentPassage;
  int _questionsAnswered = 0;
  int _totalQuestions = 50;

  int? _selectedIndex;
  bool? _lastIsCorrect;
  String? _lastExplanation;

  String? _finalLevel;
  Map<String, dynamic>? _breakdown;
  String? _errorMsg;

  Future<Options> get _authOptions async {
    final token = await _storage.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _pickType(String type) async {
    setState(() { _testType = type; _stage = _Stage.loading; _errorMsg = null; });
    try {
      final res = await _dio.get('$_baseUrl/resume',
          queryParameters: {'test_type': type}, options: await _authOptions);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _hasResumable = data['resumable'] == true;
        _resumeData = _hasResumable ? data : null;
        _stage = _Stage.intro;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi kết nối. Thử lại nhé!'; _stage = _Stage.intro; _hasResumable = false; });
    }
  }

  Future<void> _startFresh() async {
    setState(() { _stage = _Stage.loading; _errorMsg = null; });
    try {
      final res = await _dio.post('$_baseUrl/start',
          data: {'test_type': _testType}, options: await _authOptions);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _sessionId = data['session_id'];
        _currentPassage = data['passage'];
        _questionsAnswered = data['questions_answered'];
        _totalQuestions = data['total_questions'];
        _selectedIndex = null;
        _stage = _Stage.question;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Không thể bắt đầu bài kiểm tra. Thử lại nhé!'; _stage = _Stage.intro; });
    }
  }

  void _continueResumed() {
    final data = _resumeData!;
    setState(() {
      _sessionId = data['session_id'];
      _currentPassage = data['passage'];
      _questionsAnswered = data['questions_answered'];
      _totalQuestions = data['total_questions'];
      _selectedIndex = null;
      _stage = _Stage.question;
    });
  }

  Future<void> _abandonAndRestart() async {
    if (_sessionId != null) {
      try {
        await _dio.post('$_baseUrl/abandon', data: {'session_id': _sessionId}, options: await _authOptions);
      } catch (_) {}
    }
    _startFresh();
  }

  Future<void> _selectAnswer(int index) async {
    if (_selectedIndex != null) return;
    setState(() => _selectedIndex = index);
    try {
      final res = await _dio.post('$_baseUrl/answer', data: {
        'session_id': _sessionId,
        'selected_index': index,
      }, options: await _authOptions);
      final data = res.data as Map<String, dynamic>;

      HapticFeedback.mediumImpact();

      setState(() {
        _lastIsCorrect = data['is_correct'];
        _lastExplanation = data['explanation'];
        _questionsAnswered = data['questions_answered'];
        _stage = _Stage.feedback;

        if (data['finished'] == true) {
          _finalLevel = data['final_level'];
          _breakdown = data['breakdown'];
        } else {
          _currentPassage = data['next_passage'];
        }
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi khi gửi câu trả lời. Thử lại nhé!'; _selectedIndex = null; });
    }
  }

  void _goNextOrResult() {
    if (_finalLevel != null) {
      setState(() => _stage = _Stage.result);
    } else {
      setState(() {
        _selectedIndex = null;
        _lastIsCorrect = null;
        _lastExplanation = null;
        _stage = _Stage.question;
      });
    }
  }

  void _resetAll() {
    setState(() {
      _stage = _Stage.pickType;
      _testType = null;
      _sessionId = null;
      _currentPassage = null;
      _finalLevel = null;
      _breakdown = null;
      _errorMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isVip == null) {
      return const Center(child: CircularProgressIndicator(color: _CatDS.indigo));
    }
    if (_isVip == false) {
      return _buildVipLocked();
    }
    switch (_stage) {
      case _Stage.pickType: return _buildPickType();
      case _Stage.loading: return const Center(child: CircularProgressIndicator(color: _CatDS.indigo));
      case _Stage.intro: return _buildIntro();
      case _Stage.question: return _buildQuestion();
      case _Stage.feedback: return _buildFeedback();
      case _Stage.result: return _buildResult();
    }
  }
  Widget _buildVipLocked() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 40),
      Container(
        width: 90, height: 90,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB300)]),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🔒', style: TextStyle(fontSize: 40))),
      ),
      const SizedBox(height: 20),
      const Text('TaiwanMate CAT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _CatDS.textDark)),
      const SizedBox(height: 8),
      const Text(
        'Tính năng kiểm tra trình độ thích ứng — dành riêng cho hội viên VIP',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: _CatDS.textGrey, height: 1.5),
      ),
      const SizedBox(height: 8),
      const Text('🇹🇼 TOCFL A1-C1 · 🇺🇸 English CEFR · 50 câu mỗi lượt',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _CatDS.indigo, fontWeight: FontWeight.w600)),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen())),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB300)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Text('⭐ Nâng cấp VIP', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    ]),
  );

  Widget _buildPickType() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      const Text('🧪', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 12),
      const Text('TaiwanMate CAT', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _CatDS.textDark)),
      const SizedBox(height: 6),
      const Text(
        'Bài kiểm tra thích ứng độc quyền — càng làm đúng, câu càng khó dần.\nKhông phải đề thi chính thức TOCFL/HSK.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: _CatDS.textGrey, height: 1.5),
      ),
      const SizedBox(height: 28),
      _buildTypeCard('tocfl', '🇹🇼', 'TOCFL — Tiếng Trung', 'A1 → C1'),
      const SizedBox(height: 12),
      _buildTypeCard('english', '🇺🇸', 'English CEFR', 'A1 → B2'),
    ]),
  );

  Widget _buildTypeCard(String type, String flag, String title, String range) => GestureDetector(
    onTap: () => _pickType(type),
    child: Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _CatDS.white, borderRadius: BorderRadius.circular(_CatDS.radius),
        border: Border.all(color: _CatDS.indigo.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Text(flag, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _CatDS.textDark)),
          Text('Trình độ $range · 50 câu', style: const TextStyle(fontSize: 11, color: _CatDS.textGrey)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _CatDS.indigo),
      ]),
    ),
  );

  Widget _buildIntro() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: GestureDetector(
        onTap: _resetAll,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_rounded, size: 18, color: _CatDS.textGrey),
          SizedBox(width: 4),
          Text('Chọn lại', style: TextStyle(fontSize: 13, color: _CatDS.textGrey)),
        ]),
      )),
      const SizedBox(height: 20),
      Text(_testType == 'tocfl' ? '🇹🇼 TOCFL' : '🇺🇸 English CEFR',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _CatDS.textDark)),
      const SizedBox(height: 20),
      if (_errorMsg != null) Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(_errorMsg!, style: const TextStyle(color: _CatDS.red, fontSize: 13)),
      ),
      if (_hasResumable) ...[
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _CatDS.yellowLight, borderRadius: BorderRadius.circular(_CatDS.radiusSm)),
          child: Text(
            'Bạn có 1 bài đang làm dở (${_resumeData?['questions_answered']}/${_resumeData?['total_questions']} câu)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8A6D00)),
          ),
        ),
        const SizedBox(height: 12),
        _buildCta('Tiếp tục làm bài', _continueResumed, primary: true),
        const SizedBox(height: 10),
        _buildCta('Làm lại từ đầu', _abandonAndRestart, primary: false),
      ] else ...[
        const Text('50 câu · Càng đúng, câu càng khó dần', style: TextStyle(fontSize: 13, color: _CatDS.textGrey)),
        const SizedBox(height: 20),
        _buildCta('Bắt đầu', _startFresh, primary: true),
      ],
    ]),
  );

  Widget _buildCta(String label, VoidCallback onTap, {required bool primary}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: primary ? const LinearGradient(colors: [_CatDS.indigo, _CatDS.indigoDark]) : null,
        color: primary ? null : _CatDS.white,
        border: primary ? null : Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
        boxShadow: primary ? [BoxShadow(color: _CatDS.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
      ),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary ? Colors.white : _CatDS.textDark)),
    ),
  );

  Widget _buildQuestion() {
    final passage = _currentPassage!;
    final genre = passage['genre'] as String? ?? '';
    final level = passage['level'] as String? ?? '';
    final options = List<String>.from(passage['options'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _CatDS.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(_genreLabels[genre] ?? genre, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _CatDS.indigo)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _CatDS.yellowLight, borderRadius: BorderRadius.circular(20)),
            child: Text(level, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF8A6D00))),
          ),
          const Spacer(),
          Text('${_questionsAnswered + 1}/$_totalQuestions', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CatDS.textGrey)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: _questionsAnswered / _totalQuestions, minHeight: 6,
                backgroundColor: _CatDS.indigo.withOpacity(0.1), valueColor: const AlwaysStoppedAnimation(_CatDS.indigo))),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: _CatDS.white, borderRadius: BorderRadius.circular(_CatDS.radius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
          child: Text(passage['passage_text'] ?? '',
              style: const TextStyle(fontSize: 16, color: _CatDS.textDark, height: 1.8, fontFamily: 'NotoSansTC')),
        ),
        const SizedBox(height: 16),
        Text(passage['question_text'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _CatDS.textDark)),
        const SizedBox(height: 12),
        ...List.generate(options.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _selectAnswer(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: _CatDS.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))]),
              child: Row(children: [
                Container(width: 26, height: 26,
                    decoration: BoxDecoration(color: _CatDS.bg, borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(['A', 'B', 'C', 'D'][i],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _CatDS.textGrey)))),
                const SizedBox(width: 10),
                Expanded(child: Text(options[i], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _CatDS.textDark))),
              ]),
            ),
          ),
        )),
        if (_errorMsg != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_errorMsg!, style: const TextStyle(color: _CatDS.red, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildFeedback() {
    final isCorrect = _lastIsCorrect == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(width: 80, height: 80,
            decoration: BoxDecoration(color: isCorrect ? _CatDS.greenLight : _CatDS.redLight, shape: BoxShape.circle),
            child: Icon(isCorrect ? Icons.check_rounded : Icons.close_rounded,
                color: isCorrect ? _CatDS.green : _CatDS.red, size: 44)),
        const SizedBox(height: 16),
        Text(isCorrect ? 'Chính xác!' : 'Chưa đúng',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isCorrect ? _CatDS.green : _CatDS.red)),
        if (_lastExplanation != null && _lastExplanation!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _CatDS.bg, borderRadius: BorderRadius.circular(14)),
            child: Text(_lastExplanation!, style: const TextStyle(fontSize: 13, color: _CatDS.textDark, height: 1.6)),
          ),
        ],
        const SizedBox(height: 24),
        _buildCta(_finalLevel != null ? 'Xem kết quả 🎉' : 'Câu tiếp theo →', _goNextOrResult, primary: true),
      ]),
    );
  }

  Widget _buildResult() {
    final breakdown = _breakdown ?? {};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(width: 120, height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_CatDS.indigo, _CatDS.indigoDark]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _CatDS.indigo.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Center(child: Text(_finalLevel ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))),
        const SizedBox(height: 20),
        const Text('Trình độ hiện tại của bạn', style: TextStyle(fontSize: 14, color: _CatDS.textGrey)),
        const SizedBox(height: 24),
        if (breakdown.isNotEmpty) ...[
          const Align(alignment: Alignment.centerLeft,
              child: Text('Chi tiết theo dạng bài', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _CatDS.textDark))),
          const SizedBox(height: 12),
          ...breakdown.entries.map((e) {
            final ratio = (e.value as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(_genreLabels[e.key] ?? e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CatDS.textDark)),
                  const Spacer(),
                  Text('${(ratio * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CatDS.indigo)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: ratio, minHeight: 8,
                        backgroundColor: _CatDS.indigo.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(ratio >= 0.6 ? _CatDS.green : _CatDS.red))),
              ]),
            );
          }),
          const SizedBox(height: 20),
        ],
        _buildCta('Làm lại', _resetAll, primary: true),
      ]),
    );
  }
}