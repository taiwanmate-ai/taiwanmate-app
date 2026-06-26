// ════════════════════════════════════════════════════════════════
// JOURNEY TAB v2 — "30 NGÀY SINH TỒN TẠI ĐÀI LOAN"
// Mỗi ngày = 1 ải đời thực, gồm 4 màn:
//   1. 🎬 Bối cảnh (kể chuyện)
//   2. 📚 Trang bị (câu chủ chốt + nghe phát âm)
//   3. 🗣️ Thực chiến (nhập vai, chọn câu đáp đúng — KỊCH BẢN CỐ ĐỊNH, $0 API)
//   4. 🛡️ Mẹo sinh tồn + Vượt ải (huy hiệu, mở khóa ngày sau)
//
// CHI PHÍ: nội dung hard-code + nghe dùng TTS có cache → ~$0 dù scale.
// Song ngữ: _lang=='en' học tiếng Anh, ngược lại tiếng Trung. Giải thích luôn tiếng Việt.
// Khóa chặng: ngày N+1 mở khi hoàn thành ngày N. Lưu secure_storage.
// ════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:chinesemate/core/utils/web_utils.dart';

// ─── Design System (đồng bộ app) ──────────────────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const purple = Color(0xFF7C4DFF);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const yellow = Color(0xFFFFB300);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── MODELS ───────────────────────────────────────────────────
// Câu chủ chốt (màn Trang bị)
class _Equip {
  final String zh;   // câu tiếng Trung (hoặc Anh nếu lang en — xem getter)
  final String en;   // câu tiếng Anh
  final String py;   // pinyin (hoặc ipa)
  final String ipa;  // ipa cho tiếng Anh
  final String vi;   // nghĩa tiếng Việt (luôn hiển thị)
  const _Equip({required this.zh, required this.en, required this.py, this.ipa = '', required this.vi});
}

// 1 lượt hội thoại nhập vai (màn Thực chiến)
class _Turn {
  final String npc;      // câu nhân vật nói (Trung)
  final String npcEn;    // câu nhân vật nói (Anh)
  final String npcVi;    // dịch Việt câu nhân vật
  final List<String> options;    // 3 đáp án (Trung) — index 0 luôn là ĐÚNG, sẽ shuffle khi hiện
  final List<String> optionsEn;  // 3 đáp án (Anh)
  final String hintVi;   // gợi ý nghĩa đáp đúng
  const _Turn({required this.npc, required this.npcEn, required this.npcVi,
      required this.options, required this.optionsEn, required this.hintVi});
}

// 1 ngày
class _Day {
  final int day;
  final String emoji;
  final String titleVi;
  final String titleEn;
  final String sceneVi;   // bối cảnh tiếng Việt
  final String sceneEn;   // bối cảnh tiếng Anh
  final List<_Equip> equips;
  final List<_Turn> turns;
  final String tipVi;     // mẹo sinh tồn (Việt)
  final String tipEn;     // mẹo sinh tồn (Anh)
  final String badgeVi;   // tên huy hiệu (Việt)
  final String badgeEn;   // tên huy hiệu (Anh)
  const _Day({required this.day, required this.emoji, required this.titleVi, required this.titleEn,
      required this.sceneVi, required this.sceneEn, required this.equips, required this.turns,
      required this.tipVi, required this.tipEn, required this.badgeVi, required this.badgeEn});
}

// ════════════════════════════════════════════════════════════════
// DỮ LIỆU — 3 NGÀY MẪU (1, 7, 21). 27 ngày còn lại bổ sung sau khi duyệt.
// ════════════════════════════════════════════════════════════════
const List<_Day> _journeyDays = [
  // ─────────── NGÀY 1: Chào hỏi (dễ) ───────────
  _Day(
    day: 1, emoji: '👋',
    titleVi: 'Lần đầu chào hỏi', titleEn: 'First Greetings',
    sceneVi: 'Bạn vừa đặt chân đến Đài Loan. Trong ký túc xá, một người Đài Loan mỉm cười tiến lại gần bạn. Đây là lần đầu bạn phải mở miệng nói tiếng Trung...',
    sceneEn: 'You just arrived in Taiwan. In the dorm, a Taiwanese person smiles and walks toward you. This is your first time speaking Chinese...',
    equips: [
      _Equip(zh: '你好', en: 'Hello', py: 'nǐ hǎo', ipa: '/həˈloʊ/', vi: 'Xin chào'),
      _Equip(zh: '我叫阿海', en: 'My name is Hai', py: 'wǒ jiào ā hǎi', ipa: '/maɪ neɪm ɪz/', vi: 'Tôi tên là Hải'),
      _Equip(zh: '我是越南人', en: 'I am Vietnamese', py: 'wǒ shì yuè nán rén', ipa: '/aɪ æm/', vi: 'Tôi là người Việt Nam'),
      _Equip(zh: '認識你很高興', en: 'Nice to meet you', py: 'rèn shi nǐ hěn gāo xìng', ipa: '/naɪs tu mit ju/', vi: 'Rất vui được gặp bạn'),
    ],
    turns: [
      _Turn(
        npc: '你好！你叫什麼名字？', npcEn: 'Hello! What is your name?',
        npcVi: 'Xin chào! Bạn tên gì?',
        options: ['你好，我叫阿海', '多少錢？', '再見'],
        optionsEn: ['Hello, my name is Hai', 'How much?', 'Goodbye'],
        hintVi: 'Chào lại và giới thiệu tên',
      ),
      _Turn(
        npc: '你是哪裡人？', npcEn: 'Where are you from?',
        npcVi: 'Bạn là người nước nào?',
        options: ['我是越南人', '我餓了', '我不知道'],
        optionsEn: ['I am Vietnamese', 'I am hungry', "I don't know"],
        hintVi: 'Nói bạn đến từ Việt Nam',
      ),
      _Turn(
        npc: '歡迎來台灣！', npcEn: 'Welcome to Taiwan!',
        npcVi: 'Chào mừng đến Đài Loan!',
        options: ['認識你很高興', '太貴了', '我要走了'],
        optionsEn: ['Nice to meet you', 'Too expensive', 'I am leaving'],
        hintVi: 'Đáp lại lịch sự: rất vui được gặp',
      ),
    ],
    tipVi: 'Người Đài Loan rất thân thiện với người mới. Một câu "你好" kèm nụ cười mở ra rất nhiều thiện cảm. Đừng sợ nói sai — họ luôn kiên nhẫn với người nước ngoài.',
    tipEn: 'Taiwanese people are very friendly to newcomers. A simple "Hello" with a smile opens many doors. Don\'t be afraid of mistakes.',
    badgeVi: 'Đã biết chào hỏi', badgeEn: 'Greeting Master',
  ),

  // ─────────── NGÀY 7: Khám bệnh (trung bình) ───────────
  _Day(
    day: 7, emoji: '🏥',
    titleVi: 'Đi khám ở bệnh viện', titleEn: 'Visit the Hospital',
    sceneVi: 'Bạn sốt 3 ngày liền, người mệt rũ. Hôm nay bắt buộc phải đến phòng khám. Cửa kính tự động mở, một y tá nhìn bạn và hỏi điều gì đó...',
    sceneEn: 'You\'ve had a fever for 3 days and feel exhausted. You must visit a clinic today. The glass door opens, a nurse looks at you and asks something...',
    equips: [
      _Equip(zh: '我生病了', en: 'I am sick', py: 'wǒ shēng bìng le', ipa: '/aɪ æm sɪk/', vi: 'Tôi bị bệnh'),
      _Equip(zh: '我發燒', en: 'I have a fever', py: 'wǒ fā shāo', ipa: '/aɪ hæv ə ˈfivər/', vi: 'Tôi bị sốt'),
      _Equip(zh: '健保卡', en: 'Health insurance card', py: 'jiàn bǎo kǎ', ipa: '/hɛlθ ɪnˈʃʊrəns/', vi: 'Thẻ bảo hiểm y tế'),
      _Equip(zh: '我要看醫生', en: 'I need to see a doctor', py: 'wǒ yào kàn yī shēng', ipa: '/aɪ nid tu si/', vi: 'Tôi cần gặp bác sĩ'),
      _Equip(zh: '謝謝醫生', en: 'Thank you doctor', py: 'xiè xie yī shēng', ipa: '/θæŋk ju/', vi: 'Cảm ơn bác sĩ'),
    ],
    turns: [
      _Turn(
        npc: '你好，哪裡不舒服？', npcEn: 'Hello, what\'s wrong?',
        npcVi: 'Xin chào, bạn thấy chỗ nào khó chịu?',
        options: ['我生病了，我發燒', '多少錢？', '我要租房子'],
        optionsEn: ['I am sick, I have a fever', 'How much?', 'I want to rent'],
        hintVi: 'Nói bạn bị bệnh và sốt',
      ),
      _Turn(
        npc: '有帶健保卡嗎？', npcEn: 'Did you bring your health card?',
        npcVi: 'Bạn có mang thẻ bảo hiểm y tế không?',
        options: ['有，這是我的健保卡', '我不喜歡', '太遠了'],
        optionsEn: ['Yes, here is my health card', "I don't like it", 'Too far'],
        hintVi: 'Có — đưa thẻ 健保卡 ra',
      ),
      _Turn(
        npc: '請稍等，醫生馬上來', npcEn: 'Please wait, the doctor is coming',
        npcVi: 'Vui lòng đợi chút, bác sĩ đến ngay',
        options: ['好的，謝謝', '不要', '我走了'],
        optionsEn: ['Okay, thank you', 'No', 'I am leaving'],
        hintVi: 'Đồng ý và cảm ơn',
      ),
    ],
    tipVi: 'LUÔN mang theo thẻ 健保卡 (bảo hiểm y tế) khi đi khám — có thẻ chỉ trả ~150-400 NTD, không có thẻ phải trả gấp 3-5 lần. Nếu chưa có thẻ, gọi 1955 để được hướng dẫn đăng ký.',
    tipEn: 'ALWAYS bring your health insurance card. With it you pay ~150-400 NTD; without it, 3-5 times more. Call 1955 for help registering.',
    badgeVi: 'Đã biết đi khám bệnh', badgeEn: 'Hospital Survivor',
  ),

  // ─────────── NGÀY 21: Bị quỵt lương (khó) ───────────
  _Day(
    day: 21, emoji: '⚖️',
    titleVi: 'Khi bị quỵt lương', titleEn: 'When Wages Are Withheld',
    sceneVi: 'Cuối tháng, bạn kiểm tra tài khoản — không có lương. Bạn hỏi chủ, ông ta nói "tháng sau trả". Đây là lúc bạn phải biết cách tự bảo vệ mình...',
    sceneEn: 'End of month, you check your account — no salary. The boss says "next month". This is when you must know how to protect yourself...',
    equips: [
      _Equip(zh: '我的薪水', en: 'My salary', py: 'wǒ de xīn shuǐ', ipa: '/maɪ ˈsæləri/', vi: 'Lương của tôi'),
      _Equip(zh: '還沒給我', en: 'Not paid yet', py: 'hái méi gěi wǒ', ipa: '/nɑt peɪd jɛt/', vi: 'Vẫn chưa trả cho tôi'),
      _Equip(zh: '這是我的權利', en: 'This is my right', py: 'zhè shì wǒ de quán lì', ipa: '/maɪ raɪt/', vi: 'Đây là quyền của tôi'),
      _Equip(zh: '我會打電話給一九五五', en: 'I will call 1955', py: 'wǒ huì dǎ diàn huà gěi yī jiǔ wǔ wǔ', ipa: '/kɔl/', vi: 'Tôi sẽ gọi 1955'),
    ],
    turns: [
      _Turn(
        npc: '薪水下個月再給你', npcEn: 'I\'ll pay you next month',
        npcVi: 'Lương tháng sau tôi trả cho',
        options: ['我的薪水還沒給我，這是我的權利', '好的沒關係', '謝謝老闆'],
        optionsEn: ['My salary is not paid, this is my right', 'Okay no problem', 'Thank you boss'],
        hintVi: 'Khẳng định quyền của mình, KHÔNG nhượng bộ',
      ),
      _Turn(
        npc: '你敢跟我頂嘴？', npcEn: 'You dare talk back?',
        npcVi: 'Mày dám cãi tao à?',
        options: ['我會打電話給一九五五', '對不起', '我不說了'],
        optionsEn: ['I will call 1955', 'Sorry', "I won't speak"],
        hintVi: 'Cho biết bạn sẽ gọi đường dây 1955',
      ),
    ],
    tipVi: 'Chủ KHÔNG được giữ lương bạn. Gọi NGAY 1955 (miễn phí, có tiếng Việt, 24/7) — đây là đường dây bảo vệ lao động nước ngoài của chính phủ Đài Loan. Lưu bằng chứng: tin nhắn, bảng chấm công. ĐỪNG ký bất kỳ giấy gì khi chưa được tư vấn.',
    tipEn: 'Your boss CANNOT withhold your salary. Call 1955 immediately (free, Vietnamese support, 24/7). Save evidence. Don\'t sign anything before consulting.',
    badgeVi: 'Đã biết bảo vệ quyền lợi', badgeEn: 'Rights Defender',
  ),
];

// ════════════════════════════════════════════════════════════════
// WIDGET CHÍNH
// ════════════════════════════════════════════════════════════════
class JourneyTab extends StatefulWidget {
  final String lang;
  const JourneyTab({super.key, required this.lang});
  @override
  State<JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<JourneyTab> {
  final _storage = const FlutterSecureStorage();
  static const _key = 'journey_completed_days';
  Set<int> _completed = {};
  bool _loading = true;

  bool get _isEn => widget.lang == 'en';

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        _completed = raw.split(',').where((e) => e.isNotEmpty).map(int.parse).toSet();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markDone(int day) async {
    setState(() => _completed.add(day));
    try { await _storage.write(key: _key, value: _completed.join(',')); } catch (_) {}
  }

  // Ngày được mở khóa? Ngày đầu tiên trong list luôn mở. Ngày sau mở khi ngày trước đã xong.
  bool _isUnlocked(int index) {
    if (index == 0) return true;
    return _completed.contains(_journeyDays[index - 1].day);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _DS.orange));
    final done = _completed.length;
    final total = _journeyDays.length;

    return Column(children: [
      // Banner tiến độ
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🗺️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(_isEn ? '30-Day Survival' : '30 Ngày Sinh Tồn',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('$done/$total', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(_isEn ? 'Survive one real-life situation each day' : 'Mỗi ngày vượt qua một tình huống đời thực',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total, minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _journeyDays.length,
          itemBuilder: (context, i) => _buildDayCard(_journeyDays[i], _isUnlocked(i)),
        ),
      ),
    ]);
  }

  Widget _buildDayCard(_Day d, bool unlocked) {
    final isDone = _completed.contains(d.day);
    return GestureDetector(
      onTap: unlocked
          ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DayQuestScreen(day: d, isEn: _isEn, onComplete: () => _markDone(d.day))))
          : () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_isEn ? 'Complete the previous day first!' : 'Hoàn thành ngày trước đã!'),
                behavior: SnackBarBehavior.floating,
              ));
            },
      child: Opacity(
        opacity: unlocked ? 1 : 0.5,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radius),
            border: Border.all(color: isDone ? _DS.green.withOpacity(0.4) : Colors.transparent, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isDone ? _DS.greenLight : (unlocked ? _DS.orangeLight : _DS.bg),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: unlocked
                  ? Text(d.emoji, style: const TextStyle(fontSize: 24))
                  : const Icon(Icons.lock_rounded, color: _DS.textGrey, size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_isEn ? "Day" : "Ngày"} ${d.day}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.orange)),
              const SizedBox(height: 2),
              Text(_isEn ? d.titleEn : d.titleVi,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.textDark)),
            ])),
            if (isDone)
              const Icon(Icons.check_circle_rounded, color: _DS.green, size: 24)
            else if (unlocked)
              const Icon(Icons.chevron_right_rounded, color: _DS.textGrey, size: 24),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MÀN CHƠI 1 NGÀY — 4 bước: Bối cảnh → Trang bị → Thực chiến → Vượt ải
// ════════════════════════════════════════════════════════════════
class _DayQuestScreen extends StatefulWidget {
  final _Day day;
  final bool isEn;
  final VoidCallback onComplete;
  const _DayQuestScreen({required this.day, required this.isEn, required this.onComplete});
  @override
  State<_DayQuestScreen> createState() => _DayQuestScreenState();
}

class _DayQuestScreenState extends State<_DayQuestScreen> {
  final _storage = const FlutterSecureStorage();
  int _step = 0; // 0 bối cảnh, 1 trang bị, 2 thực chiến, 3 vượt ải

  // Thực chiến
  int _turnIndex = 0;
  int? _picked;
  bool _turnAnswered = false;
  late List<List<int>> _shuffledOrders; // thứ tự shuffle đáp án mỗi turn

  bool _playing = false;

  bool get _isEn => widget.isEn;
  _Day get d => widget.day;

  @override
  void initState() {
    super.initState();
    // Shuffle thứ tự đáp án cho mỗi turn (đáp đúng vốn ở index 0)
    _shuffledOrders = d.turns.map((t) {
      final order = List<int>.generate(t.options.length, (i) => i)..shuffle();
      return order;
    }).toList();
  }

  // Phát âm — dùng đúng pipeline TTS có cache của app ($0 khi scale)
  Future<void> _speak(String text) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.bytes));
      final res = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts',
        data: {'text': text, 'lang': _isEn ? 'en-US' : 'zh-TW', 'slow': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final b64 = base64Encode(res.data as List<int>);
      webEval('''
        (function(){
          if (window._journeyAudio) { window._journeyAudio.pause(); }
          var a = new Audio("data:audio/mpeg;base64,$b64");
          window._journeyAudio = a;
          a.play();
        })();
      ''');
    } catch (_) {
    } finally {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _playing = false);
    }
  }

  void _nextStep() => setState(() => _step++);

  void _pickAnswer(int displayIndex, int realIndex) {
    if (_turnAnswered) return;
    setState(() { _picked = displayIndex; _turnAnswered = true; });
  }

  void _nextTurn() {
    if (_turnIndex + 1 < d.turns.length) {
      setState(() { _turnIndex++; _picked = null; _turnAnswered = false; });
    } else {
      setState(() => _step = 3); // sang màn vượt ải
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _DS.textDark),
        title: Text('${_isEn ? "Day" : "Ngày"} ${d.day} · ${_isEn ? d.titleEn : d.titleVi}',
            style: const TextStyle(color: _DS.textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(child: _buildStep()),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildScene();
      case 1: return _buildEquip();
      case 2: return _buildBattle();
      default: return _buildVictory();
    }
  }

  // MÀN 1 — Bối cảnh
  Widget _buildScene() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Spacer(),
        Text(d.emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Text(_isEn ? d.sceneEn : d.sceneVi,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6, color: _DS.textDark, fontWeight: FontWeight.w500)),
        ),
        const Spacer(),
        _bigBtn(_isEn ? 'Start →' : 'Bắt đầu →', _nextStep),
      ]),
    );
  }

  // MÀN 2 — Trang bị
  Widget _buildEquip() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('📚', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(_isEn ? 'Equip these phrases' : 'Trang bị các câu sau',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
        ]),
      ),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        children: d.equips.map((e) {
          final main = _isEn ? e.en : e.zh;
          final phon = _isEn ? (e.ipa.isEmpty ? e.py : e.ipa) : e.py;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(main, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
                if (phon.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(phon, style: const TextStyle(fontSize: 13, color: _DS.orange, fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 4),
                Text(e.vi, style: const TextStyle(fontSize: 14, color: _DS.textGrey, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () => _speak(main),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: _DS.orangeLight, shape: BoxShape.circle),
                  child: const Icon(Icons.volume_up_rounded, color: _DS.orange, size: 22),
                ),
              ),
            ]),
          );
        }).toList(),
      )),
      Padding(
        padding: const EdgeInsets.all(20),
        child: _bigBtn(_isEn ? 'Ready to fight →' : 'Sẵn sàng thực chiến →', _nextStep),
      ),
    ]);
  }

  // MÀN 3 — Thực chiến (nhập vai)
  Widget _buildBattle() {
    final t = d.turns[_turnIndex];
    final order = _shuffledOrders[_turnIndex];
    final opts = _isEn ? t.optionsEn : t.options;

    return Column(children: [
      // Tiến độ hội thoại
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🗣️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('${_isEn ? "Conversation" : "Hội thoại"} ${_turnIndex + 1}/${d.turns.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _DS.textGrey, fontSize: 13)),
        ]),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Bong bóng NPC
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _DS.purple.withOpacity(0.15), shape: BoxShape.circle),
              child: const Center(child: Text('🧑', style: TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_isEn ? t.npcEn : t.npc,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark))),
                  GestureDetector(
                    onTap: () => _speak(_isEn ? t.npcEn : t.npc),
                    child: const Icon(Icons.volume_up_rounded, color: _DS.orange, size: 20),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(t.npcVi, style: const TextStyle(fontSize: 12, color: _DS.textGrey, fontStyle: FontStyle.italic)),
              ]),
            )),
          ]),
          const SizedBox(height: 20),
          // Gợi ý
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(child: Text(t.hintVi, style: const TextStyle(fontSize: 12, color: _DS.blue, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 16),
          Text(_isEn ? 'Choose your reply:' : 'Chọn câu đáp:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
          const SizedBox(height: 10),
          // 3 đáp án (shuffle); đúng = realIndex 0
          ...order.map((realIndex) {
            final displayIndex = order.indexOf(realIndex);
            final isCorrect = realIndex == 0;
            Color bg = _DS.white, border = Colors.grey.shade200, txt = _DS.textDark;
            Widget? icon;
            if (_turnAnswered) {
              if (isCorrect) { bg = _DS.greenLight; border = _DS.green; txt = _DS.green; icon = const Icon(Icons.check_circle_rounded, color: _DS.green, size: 20); }
              else if (_picked == displayIndex) { bg = _DS.redLight; border = _DS.red; txt = _DS.red; icon = const Icon(Icons.cancel_rounded, color: _DS.red, size: 20); }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _pickAnswer(displayIndex, realIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(_DS.radiusSm),
                      border: Border.all(color: border, width: _turnAnswered && (isCorrect || _picked == displayIndex) ? 2 : 1)),
                  child: Row(children: [
                    Expanded(child: Text(opts[realIndex], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: txt))),
                    if (icon != null) icon,
                  ]),
                ),
              ),
            );
          }),
        ]),
      )),
      if (_turnAnswered)
        Padding(
          padding: const EdgeInsets.all(20),
          child: _bigBtn(
            _turnIndex + 1 < d.turns.length
                ? (_isEn ? 'Next →' : 'Tiếp →')
                : (_isEn ? 'Finish →' : 'Hoàn thành →'),
            _nextTurn),
        ),
    ]);
  }

  // MÀN 4 — Vượt ải
  Widget _buildVictory() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 20),
        // Mẹo sinh tồn
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(_DS.radius),
              border: Border.all(color: _DS.orange.withOpacity(0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🛡️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(_isEn ? 'Survival Tip' : 'Mẹo sinh tồn',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.orange)),
            ]),
            const SizedBox(height: 10),
            Text(_isEn ? d.tipEn : d.tipVi,
                style: const TextStyle(fontSize: 14, height: 1.6, color: _DS.textDark)),
          ]),
        ),
        const Spacer(),
        // Huy hiệu
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Center(child: Text(d.emoji, style: const TextStyle(fontSize: 56))),
        ),
        const SizedBox(height: 16),
        Text(_isEn ? '🎉 Badge unlocked!' : '🎉 Mở khóa huy hiệu!',
            style: const TextStyle(fontSize: 14, color: _DS.textGrey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(_isEn ? d.badgeEn : d.badgeVi,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark),
            textAlign: TextAlign.center),
        const Spacer(),
        _bigBtn(_isEn ? 'Complete Day ${d.day} ✓' : 'Hoàn thành Ngày ${d.day} ✓', () {
          widget.onComplete();
          Navigator.pop(context);
        }),
      ]),
    );
  }

  // Nút lớn dùng chung
  Widget _bigBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}