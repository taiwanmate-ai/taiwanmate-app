import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/pronunciation/boss/${boss.id}/battle',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      battleBoss = Boss.fromJson(res.data);
    } catch (_) {
      // Nếu lỗi, dùng tạm boss gốc (5 câu đầu) để không chặn user chơi
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BattleScreen(boss: battleBoss, storage: _storage, isDaily: isDaily),
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
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🏟️ Đấu Trường', style: TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                const Text('Chinh phục Boss', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.white)),
              ]),
              const Spacer(),
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
          color: _DS.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDaily ? boss.color.withOpacity(0.5) : Colors.white.withOpacity(0.05), width: isDaily ? 2 : 1),
          boxShadow: [BoxShadow(color: boss.color.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: boss.color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: boss.color.withOpacity(0.3), width: 2),
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
  const _BattleScreen({required this.boss, required this.storage, this.isDaily = false});

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
  }

  @override
  void dispose() {
    _critHitCtrl.dispose();
    _shakeCtrl.dispose();
    _comboCtrl.dispose();
    super.dispose();
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
        setState(() { _lastResult = result; _isScoring = false; });
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
        });
      } else {
        _combo = 0;
        _retryFailCount++;
        HapticFeedback.heavyImpact();
        _shakeCtrl.forward(from: 0).then((_) => _shakeCtrl.reset());
        setState(() {
          _lastResult = result;
          _isScoring = false;
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
    _retryFailCount = 0;
    if (_currentIndex + 1 >= widget.boss.phrases.length) {
      setState(() => _battleFinished = true);
      _submitResult();
    } else {
      setState(() {
        _currentIndex++;
        _lastResult = null;
      });
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

                    // Phrase to pronounce
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.boss.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: widget.boss.color.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        Text(phrase.text, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w500, color: _DS.white, fontFamily: 'NotoSansTC')),
                        const SizedBox(height: 6),
                        Text(phrase.pinyin, style: TextStyle(fontSize: 14, color: widget.boss.color, fontStyle: FontStyle.italic)),
                        const SizedBox(height: 4),
                        Text(phrase.meaning, style: const TextStyle(fontSize: 13, color: _DS.textGrey)),
                      ]),
                    ),
                  ]),
                ),
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