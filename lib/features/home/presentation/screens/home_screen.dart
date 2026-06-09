import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// ─── Design System ────────────────────────────────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const green = Color(0xFF00C853);
  static const blue = Color(0xFF2979FF);
  static const pink = Color(0xFFE91E8C);
  static const orange = Color(0xFFFF6D00);
  static const yellow = Color(0xFFFFB300);
  static const purple = Color(0xFF651FFF);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── Feedback/Rating Service ──────────────────────────────────
class _RatingService {
  static const _storage = FlutterSecureStorage();

  static const _keySessionCount = 'rating_session_count';
  static const _keyFirstOpenDate = 'rating_first_open_date';
  static const _keyLastPromptDate = 'rating_last_prompt_date';
  static const _keyRated = 'rating_rated';

  static Future<void> trackSession() async {
    final rated = await _storage.read(key: _keyRated);
    if (rated == 'true') return;

    final firstOpen = await _storage.read(key: _keyFirstOpenDate);
    if (firstOpen == null) {
      await _storage.write(
        key: _keyFirstOpenDate,
        value: DateTime.now().toIso8601String(),
      );
    }

    final countStr = await _storage.read(key: _keySessionCount) ?? '0';
    final count = int.parse(countStr) + 1;
    await _storage.write(key: _keySessionCount, value: count.toString());
  }

  static Future<bool> shouldShowPrompt() async {
    final rated = await _storage.read(key: _keyRated);
    if (rated == 'true') return false;

    final countStr = await _storage.read(key: _keySessionCount) ?? '0';
    final count = int.parse(countStr);

    final firstOpenStr = await _storage.read(key: _keyFirstOpenDate);
    final firstOpen = firstOpenStr != null
        ? DateTime.parse(firstOpenStr)
        : DateTime.now();
    final daysSinceFirst = DateTime.now().difference(firstOpen).inDays;

    final lastPromptStr = await _storage.read(key: _keyLastPromptDate);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      final daysSinceLast = DateTime.now().difference(lastPrompt).inDays;
      if (daysSinceLast < 3) return false;
    }

    return count >= 5 || daysSinceFirst >= 3;
  }

  static Future<void> markPromptShown() async {
    await _storage.write(
      key: _keyLastPromptDate,
      value: DateTime.now().toIso8601String(),
    );
  }

  static Future<void> markRated() async {
    await _storage.write(key: _keyRated, value: 'true');
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _streak = 0, _xp = 0, _vocabCount = 0;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _loadUserStats();
    _checkFeedback();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Mở Google Form feedback ────────────────────────────────
  Future<void> _launchFeedbackForm() async {
    final Uri url = Uri.parse(
      'https://docs.google.com/forms/d/1YKj_ZylAtoMWmzQyn2yfILTAnXp50VmnqRcp9RwDsrc/viewform',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được form, thử lại nhé!')),
        );
      }
    }
  }

  // ── Feedback popup logic ───────────────────────────────────
  Future<void> _checkFeedback() async {
    await _RatingService.trackSession();
    final should = await _RatingService.shouldShowPrompt();
    if (should && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _showFeedbackDialog();
    }
  }

  void _showFeedbackDialog() {
    _RatingService.markPromptShown();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2979FF), Color(0xFF00C853)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('💬', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 16),
            const Text(
              'Góp ý cho TaiwanMate!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ý kiến của bạn giúp app\nngày càng tốt hơn 🙏',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DS.textGrey, height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Nút Góp ý ngay
            GestureDetector(
              onTap: () async {
                Navigator.pop(dialogCtx);
                await _RatingService.markRated();
                await _launchFeedbackForm();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2979FF), Color(0xFF00C853)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF2979FF).withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('📝', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text('Góp ý ngay!',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(height: 10),

            // Nút Để sau
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Để sau', style: TextStyle(color: _DS.textGrey, fontSize: 14)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Load stats ─────────────────────────────────────────────
  Future<void> _loadUserStats() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final vocabRes = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() {
        _streak = res.data['streak_days'] ?? 0;
        _xp = res.data['total_xp'] ?? 0;
        _vocabCount = (vocabRes.data as List)
            .where((w) => (w['srs_level'] as num? ?? 0) > 0)
            .length;
      });
    } catch (_) {}
    if (mounted) _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _anim,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildStreakBanner(),
                const SizedBox(height: 20),
                _buildStatRow(),
                const SizedBox(height: 26),
                _buildLabel('Tính năng chính'),
                const SizedBox(height: 14),
                _buildFeatureGrid(),
                const SizedBox(height: 26),
                _buildLabel('Từ vựng hôm nay'),
                const SizedBox(height: 12),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _WordOfDayCard()),
                const SizedBox(height: 26),
                _buildLabel('Gợi ý cho bạn'),
                const SizedBox(height: 12),
                _buildTips(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xin chào! 👋', style: TextStyle(fontSize: 13, color: _DS.textGrey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('TaiwanMate', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _DS.textDark, letterSpacing: -0.5)),
            ],
          ),
          Row(
            children: [
              // Nút feedback icon — bấm thủ công mở form bất kỳ lúc nào
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, color: _DS.textGrey),
                tooltip: 'Góp ý',
                onPressed: _launchFeedbackForm,
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF667EEA).withOpacity(0.4),
                      blurRadius: 10, offset: const Offset(0, 4),
                    )],
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)], begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('🔥', style: TextStyle(fontSize: 28))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_streak ngày liên tiếp!', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 3),
          Text('Tiếp tục duy trì streak nhé 💪', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
        ])),
        GestureDetector(
          onTap: () => context.go('/learn'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: const Text('Học ngay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF6B35))),
          ),
        ),
      ]),
    ),
  );

  Widget _buildStatRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Expanded(child: _StatCard(icon: '⭐', value: '$_xp', label: 'Điểm XP', color: _DS.yellow, bg: const Color(0xFFFFF8E1))),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(icon: '📚', value: '$_vocabCount', label: 'Từ đã học', color: _DS.blue, bg: const Color(0xFFE8F0FF))),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(icon: '🏆', value: 'A1', label: 'Cấp độ', color: _DS.purple, bg: const Color(0xFFF0EBFF))),
    ]),
  );

  Widget _buildLabel(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textDark, letterSpacing: -0.3)),
  );

  Widget _buildFeatureGrid() {
    final items = [
      {'icon': '🌐', 'label': 'Dịch thuật', 'sub': 'Text • Ảnh • Giọng nói', 'zh': '翻譯', 'route': '/translate',
        'c1': const Color(0xFF1565C0), 'c2': const Color(0xFF1E88E5)},
      {'icon': '🧠', 'label': 'Học từ vựng', 'sub': 'Flashcard & Quiz', 'zh': '學習', 'route': '/learn',
        'c1': const Color(0xFF2E7D32), 'c2': const Color(0xFF43A047)},
      {'icon': '🤖', 'label': 'Chat AI', 'sub': '小美 & 小明', 'zh': '聊天', 'route': '/chat',
        'c1': const Color(0xFFAD1457), 'c2': const Color(0xFFE91E8C)},
      {'icon': '🔧', 'label': 'Công cụ AI', 'sub': '7 công cụ thông minh', 'zh': '工具', 'route': '/tools',
        'c1': const Color(0xFFE65100), 'c2': const Color(0xFFFF6D00)},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.4,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final d = items[i];
          return GestureDetector(
            onTap: () => context.go(d['route'] as String),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [d['c1'] as Color, d['c2'] as Color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(_DS.radius),
                boxShadow: [BoxShadow(color: (d['c2'] as Color).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 5))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_DS.radius),
                child: Stack(children: [
                  Positioned(
                    right: -6, bottom: -14,
                    child: Text(d['zh'] as String, style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.13), height: 1)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['icon'] as String, style: const TextStyle(fontSize: 28)),
                      const Spacer(),
                      Text(d['label'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(d['sub'] as String, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTips() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(children: [
      _TipCard(icon: '💬', title: 'Chat với 小美', desc: 'Luyện hội thoại tự nhiên với bạn AI người Đài Loan', color: _DS.pink, onTap: () => context.go('/chat')),
      const SizedBox(height: 10),
      _TipCard(icon: '📝', title: 'Dịch hợp đồng lao động', desc: 'Hiểu rõ điều khoản hợp đồng trước khi ký', color: _DS.orange, onTap: () => context.go('/tools')),
    ]),
  );
}

// ─── Stat Card ────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String icon, value, label;
  final Color color, bg;
  const _StatCard({required this.icon, required this.value, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(_DS.radiusSm)),
    child: Column(children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  );
}

// ─── Tip Card ─────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  final String icon, title, desc;
  final Color color;
  final VoidCallback onTap;
  const _TipCard({required this.icon, required this.title, required this.desc, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _DS.textDark)),
          const SizedBox(height: 3),
          Text(desc, style: TextStyle(fontSize: 12, color: _DS.textGrey, height: 1.4)),
        ])),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: color),
        ),
      ]),
    ),
  );
}

// ─── Word of Day Card ─────────────────────────────────────────
class _WordOfDayCard extends StatelessWidget {
  const _WordOfDayCard();
  static const _words = [
    {'zh': '你好', 'vi': 'Xin chào', 'emoji': '👋', 'c': 0xFF00C853},
    {'zh': '謝謝', 'vi': 'Cảm ơn', 'emoji': '🙏', 'c': 0xFF2979FF},
    {'zh': '朋友', 'vi': 'Bạn bè', 'emoji': '👫', 'c': 0xFFE91E8C},
    {'zh': '工作', 'vi': 'Công việc', 'emoji': '💼', 'c': 0xFFFF6D00},
    {'zh': '學習', 'vi': 'Học tập', 'emoji': '📖', 'c': 0xFF651FFF},
    {'zh': '臺灣', 'vi': 'Đài Loan', 'emoji': '🇹🇼', 'c': 0xFF2979FF},
    {'zh': '美食', 'vi': 'Ẩm thực', 'emoji': '🍜', 'c': 0xFFFF6D00},
  ];

  @override
  Widget build(BuildContext context) {
    final w = _words[DateTime.now().day % _words.length];
    final color = Color(w['c'] as int);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(child: Text(w['zh'] as String, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(w['emoji'] as String, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(w['vi'] as String, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textDark)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('Từ hôm nay', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
        ])),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.volume_up_rounded, size: 20, color: color),
        ),
      ]),
    );
  }
}
