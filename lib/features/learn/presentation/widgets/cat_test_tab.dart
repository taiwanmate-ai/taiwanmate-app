import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
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

const _backendOrigin = 'https://taiwanmate-backend-production.up.railway.app';
const _baseUrl = '$_backendOrigin/api/v1/cat-test';
const _maxReplays = 2;

const _genreLabels = {
  'dialogue': '💬 Hội thoại',
  'notice': '📢 Thông báo',
  'ad': '📰 Quảng cáo',
  'article': '📄 Bài viết',
  'letter': '✉️ Thư/Email',
};

const _skillLabels = {
  'reading': '📖 Đọc hiểu',
  'listening': '🎧 Nghe hiểu',
};

const _skillOrder = ['reading', 'listening'];

/// pickType/loading dùng chung cho các bước tải trạng thái ban đầu; intro/question/feedback lặp
/// lại cho từng kỹ năng (Reading rồi Listening); skillDone là màn chuyển tiếp giữa 2 kỹ năng;
/// result là kết quả tổng hợp CẢ HAI kỹ năng (không phải kết quả của riêng 1 kỹ năng).
enum _Stage { pickType, loading, intro, question, feedback, skillDone, result }

class CatTestTab extends StatefulWidget {
  /// Gọi đúng một lần khi user bấm tiếp tục (hoặc tự động) sau khi xem kết quả CAT — dùng để gate Tab Học.
  /// Không bắt buộc: nếu null, CatTestTab hoạt động độc lập như trước (không có nút "Tiếp tục").
  final VoidCallback? onCompleted;

  /// True khi CatTestTab được mở như bài kiểm tra đầu vào bắt buộc (gate trước Learning Hub).
  /// Ở chế độ này: bỏ qua kiểm tra VIP, và tự động chuyển tiếp sau khi có kết quả.
  /// Mặc định false để không đổi hành vi cho các nơi gọi khác (vẫn yêu cầu VIP như trước).
  final bool isRequiredPlacement;

  /// test_type bắt buộc (vd 'tocfl'/'english') khi isRequiredPlacement == true — do LearnScreen
  /// quyết định theo ngôn ngữ user đang học. Khi có giá trị này, bỏ qua màn chọn loại đề thủ công.
  final String? requiredTestType;

  const CatTestTab({super.key, this.onCompleted, this.isRequiredPlacement = false, this.requiredTestType});
  @override
  State<CatTestTab> createState() => _CatTestTabState();
}

class _CatTestTabState extends State<CatTestTab> {
  final _storage = const FlutterSecureStorage();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));
  final _audioPlayer = AudioPlayer();

  bool? _isVip; // null = đang kiểm tra
  _Stage _stage = _Stage.pickType;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = state == PlayerState.playing;
        if (_isPlayingAudio) _audioReady = true;
      });
    });
    if (widget.isRequiredPlacement) {
      // CAT đầu vào bắt buộc: miễn phí cho mọi user, không kiểm tra VIP để bắt đầu/tiếp tục bài.
      _isVip = true;
      // Không cho user tự chọn loại đề — dùng đúng test_type do LearnScreen quyết định theo ngôn ngữ đang học.
      if (widget.requiredTestType != null) {
        _pickType(widget.requiredTestType!);
      }
    } else {
      _checkVip();
    }
  }

  @override
  void deactivate() {
    // Điều hướng rời khỏi tab (kể cả khi widget vẫn còn giữ trong cây, vd IndexedStack) phải dừng audio ngay.
    _audioPlayer.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
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
  String _currentSkill = 'reading';
  bool _hasResumable = false;
  Map<String, dynamic>? _resumeData;

  String? _sessionId;
  Map<String, dynamic>? _currentItem;
  int _questionsAnswered = 0;
  int _totalQuestions = 12; // gia tri mac dinh truoc khi co response tu API (khop MAX_QUESTIONS backend)

  int? _selectedIndex;
  bool? _lastIsCorrect;
  String? _lastExplanation;

  String? _finalLevel;
  Map<String, dynamic>? _breakdown;
  Map<String, dynamic>? _combinedResult;
  String? _errorMsg;
  bool _completionNotified = false;

  // Trạng thái phát audio cho câu hỏi Listening — reset mỗi khi sang item mới.
  bool _isPlayingAudio = false;
  bool _audioLoadingBtn = false;
  bool _audioReady = false; // đã phát được ít nhất 1 lần thành công -> mở khóa chọn đáp án
  bool _hasPlayedOnce = false;
  bool _audioError = false;
  int _replaysUsed = 0;

  Future<Options> get _authOptions async {
    final token = await _storage.read(key: 'access_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _pickType(String type) async {
    setState(() { _testType = type; _stage = _Stage.loading; _errorMsg = null; });
    try {
      final statusRes = await _dio.get('$_baseUrl/status',
          queryParameters: {'test_type': type}, options: await _authOptions);
      final status = statusRes.data as Map<String, dynamic>;
      final readingDone = status['reading']?['completed'] == true;
      final listeningDone = status['listening']?['completed'] == true;

      if (readingDone && listeningDone) {
        // Cả 2 kỹ năng đã hoàn thành — không cho làm lại, hiển thị thẳng kết quả tổng hợp.
        await _loadCombinedResult();
        return;
      }
      _currentSkill = readingDone ? 'listening' : 'reading';
      await _loadResumeForCurrentSkill();
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi kết nối. Thử lại nhé!'; _stage = _Stage.intro; _hasResumable = false; });
    }
  }

  Future<void> _loadResumeForCurrentSkill() async {
    setState(() { _stage = _Stage.loading; });
    try {
      final res = await _dio.get('$_baseUrl/resume',
          queryParameters: {'test_type': _testType, 'skill': _currentSkill}, options: await _authOptions);
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

  Future<void> _loadCombinedResult() async {
    setState(() { _stage = _Stage.loading; _errorMsg = null; });
    try {
      final res = await _dio.get('$_baseUrl/result',
          queryParameters: {'test_type': _testType}, options: await _authOptions);
      setState(() {
        _combinedResult = res.data as Map<String, dynamic>;
        _stage = _Stage.result;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi tải kết quả. Thử lại nhé!'; _stage = _Stage.intro; });
    }
  }

  Future<void> _startFresh() async {
    setState(() { _stage = _Stage.loading; _errorMsg = null; });
    try {
      final res = await _dio.post('$_baseUrl/start',
          data: {'test_type': _testType, 'skill': _currentSkill}, options: await _authOptions);
      final data = res.data as Map<String, dynamic>;
      setState(() {
        _sessionId = data['session_id'];
        _currentItem = data['item'];
        _questionsAnswered = data['questions_answered'];
        _totalQuestions = data['total_questions'];
        _selectedIndex = null;
        _stage = _Stage.question;
      });
      _resetAudioState();
    } catch (e) {
      setState(() { _errorMsg = 'Không thể bắt đầu bài kiểm tra. Thử lại nhé!'; _stage = _Stage.intro; });
    }
  }

  void _continueResumed() {
    final data = _resumeData!;
    setState(() {
      _sessionId = data['session_id'];
      _currentItem = data['item'];
      _questionsAnswered = data['questions_answered'];
      _totalQuestions = data['total_questions'];
      _selectedIndex = null;
      _stage = _Stage.question;
    });
    _resetAudioState();
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
    // Không cho chọn đáp án Listening trước khi audio đã sẵn sàng (đã phát được ít nhất 1 lần).
    if (_currentSkill == 'listening' && !_audioReady) return;
    setState(() => _selectedIndex = index);
    _audioPlayer.stop();
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
          _currentItem = data['next_item'];
        }
      });
      if (data['finished'] != true) _resetAudioState();
    } catch (e) {
      setState(() { _errorMsg = 'Lỗi khi gửi câu trả lời. Thử lại nhé!'; _selectedIndex = null; });
    }
  }

  void _goNextOrResult() {
    if (_finalLevel != null) {
      if (_currentSkill == 'reading') {
        // Reading xong nhưng CAT đầu vào chỉ hoàn thành khi CẢ HAI kỹ năng xong -> chuyển tiếp Listening.
        setState(() => _stage = _Stage.skillDone);
      } else {
        _loadCombinedResult().then((_) {
          // CAT đầu vào bắt buộc: ưu tiên tự động chuyển vào Learning Hub sau khi user kịp xem kết quả.
          if (widget.isRequiredPlacement && widget.onCompleted != null) {
            _autoAdvanceTimer?.cancel();
            _autoAdvanceTimer = Timer(const Duration(seconds: 4), _notifyCompleted);
          }
        });
      }
    } else {
      setState(() {
        _selectedIndex = null;
        _lastIsCorrect = null;
        _lastExplanation = null;
        _stage = _Stage.question;
      });
    }
  }

  Future<void> _advanceToListening() async {
    setState(() {
      _currentSkill = 'listening';
      _finalLevel = null;
      _breakdown = null;
      _sessionId = null;
      _currentItem = null;
      _questionsAnswered = 0;
    });
    await _loadResumeForCurrentSkill();
  }

  void _resetAll() {
    _autoAdvanceTimer?.cancel();
    _audioPlayer.stop();
    setState(() {
      _stage = _Stage.pickType;
      _testType = null;
      _currentSkill = 'reading';
      _sessionId = null;
      _currentItem = null;
      _finalLevel = null;
      _breakdown = null;
      _combinedResult = null;
      _errorMsg = null;
    });
  }

  void _resetAudioState() {
    _audioPlayer.stop();
    setState(() {
      _isPlayingAudio = false;
      _audioLoadingBtn = false;
      _audioReady = false;
      _hasPlayedOnce = false;
      _audioError = false;
      _replaysUsed = 0;
    });
  }

  Future<void> _playAudio(String url) async {
    if (_isPlayingAudio) return; // khong cho phat chong len
    if (_hasPlayedOnce && _replaysUsed >= _maxReplays) return; // het luot nghe lai
    setState(() { _audioLoadingBtn = true; _audioError = false; });
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (_hasPlayedOnce) _replaysUsed++;
      _hasPlayedOnce = true;
    } catch (e) {
      if (mounted) setState(() => _audioError = true);
    } finally {
      if (mounted) setState(() => _audioLoadingBtn = false);
    }
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
      case _Stage.skillDone: return _buildSkillDone();
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
      const Text('🇹🇼 TOCFL A1-C2 · 🇺🇸 English CEFR · Đọc hiểu + Nghe hiểu · khoảng 8-12 câu mỗi kỹ năng',
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
        'Bài kiểm tra thích ứng độc quyền gồm Đọc hiểu + Nghe hiểu — càng làm đúng, câu càng khó dần.\nKhông phải đề thi chính thức TOCFL/HSK.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: _CatDS.textGrey, height: 1.5),
      ),
      const SizedBox(height: 28),
      _buildTypeCard('tocfl', '🇹🇼', 'TOCFL — Tiếng Trung', 'A1 → C2'),
      const SizedBox(height: 12),
      _buildTypeCard('english', '🇺🇸', 'English CEFR', 'A1 → C2'),
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
          Text('Trình độ $range · Đọc hiểu + Nghe hiểu', style: const TextStyle(fontSize: 11, color: _CatDS.textGrey)),
        ])),
        const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: _CatDS.indigo),
      ]),
    ),
  );

  /// Chỉ báo kỹ năng đang làm + vị trí trong 2 kỹ năng (Reading = 1/2, Listening = 2/2).
  Widget _buildSkillProgress() {
    final currentIdx = _skillOrder.indexOf(_currentSkill);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < _skillOrder.length; i++) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: i == currentIdx ? _CatDS.indigo : (i < currentIdx ? _CatDS.green.withOpacity(0.12) : _CatDS.bg),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${i < currentIdx ? '✓ ' : ''}${_skillLabels[_skillOrder[i]]}',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: i == currentIdx ? Colors.white : (i < currentIdx ? _CatDS.green : _CatDS.textGrey),
            ),
          ),
        ),
        if (i < _skillOrder.length - 1)
          Container(width: 16, height: 2, color: i < currentIdx ? _CatDS.green : Colors.grey.shade300),
      ],
    ]);
  }

  Widget _buildIntro() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 10),
      // CAT đầu vào bắt buộc: không cho quay lại chọn loại đề khác — test_type do LearnScreen quyết định.
      if (!widget.isRequiredPlacement)
        Align(alignment: Alignment.centerLeft, child: GestureDetector(
          onTap: _resetAll,
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_rounded, size: 18, color: _CatDS.textGrey),
            SizedBox(width: 4),
            Text('Chọn lại', style: TextStyle(fontSize: 13, color: _CatDS.textGrey)),
          ]),
        )),
      const SizedBox(height: 16),
      _buildSkillProgress(),
      const SizedBox(height: 16),
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
            'Bạn có 1 bài ${_skillLabels[_currentSkill]} đang làm dở (${_resumeData?['questions_answered']}/${_resumeData?['total_questions']} câu)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8A6D00)),
          ),
        ),
        const SizedBox(height: 12),
        _buildCta('Tiếp tục làm bài', _continueResumed, primary: true),
        const SizedBox(height: 10),
        _buildCta('Làm lại từ đầu', _abandonAndRestart, primary: false),
      ] else ...[
        Text(
          _currentSkill == 'reading'
              ? 'Khoảng 8-12 câu đọc hiểu · Càng đúng, câu càng khó dần'
              : 'Khoảng 8-12 câu nghe hiểu · Nghe rồi mới được chọn đáp án',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _CatDS.textGrey),
        ),
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
    final item = _currentItem!;
    final genre = item['genre'] as String? ?? '';
    final level = item['level'] as String? ?? '';
    final options = List<String>.from(item['options'] ?? []);
    final isListening = _currentSkill == 'listening';
    final answersLocked = isListening && !_audioReady;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Text(_skillLabels[_currentSkill] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _CatDS.indigo))),
        const SizedBox(height: 8),
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
        if (isListening)
          _buildAudioCard(item)
        else
          Container(
            width: double.infinity, padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: _CatDS.white, borderRadius: BorderRadius.circular(_CatDS.radius),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
            child: Text(item['passage_text'] ?? '',
                style: const TextStyle(fontSize: 16, color: _CatDS.textDark, height: 1.8, fontFamily: 'NotoSansTC')),
          ),
        const SizedBox(height: 16),
        Text(item['question_text'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _CatDS.textDark)),
        const SizedBox(height: 12),
        ...List.generate(options.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: answersLocked ? null : () => _selectAnswer(i),
            child: Opacity(
              opacity: answersLocked ? 0.45 : 1.0,
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
          ),
        )),
        if (answersLocked) Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Hãy nghe audio trước khi chọn đáp án nhé!',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _CatDS.textGrey)),
        ),
        if (_errorMsg != null) Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_errorMsg!, style: const TextStyle(color: _CatDS.red, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildAudioCard(Map<String, dynamic> item) {
    final audioUrl = '$_backendOrigin${item['audio_url'] ?? ''}';
    final remaining = _maxReplays - _replaysUsed;
    final canTap = !_audioLoadingBtn && !_isPlayingAudio && !(_hasPlayedOnce && remaining <= 0);

    String statusText;
    if (_audioError) {
      statusText = 'Không phát được âm thanh — chạm để thử lại';
    } else if (_audioLoadingBtn) {
      statusText = 'Đang tải...';
    } else if (_isPlayingAudio) {
      statusText = 'Đang phát...';
    } else if (!_hasPlayedOnce) {
      statusText = 'Chạm để nghe';
    } else if (remaining > 0) {
      statusText = 'Chạm để nghe lại (còn $remaining lần)';
    } else {
      statusText = 'Đã hết lượt nghe lại';
    }

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _CatDS.white, borderRadius: BorderRadius.circular(_CatDS.radius),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(children: [
        GestureDetector(
          onTap: canTap ? () => _playAudio(audioUrl) : null,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: canTap || _isPlayingAudio
                  ? [_CatDS.indigo, _CatDS.indigoDark]
                  : [Colors.grey.shade400, Colors.grey.shade500]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _audioLoadingBtn
                  ? const SizedBox(width: 26, height: 26,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Icon(_isPlayingAudio ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(statusText, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: _audioError ? _CatDS.red : _CatDS.textGrey)),
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
        _buildCta(
          _finalLevel != null
              ? (_currentSkill == 'reading' ? 'Xong Đọc hiểu →' : 'Xem kết quả 🎉')
              : 'Câu tiếp theo →',
          _goNextOrResult, primary: true,
        ),
      ]),
    );
  }

  Widget _buildSkillDone() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 30),
      Container(width: 90, height: 90,
          decoration: const BoxDecoration(color: _CatDS.greenLight, shape: BoxShape.circle),
          child: const Center(child: Text('✅', style: TextStyle(fontSize: 40)))),
      const SizedBox(height: 20),
      const Text('Xong phần Đọc hiểu!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _CatDS.textDark)),
      const SizedBox(height: 8),
      Text('Trình độ tạm thời: $_finalLevel', style: const TextStyle(fontSize: 14, color: _CatDS.textGrey)),
      const SizedBox(height: 24),
      _buildSkillProgress(),
      const SizedBox(height: 24),
      const Text('Tiếp theo là phần Nghe hiểu — nghe audio rồi chọn đáp án đúng.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _CatDS.textGrey, height: 1.5)),
      const SizedBox(height: 24),
      _buildCta('Bắt đầu Nghe hiểu →', _advanceToListening, primary: true),
    ]),
  );

  Widget _buildResult() {
    final result = _combinedResult ?? {};
    final overallLevel = result['overall_level'] as String?;
    final reading = (result['reading'] as Map<String, dynamic>?) ?? {};
    final listening = (result['listening'] as Map<String, dynamic>?) ?? {};
    final recommended = result['recommended'] as Map<String, dynamic>?;
    final bothDone = reading['completed'] == true && listening['completed'] == true;

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
            child: Center(child: Text(overallLevel ?? '-', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)))),
        const SizedBox(height: 12),
        const Text('Trình độ tổng hợp của bạn', style: TextStyle(fontSize: 14, color: _CatDS.textGrey)),
        const SizedBox(height: 4),
        const Text('(lấy mức thấp hơn giữa Đọc hiểu và Nghe hiểu)',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _CatDS.textGrey)),
        const SizedBox(height: 24),
        if (bothDone) ...[
          _buildSkillResultCard('📖 Đọc hiểu', reading),
          const SizedBox(height: 12),
          _buildSkillResultCard('🎧 Nghe hiểu', listening),
          if (recommended != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _CatDS.yellowLight, borderRadius: BorderRadius.circular(_CatDS.radiusSm)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Gợi ý bài học phù hợp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A6D00))),
                const SizedBox(height: 4),
                Text('${recommended['level']} · ${recommended['topic_vi'] ?? ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _CatDS.textDark)),
              ]),
            ),
          ],
          const SizedBox(height: 20),
        ],
        if (widget.onCompleted != null) ...[
          _buildCta('Tiếp tục vào Học tập', _notifyCompleted, primary: true),
          if (widget.isRequiredPlacement) ...[
            const SizedBox(height: 10),
            const Text('Sẽ tự động chuyển vào Học tập sau ít giây...',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _CatDS.textGrey)),
          ],
        ] else if (!widget.isRequiredPlacement)
          _buildCta('Về màn hình chính', _resetAll, primary: true),
      ]),
    );
  }

  Widget _buildSkillResultCard(String label, Map<String, dynamic> skillResult) {
    final level = skillResult['final_level'] as String? ?? '-';
    final correct = skillResult['correct_count'] as int? ?? 0;
    final wrong = skillResult['wrong_count'] as int? ?? 0;
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _CatDS.white, borderRadius: BorderRadius.circular(_CatDS.radiusSm),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _CatDS.textDark)),
        const Spacer(),
        Text('$correct đúng / $wrong sai', style: const TextStyle(fontSize: 12, color: _CatDS.textGrey)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _CatDS.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(level, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _CatDS.indigo)),
        ),
      ]),
    );
  }

  void _notifyCompleted() {
    if (_completionNotified) return;
    _completionNotified = true;
    _autoAdvanceTimer?.cancel();
    widget.onCompleted?.call();
  }
}
