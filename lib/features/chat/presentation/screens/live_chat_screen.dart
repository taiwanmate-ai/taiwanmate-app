import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/features/profile/paywall_screen.dart';
import 'package:chinesemate/features/tools/presentation/screens/grammar_tool_screen.dart';
import 'package:chinesemate/core/constants/api_constants.dart';

// ─── Design System ────────────────────────────────────────────
class _DS {
  static const bg = Color(0xFF0D0D1A);
  static const card = Color(0xFF1A1A2E);
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const white = Colors.white;
  static const textGrey = Color(0xFF8A8FA3);
  static const green = Color(0xFF00C853);
  static const red = Color(0xFFFF3D57);
  static const yellow = Color(0xFFFFD166);
  static const orange = Color(0xFFFF6B35);
}

// ─── Boss Model ───────────────────────────────────────────────
class Boss {
  final int id;
  final String name;
  final String emoji;
  final String situation;
  final String difficulty;
  final Color color;
  final List<Phrase> phrases;
  // "Diem yeu Boss" — chu de Boss nay de bi "chi mang" nhat, server tinh
  // dua tren topic_tag pho bien nhat trong bo cau cua chinh Boss do (xem
  // BOSSES trong pronunciation.py). weaknessLabel de trong neu backend cu
  // chua co field nay (an toan nguoc, khong crash app cu hon).
  final String? weaknessTag;
  final String? weaknessLabel;

  Boss({required this.id, required this.name, required this.emoji,
    required this.situation, required this.difficulty,
    required this.color, required this.phrases,
    this.weaknessTag, this.weaknessLabel});

  factory Boss.fromJson(Map<String, dynamic> j) => Boss(
    id: j['id'], name: j['name'], emoji: j['emoji'],
    situation: j['situation'], difficulty: j['difficulty'],
    color: Color(int.parse('FF${j['color'].replaceAll('#', '')}', radix: 16)),
    phrases: (j['phrases'] as List).map((p) => Phrase.fromJson(p)).toList(),
    weaknessTag: j['weakness_tag'] as String?,
    weaknessLabel: j['weakness_label'] as String?,
  );
}

class Phrase {
  final String id, text, meaning, pinyin;
  Phrase({required this.id, required this.text, required this.meaning, required this.pinyin});
  factory Phrase.fromJson(Map<String, dynamic> j) =>
      Phrase(id: j['id'] ?? '', text: j['text'], meaning: j['meaning'], pinyin: j['pinyin']);
}

// ─── Score Result ─────────────────────────────────────────────
class ScoreResult {
  final int score;
  final bool isCorrect;
  final String feedbackVi;
  final bool toneOk;
  final bool pronunciationOk;
  final String userSaid;
  // STT Quality Gates (backend) tu choi ban ghi am qua yeu/khong chac
  // chan — score luon la 0, KHONG phai user phat am sai that su, nen UI
  // phai hien thong bao rieng ("thu lai") thay vi coi nhu 1 lan sai that.
  final bool gateRejected;
  final bool criticalHit;
  final String? weaknessLabel;

  ScoreResult({required this.score, required this.isCorrect,
    required this.feedbackVi, required this.toneOk,
    required this.pronunciationOk, required this.userSaid,
    this.gateRejected = false, this.criticalHit = false, this.weaknessLabel});

  factory ScoreResult.fromJson(Map<String, dynamic> j) => ScoreResult(
    score: j['score'] ?? 0,
    isCorrect: j['is_correct'] ?? false,
    feedbackVi: j['feedback_vi'] ?? '',
    toneOk: j['tone_ok'] ?? false,
    pronunciationOk: j['pronunciation_ok'] ?? false,
    userSaid: j['user_said'] ?? '',
    gateRejected: j['gate_rejected'] ?? false,
    criticalHit: j['critical_hit'] ?? false,
    weaknessLabel: j['weakness_label'] as String?,
  );
}

// ─── Ghost Run — "Đua Bóng Ma" (idea #2) ────────────────────────
// Ban chay NHANH NHAT (moi cau >=70 diem) tung duoc ghi nhan cho 1 Boss —
// xem BossGhostRun/backend. Client dung phraseTimestamps de ve tien do
// "bong ma" song song voi tien do that cua nguoi choi hien tai, KHONG can
// dong bo real-time/WebSocket (xem phan tich 4 y tuong da trinh bay).
class GhostRun {
  final String displayName;
  final int totalTimeSeconds;
  final List<double> phraseTimestamps;
  final int totalScore;
  final bool isMine;

  GhostRun({required this.displayName, required this.totalTimeSeconds,
    required this.phraseTimestamps, required this.totalScore, required this.isMine});

  factory GhostRun.fromJson(Map<String, dynamic> j) => GhostRun(
    displayName: j['display_name'] ?? 'Ẩn danh',
    totalTimeSeconds: j['total_time_seconds'] ?? 0,
    phraseTimestamps: (j['phrase_timestamps'] as List? ?? []).map((e) => (e as num).toDouble()).toList(),
    totalScore: j['total_score'] ?? 0,
    isMine: j['is_mine'] ?? false,
  );

  /// So voi thoi diem elapsedSeconds hien tai, bong ma da xong bao nhieu cau.
  int phrasesCompletedAt(double elapsedSeconds) =>
      phraseTimestamps.where((t) => t <= elapsedSeconds).length;
}

// ═══════════════════════════════════════════════════════════════
// LIVE CHAT SCREEN — Entry point
// ═══════════════════════════════════════════════════════════════
class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});
  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _storage = const FlutterSecureStorage();
  List<Boss> _bosses = [];
  int? _dailyBossId;
  bool _isLoading = true;
  bool _loadFailed = false;
  // "Boss nói trước" (idea #3, 2026-09-16) — chế độ NGHE ĐOÁN: ẩn chữ Hán
  // + pinyin, Boss đọc TRƯỚC bằng TTS, user phải NGHE rồi mới nói lại
  // (xem _BattleScreenState._revealed). Mặc định tắt để không đổi hành vi
  // cũ (đọc theo mẫu hiển thị sẵn) — user tự bật khi muốn luyện nghe.
  bool _listenMode = false;

  @override
  void initState() {
    super.initState();
    _loadBosses();
  }

  Future<void> _loadBosses() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/pronunciation/bosses',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      setState(() {
        _bosses = (data['bosses'] as List).map((b) => Boss.fromJson(b)).toList();
        _dailyBossId = data['daily_boss_id'];
        _isLoading = false;
      });
    } catch (e) {
      // Bug "man hinh trang im lang khi mat mang" — truoc day chi tat
      // loading, khong bao gio bao user biet la loi hay that su chua co
      // Boss nao, cung khong co cach thu lai tru thoat man hinh vao lai.
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _startBattle(Boss boss, {required bool isDaily}) async {
    Boss battleBoss = boss;
    GhostRun? ghost;
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/pronunciation/boss/${boss.id}/battle',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      battleBoss = Boss.fromJson(res.data);
      // Bong ma — best-effort, KHONG chan tran dau neu loi/chua co ghost.
      try {
        final ghostRes = await dio.get(
          '${ApiConstants.baseUrl}/pronunciation/boss/${boss.id}/ghost',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        if (ghostRes.data['ghost'] != null) ghost = GhostRun.fromJson(ghostRes.data['ghost']);
      } catch (_) {}
    } catch (_) {
      // Nếu lỗi, dùng tạm boss gốc (5 câu đầu) để không chặn user chơi
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BattleScreen(boss: battleBoss, storage: _storage, isDaily: isDaily,
          listenMode: _listenMode, ghost: ghost),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF181830), _DS.bg],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('🏟️ Đấu Trường', style: TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  const Text('Chinh phục Boss', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.white)),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SurvivalScreen())),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _DS.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _DS.red.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Text('🌊', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Sinh Tồn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.red)),
                    ]),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _LeaderboardScreen(storage: _storage))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _DS.yellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _DS.yellow.withOpacity(0.3)),
                    ),
                    child: const Row(children: [
                      Text('🏆', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('BXH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.yellow)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // Mode toggle — "Đọc theo" (mac dinh, hien san chu+pinyin) vs
              // "Nghe đoán" (Boss noi truoc, an chu toi khi tra loi — idea #3).
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: _DS.card, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _ModeTab(
                    label: '🗣️ Đọc theo', selected: !_listenMode,
                    onTap: () => setState(() => _listenMode = false),
                  )),
                  Expanded(child: _ModeTab(
                    label: '🎧 Nghe đoán', selected: _listenMode,
                    onTap: () => setState(() => _listenMode = true),
                  )),
                ]),
              ),
            ]),
          ),

          // Daily Boss Banner
          if (_dailyBossId != null && _bosses.isNotEmpty)
            GestureDetector(
              onTap: () {
                final daily = _bosses.firstWhere((b) => b.id == _dailyBossId, orElse: () => _bosses.first);
                _startBattle(daily, isDaily: true);
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF3D57)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  const Text('⚡', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('BOSS HÔM NAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 1)),
                    Text(
                      _bosses.firstWhere((b) => b.id == _dailyBossId, orElse: () => _bosses.first).name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const Text('Điểm x2 hôm nay! 🔥', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ])),
                  const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 40),
                ]),
              ),
            ),

          // Boss List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _DS.indigo))
                : _loadFailed
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('😢', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          const Text('Không tải được danh sách Boss.\nKiểm tra mạng rồi thử lại nhé!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _DS.textGrey, height: 1.5)),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _loadBosses,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(color: _DS.indigo, borderRadius: BorderRadius.circular(14)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Thử lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ]),
                      )
                    : RefreshIndicator(
                        color: _DS.indigo,
                        backgroundColor: _DS.card,
                        onRefresh: _loadBosses,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _bosses.length,
                          itemBuilder: (_, i) => _BossCard(
                            boss: _bosses[i],
                            isDaily: _bosses[i].id == _dailyBossId,
                            onTap: () => _startBattle(_bosses[i], isDaily: _bosses[i].id == _dailyBossId),
                          ),
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─── Boss Card ────────────────────────────────────────────────
class _BossCard extends StatelessWidget {
  final Boss boss;
  final bool isDaily;
  final VoidCallback onTap;

  const _BossCard({required this.boss, required this.isDaily, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_DS.card, Color.lerp(_DS.card, boss.color, 0.08)!],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDaily ? boss.color.withOpacity(0.5) : Colors.white.withOpacity(0.06), width: isDaily ? 2 : 1),
          boxShadow: [BoxShadow(color: boss.color.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [boss.color.withOpacity(0.25), boss.color.withOpacity(0.1)]),
              shape: BoxShape.circle,
              border: Border.all(color: boss.color.withOpacity(0.4), width: 2),
              boxShadow: [BoxShadow(color: boss.color.withOpacity(0.25), blurRadius: 10)],
            ),
            child: Center(child: Text(boss.emoji, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(boss.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.white)),
              if (isDaily) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: _DS.orange, borderRadius: BorderRadius.circular(8)),
                  child: const Text('HOT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(boss.situation, style: TextStyle(fontSize: 12, color: _DS.textGrey)),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: boss.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(boss.difficulty, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: boss.color)),
              ),
              const SizedBox(width: 8),
              Text('${boss.phrases.length} câu', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
            ]),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, color: boss.color, size: 16),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BATTLE SCREEN
// ═══════════════════════════════════════════════════════════════
class _BattleScreen extends StatefulWidget {
  final Boss boss;
  final FlutterSecureStorage storage;
  final bool isDaily;
  final bool listenMode;
  final GhostRun? ghost;
  const _BattleScreen({required this.boss, required this.storage, this.isDaily = false,
    this.listenMode = false, this.ghost});

  @override
  State<_BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<_BattleScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _totalScore = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _perfectCount = 0;
  int _criticalHits = 0;
  bool _isRecording = false;
  bool _isScoring = false;
  ScoreResult? _lastResult;
  bool _battleFinished = false;
  final List<ScoreResult> _results = [];
  late DateTime _startTime;
  Map<String, dynamic>? _nextAction;
  List<dynamic> _badges = [];

  // "Boss phan don" (2026-09-15) — diem < 70 (va KHONG phai do Gate tu
  // choi audio) gio BAT BUOC noi lai DUNG cau do truoc khi duoc di tiep,
  // thay vi cho qua vo dieu kien nhu truoc — HP Boss vi vay gio phan anh
  // CHAT LUONG that, khong chi so luong cau da qua. Sau 3 lan thu that
  // bai lien tiep, mo loi thoat "Bo qua cau nay" de tranh ket cung.
  int _retryFailCount = 0;
  static const _maxForcedRetries = 3;

  // Luu ket qua tran dau (2026-09-15) — truoc day that bai HOAN TOAN im
  // lang, diem/combo/perfect mat trang khong bao gio bao user. Gio theo
  // doi trang thai de hien banner + nut "Thu luu lai" neu that bai.
  bool _isSavingResult = false;
  bool _resultSaveFailed = false;

  // "Dua bong ma" (2026-09-16) — dong ho bam gio tu luc vao tran, ghi lai
  // moc thoi gian (giay) tai thoi diem HOAN THANH moi cau (dan toi
  // _advancePhrase) de sau tran nop len /boss/{id}/ghost neu du dieu
  // kien. _ghostTimer chi de ep UI ve lai moi 500ms cho thanh tien do
  // "dang truoc/sau bong ma" chay muot, KHONG lien quan logic cham diem.
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _myTimestamps = [];
  Timer? _ghostTimer;
  bool _newGhostRecord = false;

  // "Boss noi truoc" / che do Nghe doan (2026-09-16) — khi listenMode bat,
  // an chu Han + pinyin cho toi khi user nop CAU TRA LOI DAU TIEN cho cau
  // hien tai (ke ca bi Gate tu choi cung tinh la da "thu"), giup ep nghe
  // truoc khi doc. _isSpeaking khoa nut phat de tranh bam chong TTS.
  bool _revealed = true;
  bool _isSpeaking = false;

  late AnimationController _critHitCtrl;
  late Animation<double> _critHitAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _comboCtrl;
  late Animation<double> _comboAnim;

  double get _bossHp => 1 - (_currentIndex / widget.boss.phrases.length);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _revealed = !widget.listenMode;

    // Vi tuoc bug (2026-09-15): AnimationController nay TRUOC DAY khong
    // bao gio duoc .forward(), tao ra nhung khong dung — thanh HP da tu
    // muot ma qua AnimatedContainer (500ms) roi, KHONG can controller
    // rieng cho no. Tai su dung LAM hieu ung loe vang khi "chi mang"
    // (Diem yeu Boss) thay vi xoa han, thuong cho co che moi ben duoi.
    _critHitCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _critHitAnim = CurvedAnimation(parent: _critHitCtrl, curve: Curves.easeOut);

    _shakeCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(_shakeCtrl);

    _comboCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _comboAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _comboCtrl, curve: Curves.elasticOut));

    _stopwatch.start();
    if (widget.ghost != null) {
      _ghostTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted && !_battleFinished) setState(() {});
      });
    }
    if (widget.listenMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrentPhrase());
    }
  }

  @override
  void dispose() {
    _critHitCtrl.dispose();
    _shakeCtrl.dispose();
    _comboCtrl.dispose();
    _ghostTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _speakCurrentPhrase() async {
    if (_isSpeaking || !mounted) return;
    setState(() => _isSpeaking = true);
    try {
      final phrase = widget.boss.phrases[_currentIndex];
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.post(
        '${ApiConstants.baseUrl}/translate/tts',
        data: {'text': phrase.text, 'lang': 'zh-TW'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final b64 = base64Encode(response.data as List<int>);
      await webPlayAudio(b64);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi phát âm Boss. Thử lại nhé!')),
      );
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isScoring) return;
    setState(() => _isRecording = true);
    HapticFeedback.lightImpact();
    await webStartRecording(
      (audioBase64) => _submitAudio(audioBase64),
      (error) => setState(() => _isRecording = false),
    );
  }

  void _stopRecording() {
    webStopRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _submitAudio(String audioBase64) async {
    setState(() { _isRecording = false; _isScoring = true; });
    try {
      final phrase = widget.boss.phrases[_currentIndex];
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)));
      final res = await dio.post(
        '${ApiConstants.baseUrl}/pronunciation/score',
        data: {
          'audio_base64': audioBase64,
          'phrase_id': phrase.id,
          'phrase_text': phrase.text,
          'phrase_pinyin': phrase.pinyin,
          'phrase_meaning': phrase.meaning,
          'boss_id': widget.boss.id,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final result = ScoreResult.fromJson(res.data);

      // Audio bi Gate tu choi (khong nghe ro/khong chac chan) KHONG phai
      // 1 lan phat am that su — khong tinh vao lich su cau tra loi, khong
      // pha combo, khong tinh vao so lan "phan cong" bat buoc thu lai.
      if (result.gateRejected) {
        setState(() { _lastResult = result; _isScoring = false; _revealed = true; });
        return;
      }

      // QUAN TRONG (bug tu phat hien khi them "Boss phan don"): _results/
      // _totalScore/_criticalHits/_perfectCount/_maxCombo CHI duoc cong
      // dua tren lan thu THANH CONG (>=70) — moi lan "Boss phan don" bat
      // buoc thu lai (score<70) se GOI LAI _submitAudio nhieu lan cho
      // CUNG 1 cau, neu cong diem/ket qua o day moi lan se bi CONG DON
      // SAI (vd thu sai 3 lan roi dung van duoc tinh 4 lan, hoac ket qua
      // review cuoi tran bi lech vi so entry _results > so cau thuc te).
      // _results.add() gio doi sang _advancePhrase() (chi push DUY NHAT
      // 1 lan/cau, la lan cuoi cung dan toi tien tiep/bo qua).
      if (result.score >= 70) {
        int earned = result.score;
        // Combo: x1.5 tu 3, x2 tu 5 — KHONG cong don (sua bug hien thi
        // "x2" nhung thuc te nhan x3 truoc day).
        if (_combo >= 5) {
          earned = (earned * 2).toInt();
        } else if (_combo >= 3) {
          earned = (earned * 1.5).toInt();
        }
        // Boss ngay nhan them x2 (Idea "Diem x2 hom nay" gio moi THAT SU
        // co co che, truoc day chi la chu trang tri khong lam gi ca).
        if (widget.isDaily) earned *= 2;
        // Diem yeu Boss — chi mang cong them flat.
        if (result.criticalHit) {
          earned += 20;
          _criticalHits++;
          HapticFeedback.mediumImpact();
          _critHitCtrl.forward(from: 0);
        }

        _combo++;
        if (_combo > _maxCombo) _maxCombo = _combo;
        if (result.score >= 95) _perfectCount++;
        _retryFailCount = 0;
        HapticFeedback.lightImpact();
        _comboCtrl.forward(from: 0);

        setState(() {
          _lastResult = result;
          _totalScore += earned;
          _isScoring = false;
          _revealed = true;
        });
      } else {
        _combo = 0;
        _retryFailCount++;
        HapticFeedback.heavyImpact();
        _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reset());
        setState(() {
          _lastResult = result;
          _isScoring = false;
          _revealed = true;
        });
      }

    } on DioException catch (e) {
      setState(() => _isScoring = false);
      if (e.response?.statusCode == 403) {
        if (mounted) showDialog(
          context: context,
          builder: (_) => const PaywallScreen(),
        );
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi chấm điểm. Thử lại!'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => _isScoring = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi chấm điểm. Thử lại!'), backgroundColor: Colors.red),
      );
    }
  }
  /// Di tiep sang cau moi (hoac ket thuc tran) — CHI goi khi diem dat
  /// (>=70) hoac user chu dong bam "Bo qua" sau khi da thu bat buoc du
  /// _maxForcedRetries lan. KHONG con la duong duy nhat sau moi cau nhu
  /// truoc — xem _retryCurrentPhrase() cho truong hop diem thap.
  void _advancePhrase() {
    // Ghi DUY NHAT 1 ket qua cho cau nay vao lich su review cuoi tran —
    // du co bao nhieu lan "Boss phan don" bat buoc thu lai truoc do,
    // chi lan CUOI CUNG (dan toi tien tiep, hoac lan gan nhat neu bam
    // "Bo qua") moi duoc tinh — tranh _results.length vuot qua so cau
    // thuc te (xem ghi chu trong _submitAudio).
    if (_lastResult != null) _results.add(_lastResult!);
    _myTimestamps.add(_stopwatch.elapsed.inMilliseconds / 1000.0);
    _retryFailCount = 0;
    if (_currentIndex + 1 >= widget.boss.phrases.length) {
      _stopwatch.stop();
      _ghostTimer?.cancel();
      setState(() => _battleFinished = true);
      _submitResult();
    } else {
      setState(() {
        _currentIndex++;
        _lastResult = null;
        _revealed = !widget.listenMode;
      });
      if (widget.listenMode) _speakCurrentPhrase();
    }
  }

  /// "Boss phan don" — xoa ket qua vua roi, GIU NGUYEN _currentIndex de
  /// user bat buoc noi lai DUNG cau vua sai (hoac audio vua bi Gate tu
  /// choi), thay vi duoc luot qua vo dieu kien nhu truoc.
  void _retryCurrentPhrase() {
    setState(() => _lastResult = null);
  }

  Future<void> _submitResult() async {
    setState(() { _isSavingResult = true; _resultSaveFailed = false; });
    try {
      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.post(
        '${ApiConstants.baseUrl}/pronunciation/submit',
        data: {
          'boss_id': widget.boss.id,
          'total_score': _totalScore,
          'perfect_count': _perfectCount,
          'combo_max': _maxCombo,
          'time_seconds': elapsed,
          'critical_hits': _criticalHits,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          _isSavingResult = false;
          _badges = (res.data['badges'] as List?) ?? [];
        });
      }
    } catch (e) {
      // Bug "mat trang ket qua tran dau" (2026-09-15) — truoc day that
      // bai HOAN TOAN im lang, user tuong da luu nhung thuc te mat sach
      // diem/combo/perfect. Gio giu nguyen so lieu tren man hinh (khong
      // mat, van hien thi binh thuong) NHUNG bao ro + cho nut "Thu luu
      // lai" thay vi im lang.
      if (mounted) setState(() { _isSavingResult = false; _resultSaveFailed = true; });
    }
    _loadNextAction();
    _submitGhost();
  }

  /// "Dua bong ma" — nop lam ghost moi cho Boss nay, best-effort (khong
  /// bao loi neu that bai, khong anh huong flow chinh cua man ket qua).
  /// Backend TU quyet dinh co luu hay khong (phai dat moi cau >=70 diem
  /// VA nhanh hon ghost hien tai) — client chi gui du lieu that.
  Future<void> _submitGhost() async {
    if (_results.length < widget.boss.phrases.length) return;
    try {
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.post(
        '${ApiConstants.baseUrl}/pronunciation/boss/${widget.boss.id}/ghost',
        data: {
          'phrase_scores': _results.map((r) => r.score).toList(),
          'total_time_seconds': _myTimestamps.isNotEmpty ? _myTimestamps.last.round() : 0,
          'phrase_timestamps': _myTimestamps,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted && res.data['saved'] == true) {
        setState(() => _newGhostRecord = true);
      }
    } catch (e) {}
  }

  Future<void> _loadNextAction() async {
    try {
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/mastery/next-action',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted && res.data['has_suggestion'] == true) {
        setState(() => _nextAction = res.data);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_battleFinished) return _buildResult();

    final phrase = widget.boss.phrases[_currentIndex];
    final progress = _currentIndex / widget.boss.phrases.length;

    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_shakeAnim.value * math.sin(_shakeAnim.value * math.pi * 8) * 10, 0),
            child: child,
          ),
          child: Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.close_rounded, color: _DS.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_currentIndex + 1}/${widget.boss.phrases.length}',
                      style: const TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / widget.boss.phrases.length,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(widget.boss.color),
                    ),
                  ),
                ])),
                if (widget.isDaily) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(color: _DS.orange, borderRadius: BorderRadius.circular(20)),
                    child: const Text('x2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _DS.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Text('⭐', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text('$_totalScore', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.yellow)),
                  ]),
                ),
              ]),
            ),

            // Boss
            Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: Listenable.merge([_shakeAnim, _critHitAnim]),
                builder: (_, __) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _DS.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      // "Chi mang" (Diem yeu Boss) — loe vien vang 600ms
                      // roi tat dan, tai su dung _critHitCtrl (truoc day
                      // khong lam gi ca).
                      color: Color.lerp(widget.boss.color, _DS.yellow, _critHitAnim.value * (1 - _critHitAnim.value) * 4)!
                          .withOpacity(0.3 + _critHitAnim.value * (1 - _critHitAnim.value) * 4 * 0.6),
                      width: 1 + _critHitAnim.value * (1 - _critHitAnim.value) * 4 * 3,
                    ),
                  ),
                  child: Column(children: [
                    // Boss HP
                    Row(children: [
                      Text(widget.boss.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.boss.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.white)),
                        const SizedBox(height: 6),
                        Stack(children: [
                          Container(height: 10, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(5))),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            height: 10,
                            width: MediaQuery.of(context).size.width * 0.4 * _bossHp,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [widget.boss.color, widget.boss.color.withOpacity(0.6)]),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ]),
                      ])),
                      const SizedBox(width: 8),
                      Text('${(progress * 100).toInt()}%', style: TextStyle(fontSize: 12, color: widget.boss.color, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 16),

                    // Phrase to pronounce — che do "Nghe đoán" (listenMode)
                    // an chu Han + pinyin toi khi user nop lan thu DAU
                    // TIEN cho cau nay (_revealed), buoc nghe TTS truoc.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.boss.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: widget.boss.color.withOpacity(0.2)),
                      ),
                      child: _revealed
                          ? Column(children: [
                              Text(phrase.text, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500, color: _DS.white, fontFamily: 'NotoSansTC')),
                              const SizedBox(height: 6),
                              Text(phrase.pinyin, style: TextStyle(fontSize: 14, color: widget.boss.color, fontStyle: FontStyle.italic)),
                              const SizedBox(height: 4),
                              Text(phrase.meaning, style: const TextStyle(fontSize: 13, color: _DS.textGrey)),
                            ])
                          : Column(children: [
                              Text(phrase.meaning, style: const TextStyle(fontSize: 15, color: _DS.textGrey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _speakCurrentPhrase,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [widget.boss.color, widget.boss.color.withOpacity(0.7)]),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(_isSpeaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_isSpeaking ? 'Đang phát...' : 'Nghe Boss nói',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ]),
                                ),
                              ),
                            ]),
                    ),
                  ]),
                ),
              ),
            ),

            // "Dua bong ma" — thanh tien do song song, chi hien khi co
            // ghost VA tran dau chua ket thuc (sau khi ket thuc chuyen
            // sang hien banner ky luc moi trong man ket qua).
            if (widget.ghost != null && !_battleFinished)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _GhostProgressBar(
                  ghost: widget.ghost!,
                  myPhrasesDone: _currentIndex,
                  totalPhrases: widget.boss.phrases.length,
                  elapsedSeconds: _stopwatch.elapsed.inMilliseconds / 1000.0,
                ),
              ),

            // Combo display
            if (_combo >= 3)
              AnimatedBuilder(
                animation: _comboAnim,
                builder: (_, __) => Transform.scale(
                  scale: _comboAnim.value,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFD166)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _combo >= 5 ? '🔥🔥 COMBO x2 — $_combo!' : '🔥 COMBO x1.5 — $_combo!',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ),
              ),

            // Result feedback
            if (_lastResult != null && _lastResult!.gateRejected) ...[
              // Audio bi Gate tu choi — KHONG phai 1 lan sai that, chi
              // can noi lai, khong anh huong combo/HP/luot bat buoc.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _DS.yellow.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _DS.yellow.withOpacity(0.3)),
                ),
                child: Column(children: [
                  const Text('🎤', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 6),
                  Text(_lastResult!.feedbackVi,
                      style: const TextStyle(fontSize: 14, color: _DS.white, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _retryCurrentPhrase,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_DS.yellow, _DS.orange]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('🎤 Nói lại',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ] else if (_lastResult != null) ...[
              if (_lastResult!.criticalHit)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD166), Color(0xFFFF6B35)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '🎯 CHÍ MẠNG! Trúng điểm yếu: ${_lastResult!.weaknessLabel ?? "Boss"} (+20)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _lastResult!.isCorrect ? _DS.green.withOpacity(0.1) : _DS.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (_lastResult!.isCorrect ? _DS.green : _DS.red).withOpacity(0.3)),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      _lastResult!.isCorrect ? '✅' : '❌',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_lastResult!.score}/100',
                      style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w900,
                        color: _lastResult!.isCorrect ? _DS.green : _DS.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_lastResult!.score >= 95) const Text('⭐ PERFECT!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.yellow)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_lastResult!.feedbackVi, style: const TextStyle(fontSize: 13, color: _DS.white)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _FeedbackChip(label: 'Thanh điệu', ok: _lastResult!.toneOk),
                    const SizedBox(width: 8),
                    _FeedbackChip(label: 'Phát âm', ok: _lastResult!.pronunciationOk),
                  ]),
                  if (_lastResult!.userSaid.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('AI nghe: "${_lastResult!.userSaid}"',
                        style: TextStyle(fontSize: 11, color: _DS.textGrey, fontStyle: FontStyle.italic)),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              if (_lastResult!.score < 70) ...[
                // "Boss phan don" — bat buoc noi lai truoc khi duoc di
                // tiep, tru khi da thu du _maxForcedRetries lan (tranh
                // ket cung neu cau qua kho voi user).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    GestureDetector(
                      onTap: _retryCurrentPhrase,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_DS.red, Color(0xFFB71C1C)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('💥 Boss phản công! Nói lại câu này',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    if (_retryFailCount >= _maxForcedRetries) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _advancePhrase,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('Bỏ qua câu này (0 điểm)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: _DS.textGrey, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ]),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: _advancePhrase,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [widget.boss.color, widget.boss.color.withOpacity(0.7)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: widget.boss.color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Text(
                        _currentIndex + 1 >= widget.boss.phrases.length ? '🏆 Xem kết quả' : 'Tiếp theo →',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ] else ...[
              const Spacer(),
              // Record button
              GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopRecording(),
                onTapCancel: () => _stopRecording(),
                child: _isScoring
                    ? Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _DS.card),
                        child: const Center(child: CircularProgressIndicator(color: _DS.indigo, strokeWidth: 3)),
                      )
                    : AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _isRecording ? 110 : 100,
                        height: _isRecording ? 110 : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [_DS.red, const Color(0xFFB71C1C)]
                                : [widget.boss.color, widget.boss.color.withOpacity(0.7)],
                          ),
                          boxShadow: [BoxShadow(
                            color: (_isRecording ? _DS.red : widget.boss.color).withOpacity(0.5),
                            blurRadius: _isRecording ? 30 : 16,
                            spreadRadius: _isRecording ? 4 : 0,
                          )],
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
                          const SizedBox(height: 4),
                          Text(
                            _isRecording ? 'Thả để gửi' : 'Giữ để nói',
                            style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ]),
        ),
      ),
    );
  }
  Future<void> _handleNextActionTap(BuildContext context) async {
    final action = _nextAction;
    if (action == null) return;

    if (action['feature_type'] == 'grammar_tool') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GrammarToolScreen(initialQuery: action['reference_id'] as String?),
      ));
      return;
    }

    if (action['feature_type'] == 'boss_arena') {
      final bossId = int.tryParse(action['reference_id']?.toString() ?? '');
      if (bossId == null) return;
      try {
        final token = await widget.storage.read(key: 'access_token');
        final dio = Dio();
        final res = await dio.get(
          '${ApiConstants.baseUrl}/pronunciation/boss/$bossId/battle',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final targetBoss = Boss.fromJson(res.data);
        if (!context.mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => _BattleScreen(boss: targetBoss, storage: widget.storage),
        ));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được Boss này, thử lại nhé!')),
        );
      }
    }
  }
  Widget _buildResult() {
    final avgScore = _results.isEmpty ? 0 : _results.map((r) => r.score).reduce((a, b) => a + b) ~/ _results.length;
    final emoji = avgScore >= 85 ? '🏆' : avgScore >= 65 ? '💪' : '📚';
    final msg = avgScore >= 85 ? 'Boss bị tiêu diệt!' : avgScore >= 65 ? 'Chiến thắng vất vả!' : 'Cần luyện thêm!';

    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            // Boss defeated animation
            Text(widget.boss.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: _DS.red.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('BOSS BỊ ĐÁNH BẠI!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _DS.red, letterSpacing: 1)),
            ),
            const SizedBox(height: 16),
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(msg, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.white)),
            const SizedBox(height: 24),

            // "Dua bong ma" — chi hien khi backend XAC NHAN da luu ghost
            // moi (xem _submitGhost, dieu kien: moi cau >=70 diem VA
            // nhanh hon ghost cu).
            if (_newGhostRecord) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), Color(0xFF5B5FEF)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('👻', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('Bạn vừa lập kỷ lục Bóng Ma mới cho Boss này!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ],

            // Bug "mat trang ket qua tran dau" — bao ro neu /submit that
            // bai, cho nut thu luu lai thay vi im lang mat het diem/combo.
            if (_resultSaveFailed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: _DS.red.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _DS.red.withOpacity(0.3))),
                child: Column(children: [
                  const Text('⚠️ Chưa lưu được kết quả trận này (lỗi mạng)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _DS.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _isSavingResult ? null : _submitResult,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: _DS.red, borderRadius: BorderRadius.circular(12)),
                      child: _isSavingResult
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Thử lưu lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ],

            // Badges (backend /submit da tinh san — truoc day bi bo qua
            // hoan toan phia client, khong hien thi o dau ca)
            if (_badges.isNotEmpty) ...[
              Wrap(
                spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                children: _badges.map((b) {
                  final badge = b as Map;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${badge['emoji'] ?? '🏅'}', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text('${badge['name'] ?? ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Stats
            Row(children: [
              Expanded(child: _StatBox(label: '⭐ Điểm', value: '$_totalScore', color: _DS.yellow)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: '🎯 TB', value: '$avgScore%', color: widget.boss.color)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: '🔥 Combo', value: '$_maxCombo', color: _DS.orange)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _StatBox(label: '⭐ Perfect', value: '$_perfectCount/${widget.boss.phrases.length}', color: _DS.green)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: '📊 Đúng', value: '${_results.where((r) => r.isCorrect).length}/${_results.length}', color: _DS.indigo)),
              const SizedBox(width: 10),
              Expanded(child: _StatBox(label: '🎯 Chí mạng', value: '$_criticalHits', color: _DS.red)),
            ]),
            const SizedBox(height: 24),

            // Phrase review
            const Align(alignment: Alignment.centerLeft,
              child: Text('Chi tiết từng câu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.white))),
            const SizedBox(height: 10),
            ...List.generate(_results.length, (i) {
              final r = _results[i];
              final p = widget.boss.phrases[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _DS.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (r.isCorrect ? _DS.green : _DS.red).withOpacity(0.2)),
                ),
                child: Row(children: [
                  Text(r.isCorrect ? '✅' : '❌', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _DS.white, fontFamily: 'NotoSansTC')),
                    Text(p.meaning, style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                  ])),
                  Text('${r.score}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                    color: r.score >= 90 ? _DS.yellow : r.score >= 70 ? _DS.green : _DS.red)),
                ]),
              );
            }),
            const SizedBox(height: 20),

            if (_nextAction != null) ...[
              GestureDetector(
                onTap: () => _handleNextActionTap(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Row(children: [
                    const Text('🎯', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Bước tiếp theo cô đề xuất', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_nextAction!['cta_text'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                    ])),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ]),
                ),
              ),
            ],

            // Buttons
            GestureDetector(
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => _BattleScreen(boss: widget.boss, storage: widget.storage),
              )),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.boss.color, widget.boss.color.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Thách đấu lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Chọn Boss khác', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _DS.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LEADERBOARD SCREEN
// ═══════════════════════════════════════════════════════════════
class _LeaderboardScreen extends StatefulWidget {
  final FlutterSecureStorage storage;
  const _LeaderboardScreen({required this.storage});

  @override
  State<_LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<_LeaderboardScreen> {
  List _top10 = [];
  int? _myRank;
  int _myScore = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await widget.storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/pronunciation/leaderboard',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _top10 = res.data['top10'] ?? [];
        _myRank = res.data['my_rank'];
        _myScore = res.data['my_score'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: _DS.white),
              ),
              const SizedBox(width: 16),
              const Text('🏆 Bảng Anh Hùng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.white)),
            ]),
          ),

          // My rank
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Text('👤', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Xếp hạng của bạn', style: TextStyle(fontSize: 11, color: Colors.white70)),
                Text(_myRank != null ? '#$_myRank tuần này' : 'Chưa có điểm',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$_myScore', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.yellow)),
                const Text('điểm', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
            ]),
          ),

          // Top 10
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _DS.indigo))
                : _top10.isEmpty
                    ? const Center(child: Text('Chưa có ai lên bảng tuần này!\nHãy là người đầu tiên! 🔥',
                        textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, height: 1.5)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _top10.length,
                        itemBuilder: (_, i) {
                          final entry = _top10[i];
                          final rank = entry['rank'];
                          final rankEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: rank <= 3 ? _DS.yellow.withOpacity(0.1) : _DS.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: rank <= 3 ? _DS.yellow.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(children: [
                              Text(rankEmoji, style: TextStyle(fontSize: rank <= 3 ? 24 : 16, fontWeight: FontWeight.w900, color: _DS.yellow)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(entry['name'] ?? 'Ẩn danh', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _DS.white)),
                                Text('${entry['battles']} trận', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                              ])),
                              Text('${entry['score']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.yellow)),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SURVIVAL SCREEN — "Chế độ Sinh Tồn" (idea #1, 2026-09-16)
// ═══════════════════════════════════════════════════════════════
// Vong choi VO HAN, cau lay tu TOAN BO 100 cau (5 Boss gop chung), uu
// tien chu de nguoi dung dang YEU nhat qua /survival/next-phrase (tai su
// dung THANG du lieu user_topic_mastery da co san — xem phan tich 4 y
// tuong da trinh bay). Khac Dau Truong: KHONG co combo/critical hit/che
// do nghe doan — giu MVP gon, dung 3 mang (lives), sai 1 cau mat 1 mang,
// het mang thi ket thuc va luu STREAK (so cau dung LIEN TIEP tot nhat)
// len BXH rieng (/survival/submit, xem backend — score = MAX khong cong
// don qua nhieu luot).
Color _parseHexColor(String hex) => Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

class _SurvivalScreen extends StatefulWidget {
  const _SurvivalScreen();
  @override
  State<_SurvivalScreen> createState() => _SurvivalScreenState();
}

class _SurvivalScreenState extends State<_SurvivalScreen> {
  final _storage = const FlutterSecureStorage();
  static const _maxLives = 3;

  int _lives = _maxLives;
  int _streak = 0;
  int _bestStreakThisRun = 0;
  int _totalScore = 0;
  bool _isLoadingPhrase = true;
  bool _loadFailed = false;
  bool _isRecording = false;
  bool _isScoring = false;
  bool _gameOver = false;
  Map<String, dynamic>? _phrase;
  ScoreResult? _lastResult;
  late DateTime _startTime;
  bool _isSavingResult = false;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadNextPhrase();
  }

  Future<void> _loadNextPhrase() async {
    setState(() { _isLoadingPhrase = true; _loadFailed = false; _lastResult = null; });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/pronunciation/survival/next-phrase',
        queryParameters: _phrase != null ? {'exclude_id': _phrase!['id']} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() { _phrase = res.data; _isLoadingPhrase = false; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingPhrase = false; _loadFailed = true; });
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isScoring || _phrase == null) return;
    setState(() => _isRecording = true);
    HapticFeedback.lightImpact();
    await webStartRecording(
      (audioBase64) => _submitAudio(audioBase64),
      (error) => setState(() => _isRecording = false),
    );
  }

  void _stopRecording() {
    webStopRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _submitAudio(String audioBase64) async {
    if (_phrase == null) return;
    setState(() { _isRecording = false; _isScoring = true; });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)));
      final res = await dio.post(
        '${ApiConstants.baseUrl}/pronunciation/score',
        data: {
          'audio_base64': audioBase64,
          'phrase_id': _phrase!['id'],
          'phrase_text': _phrase!['text'],
          'phrase_pinyin': _phrase!['pinyin'],
          'phrase_meaning': _phrase!['meaning'],
          'boss_id': _phrase!['boss_id'],
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final result = ScoreResult.fromJson(res.data);
      setState(() { _lastResult = result; _isScoring = false; });

      // Bi Gate tu choi — KHONG mat mang, chi can noi lai CUNG cau nay.
      if (result.gateRejected) return;

      if (result.score >= 70) {
        HapticFeedback.lightImpact();
        setState(() {
          _streak++;
          if (_streak > _bestStreakThisRun) _bestStreakThisRun = _streak;
          _totalScore += result.score;
        });
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted && !_gameOver) _loadNextPhrase();
      } else {
        HapticFeedback.heavyImpact();
        _streak = 0;
        final newLives = _lives - 1;
        setState(() => _lives = newLives);
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        if (newLives <= 0) {
          _endGame();
        } else {
          _loadNextPhrase();
        }
      }
    } on DioException catch (e) {
      setState(() => _isScoring = false);
      if (e.response?.statusCode == 403) {
        if (mounted) showDialog(context: context, builder: (_) => const PaywallScreen());
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi chấm điểm. Thử lại!'), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isScoring = false);
    }
  }

  Future<void> _endGame() async {
    setState(() { _gameOver = true; _isSavingResult = true; });
    try {
      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        '${ApiConstants.baseUrl}/pronunciation/survival/submit',
        data: {'streak': _bestStreakThisRun, 'total_score': _totalScore, 'time_seconds': elapsed},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {}
    if (mounted) setState(() => _isSavingResult = false);
  }

  void _restart() {
    setState(() {
      _lives = _maxLives; _streak = 0; _bestStreakThisRun = 0; _totalScore = 0;
      _gameOver = false; _phrase = null; _startTime = DateTime.now();
    });
    _loadNextPhrase();
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver) return _buildGameOver();

    final bossColor = _phrase != null ? _parseHexColor(_phrase!['boss_color']) : _DS.red;

    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.close_rounded, color: _DS.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Text('🌊 Sinh Tồn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _DS.white)),
              const Spacer(),
              _HeartRow(lives: _lives, maxLives: _maxLives),
            ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _DS.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('Streak: $_streak', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.orange)),
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _DS.yellow.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Text('⭐', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text('$_totalScore', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.yellow)),
              ]),
            ),
          ]),
          Expanded(
            child: Center(
              child: _isLoadingPhrase
                  ? const CircularProgressIndicator(color: _DS.red)
                  : _loadFailed
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('😢 Không tải được câu tiếp theo.', style: TextStyle(color: _DS.textGrey)),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _loadNextPhrase,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(color: _DS.red, borderRadius: BorderRadius.circular(14)),
                              child: const Text('Thử lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ])
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: bossColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                              child: Text('${_phrase!['boss_emoji']} ${_phrase!['boss_name']}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: bossColor)),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: bossColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: bossColor.withOpacity(0.2)),
                              ),
                              child: Column(children: [
                                Text(_phrase!['text'], textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: _DS.white, fontFamily: 'NotoSansTC')),
                                const SizedBox(height: 6),
                                Text(_phrase!['pinyin'], style: TextStyle(fontSize: 14, color: bossColor, fontStyle: FontStyle.italic)),
                                const SizedBox(height: 4),
                                Text(_phrase!['meaning'], style: const TextStyle(fontSize: 13, color: _DS.textGrey)),
                              ]),
                            ),
                            const SizedBox(height: 20),
                            if (_lastResult != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (_lastResult!.gateRejected ? _DS.yellow : (_lastResult!.isCorrect ? _DS.green : _DS.red)).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: _lastResult!.gateRejected
                                    ? Text(_lastResult!.feedbackVi, textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 13, color: _DS.white, fontWeight: FontWeight.w700))
                                    : Column(children: [
                                        Text('${_lastResult!.score}/100', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                                            color: _lastResult!.isCorrect ? _DS.green : _DS.red)),
                                        const SizedBox(height: 4),
                                        Text(_lastResult!.feedbackVi, style: const TextStyle(fontSize: 12, color: _DS.white)),
                                      ]),
                              ),
                              const SizedBox(height: 16),
                            ],
                            GestureDetector(
                              onTapDown: (_) => _startRecording(),
                              onTapUp: (_) => _stopRecording(),
                              onTapCancel: () => _stopRecording(),
                              child: _isScoring
                                  ? Container(
                                      width: 90, height: 90,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _DS.card),
                                      child: const Center(child: CircularProgressIndicator(color: _DS.red, strokeWidth: 3)),
                                    )
                                  : AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: _isRecording ? 100 : 90,
                                      height: _isRecording ? 100 : 90,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: _isRecording
                                            ? [_DS.red, const Color(0xFFB71C1C)]
                                            : [bossColor, bossColor.withOpacity(0.7)]),
                                        boxShadow: [BoxShadow(
                                          color: (_isRecording ? _DS.red : bossColor).withOpacity(0.5),
                                          blurRadius: _isRecording ? 26 : 14, spreadRadius: _isRecording ? 3 : 0,
                                        )],
                                      ),
                                      child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 34),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(_isRecording ? 'Thả để gửi' : 'Giữ để nói',
                                style: const TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                          ]),
                        ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGameOver() {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('💀', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              const Text('Hết mạng rồi!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _DS.white)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _StatBox(label: '🔥 Streak tốt nhất', value: '$_bestStreakThisRun', color: _DS.orange)),
                const SizedBox(width: 10),
                Expanded(child: _StatBox(label: '⭐ Điểm', value: '$_totalScore', color: _DS.yellow)),
              ]),
              const SizedBox(height: 24),
              if (_isSavingResult) const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _DS.red)),
              ),
              GestureDetector(
                onTap: _restart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.red, Color(0xFFB71C1C)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Chơi lại', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ]),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: const Text('Thoát', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _DS.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HeartRow extends StatelessWidget {
  final int lives;
  final int maxLives;
  const _HeartRow({required this.lives, required this.maxLives});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(maxLives, (i) => Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Text(i < lives ? '❤️' : '🖤', style: const TextStyle(fontSize: 18)),
    )),
  );
}

// ─── Helper Widgets ───────────────────────────────────────────
class _FeedbackChip extends StatelessWidget {
  final String label;
  final bool ok;
  const _FeedbackChip({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: (ok ? _DS.green : _DS.red).withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(ok ? '✅' : '❌', style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ok ? _DS.green : _DS.red)),
    ]),
  );
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2))),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
    ]),
  );
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _DS.indigo : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w800,
        color: selected ? Colors.white : _DS.textGrey,
      )),
    ),
  );
}

class _GhostProgressBar extends StatelessWidget {
  final GhostRun ghost;
  final int myPhrasesDone;
  final int totalPhrases;
  final double elapsedSeconds;
  const _GhostProgressBar({required this.ghost, required this.myPhrasesDone,
    required this.totalPhrases, required this.elapsedSeconds});

  @override
  Widget build(BuildContext context) {
    final ghostDone = ghost.phrasesCompletedAt(elapsedSeconds);
    final diff = myPhrasesDone - ghostDone;
    final leading = diff > 0 ? 'Bạn đang dẫn trước!' : diff < 0 ? 'Bóng ma đang dẫn trước!' : 'Đang ngang bóng ma!';
    final leadColor = diff > 0 ? _DS.green : diff < 0 ? _DS.red : _DS.yellow;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C4DFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7C4DFF).withOpacity(0.25)),
      ),
      child: Column(children: [
        Row(children: [
          const Text('👻', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Expanded(child: Text('Bóng ma của ${ghost.displayName}',
              style: const TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
          Text(leading, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: leadColor)),
        ]),
        const SizedBox(height: 8),
        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(4))),
          // Vach danh dau vi tri bong ma
          FractionallySizedBox(
            widthFactor: totalPhrases == 0 ? 0 : (ghostDone / totalPhrases).clamp(0.0, 1.0),
            child: Container(height: 8, decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.5), width: 2)),
            )),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 8,
            width: (MediaQuery.of(context).size.width - 64) * (totalPhrases == 0 ? 0 : (myPhrasesDone / totalPhrases).clamp(0.0, 1.0)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C4DFF), _DS.indigo]),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ]),
      ]),
    );
  }
}