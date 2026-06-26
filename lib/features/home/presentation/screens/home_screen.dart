import 'package:dio/dio.dart';
import 'package:chinesemate/features/home/presentation/screens/news_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class _DS {
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const indigoDeep = Color(0xFF1A1A4E);
  static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const green = Color(0xFF00C853);
  static const blue = Color(0xFF2979FF);
  static const pink = Color(0xFFE91E8C);
  static const orange = Color(0xFFFF6D00);
  static const yellow = Color(0xFFFFD166);
  static const purple = Color(0xFF651FFF);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

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
      await _storage.write(key: _keyFirstOpenDate, value: DateTime.now().toIso8601String());
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
    final firstOpen = firstOpenStr != null ? DateTime.parse(firstOpenStr) : DateTime.now();
    final daysSinceFirst = DateTime.now().difference(firstOpen).inDays;
    final lastPromptStr = await _storage.read(key: _keyLastPromptDate);
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      if (DateTime.now().difference(lastPrompt).inDays < 3) return false;
    }
    return count >= 5 || daysSinceFirst >= 3;
  }

  static Future<void> markPromptShown() async {
    await _storage.write(key: _keyLastPromptDate, value: DateTime.now().toIso8601String());
  }

  static Future<void> markRated() async {
    await _storage.write(key: _keyRated, value: 'true');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _streak = 0, _xp = 0, _vocabCount = 0;
  bool _isLoading = true;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Mission state
  bool _mission1 = false;
  bool _mission2 = false;
  bool _mission3 = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'Khuya rồi 🌙';
    if (h < 12) return 'Chào buổi sáng ☀️';
    if (h < 18) return 'Chào buổi chiều 👋';
    return 'Chào buổi tối 🌆';
  }

  String get _aiMood {
    final h = DateTime.now().hour;
    if (h < 10) return 'Sáng sớm rồi, học đi mày! ☕';
    if (h < 14) return 'Giờ này chưa học à? 😤';
    if (h < 20) return 'Tao đang chờ mày đó! 🔥';
    return 'Khuya rồi, học ít thôi nha 😴';
  }

  int get _missionsDone => [_mission1, _mission2, _mission3].where((m) => m).length;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadUserStats();
    _checkFeedback();
    Future.delayed(const Duration(seconds: 2), _loadNewsPreview);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchFeedbackForm() async {
    final Uri url = Uri.parse('https://docs.google.com/forms/d/1YKj_ZylAtoMWmzQyn2yfILTAnXp50VmnqRcp9RwDsrc/viewform');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không mở được form, thử lại nhé!')));
    }
  }

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
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('💬', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 16),
            const Text('Góp ý cho TaiwanMate!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Ý kiến của bạn giúp app\nngày càng tốt hơn 🙏',
                textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, height: 1.5, fontSize: 14)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async { Navigator.pop(dialogCtx); await _RatingService.markRated(); await _launchFeedbackForm(); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('📝', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text('Góp ý ngay!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Để sau', style: TextStyle(color: _DS.textGrey, fontSize: 14))),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadUserStats() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
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
        _vocabCount = (vocabRes.data as List).where((w) => (w['srs_level'] as num? ?? 0) > 0).length;
      });
   } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
    if (mounted) _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: _isLoading ? _buildSkeleton() : FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroBanner(),
              const SizedBox(height: 20),
              _buildMissionCard(),
              const SizedBox(height: 20),
              _buildStatRow(),
              const SizedBox(height: 24),
              _buildSectionLabel('Bạn cần gì hôm nay?'),
              const SizedBox(height: 14),
              _buildFeatureGrid(),
              const SizedBox(height: 24),
              _buildSectionLabel('Từ sinh tồn hôm nay'),
              const SizedBox(height: 12),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _WordOfDayCard()),
              const SizedBox(height: 24),
              _buildSectionLabel('📰 Tin tức sống còn'),
              const SizedBox(height: 12),
              _buildNewsPreview(),
              const SizedBox(height: 24),
              _buildSectionLabel('Gợi ý cho bạn'),
              const SizedBox(height: 12),
              _buildTips(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  // ── Skeleton loading — mô phỏng bố cục home khi đang tải ──
  Widget _buildSkeleton() {
    Widget box(double h, {double? w, double r = 12}) => Container(
          width: w, height: h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          // Hero banner
          box(160, w: double.infinity, r: 20),
          const SizedBox(height: 20),
          // Stat row
          Row(children: [
            Expanded(child: box(70, r: 16)),
            const SizedBox(width: 12),
            Expanded(child: box(70, r: 16)),
            const SizedBox(width: 12),
            Expanded(child: box(70, r: 16)),
          ]),
          const SizedBox(height: 24),
          // Section label
          box(20, w: 140),
          const SizedBox(height: 12),
          // Feature grid
          Row(children: [
            Expanded(child: box(120, r: 18)),
            const SizedBox(width: 12),
            Expanded(child: box(120, r: 18)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: box(90, r: 18)),
            const SizedBox(width: 12),
            Expanded(child: box(90, r: 18)),
          ]),
          const SizedBox(height: 24),
          // News
          box(20, w: 120),
          const SizedBox(height: 12),
          box(110, w: double.infinity, r: 18),
        ]),
      ),
    );
  }

  // ── HERO BANNER ───────────────────────────────────────────
  Widget _buildHeroBanner() {
    final size = MediaQuery.of(context).size;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _DS.indigoDeep,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFA78BFA), fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      const SizedBox(height: 4),
                      const Text('TaiwanMate',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    ],
                  ),
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.help_outline_rounded, color: Color(0xFFA78BFA)),
                      onPressed: _launchFeedbackForm,
                    ),
                    GestureDetector(
                      onTap: () => context.go('/profile'),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _DS.indigo,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.4), width: 1.5),
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ]),
                ],
              ),

              const SizedBox(height: 16),

              // AI mood + illustration row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // AI bubble
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Streak pill
                        if (_streak > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _DS.yellow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _DS.yellow.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => Transform.scale(
                                  scale: _pulseAnim.value,
                                  child: const Text('🔥', style: TextStyle(fontSize: 14)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('$_streak ngày streak',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.yellow)),
                            ]),
                          ),

                        // AI chat bubble
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _DS.indigo.withOpacity(0.3),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            border: Border.all(color: _DS.indigo.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Yuki', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFA78BFA), letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(_aiMood,
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, height: 1.4)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Chat now button
                        GestureDetector(
                          onTap: () => context.go('/chat'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: _DS.indigo,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('💬', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 6),
                              Text('Chat với Yuki', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Illustration
                  SizedBox(
                    width: size.width * 0.38,
                    height: size.width * 0.38,
                    child: Image.asset('assets/images/Digital_tools-rafiki.png', fit: BoxFit.contain),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MISSION CARD ──────────────────────────────────────────
  Widget _buildMissionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
          border: Border.all(color: _DS.indigo.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Nhiệm vụ hôm nay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.textDark)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _missionsDone == 3 ? _DS.green.withOpacity(0.1) : _DS.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$_missionsDone/3',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                          color: _missionsDone == 3 ? _DS.green : _DS.indigo)),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _missionsDone / 3,
                minHeight: 5,
                backgroundColor: _DS.indigo.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_missionsDone == 3 ? _DS.green : _DS.indigo),
              ),
            ),
            const SizedBox(height: 14),

            _buildMissionItem('Dịch 1 câu tiếng Trung', _mission1, () {
              setState(() => _mission1 = !_mission1);
              context.go('/translate');
            }),
            const SizedBox(height: 10),
            _buildMissionItem('Học 5 từ mới', _mission2, () {
              setState(() => _mission2 = !_mission2);
              context.go('/learn');
            }),
            const SizedBox(height: 10),
            _buildMissionItem('Chat 1 lượt với Yuki', _mission3, () {
              setState(() => _mission3 = !_mission3);
              context.go('/chat');
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionItem(String label, bool done, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: done ? _DS.green.withOpacity(0.07) : _DS.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? _DS.green.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: done ? _DS.green : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: done ? _DS.green : const Color(0xFFCBCFFF), width: 2),
            ),
            child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: done ? _DS.textGrey : _DS.textDark,
                  decoration: done ? TextDecoration.lineThrough : null,
                )),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: done ? _DS.green : const Color(0xFFCBCFFF)),
        ]),
      ),
    );
  }

  // ── STATS ROW ─────────────────────────────────────────────
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

  Widget _buildSectionLabel(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark, letterSpacing: -0.3)),
  );

  // ── FEATURE GRID ──────────────────────────────────────────
  Widget _buildFeatureGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        // 2 card lớn
        Row(children: [
          Expanded(child: _buildBigFeatureCard(
            icon: '🌐', label: 'Dịch thuật', sub: 'Có hợp đồng cần dịch?', zh: '翻譯',
            c1: const Color(0xFF1565C0), c2: const Color(0xFF1E88E5), route: '/translate',
          )),
          const SizedBox(width: 14),
          Expanded(child: _buildBigFeatureCard(
            icon: '🧠', label: 'Học từ vựng', sub: 'Muốn ôn từ mới?', zh: '學習',
            c1: const Color(0xFF2E7D32), c2: const Color(0xFF43A047), route: '/learn',
          )),
        ]),
        const SizedBox(height: 14),
        // 2 card nhỏ
        Row(children: [
          Expanded(child: _buildSmallFeatureCard(
            icon: '🤖', label: 'Chat AI', sub: 'Yuki & Kai',
            color: const Color(0xFFAD1457), route: '/chat',
          )),
          const SizedBox(width: 14),
          Expanded(child: _buildSmallFeatureCard(
            icon: '🔧', label: 'Công cụ AI', sub: '7 công cụ',
            color: const Color(0xFFE65100), route: '/tools',
          )),
        ]),
      ]),
    );
  }

  Widget _buildBigFeatureCard({
    required String icon, required String label, required String sub,
    required String zh, required String route, required Color c1, required Color c2,
  }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: c2.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radius),
          child: Stack(children: [
            Positioned(right: -10, bottom: -16,
                child: Text(zh, style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900,
                    color: Colors.white.withOpacity(0.1), height: 1))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(icon, style: const TextStyle(fontSize: 30)),
                const Spacer(),
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 3),
                Text(sub, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSmallFeatureCard({
    required String icon, required String label, required String sub,
    required String route, required Color color,
  }) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.textDark)),
            Text(sub, style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withOpacity(0.5)),
        ]),
      ),
    );
  }
List<Map<String, dynamic>> _previewNews = [];
  bool _newsLoading = true;

  Future<void> _loadNewsPreview() async {
    try {
      final token = await const FlutterSecureStorage().read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)));
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/news/feed',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final newsList = List<Map<String, dynamic>>.from(response.data['news'] ?? []);
      print('News loaded: ${newsList.length} items');
      if (mounted) setState(() { _previewNews = newsList.take(3).toList(); _newsLoading = false; });
    } catch (e) {
      print('News error: $e');
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  Widget _buildNewsPreview() {
    if (_newsLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF5B5FEF), strokeWidth: 2)),
        ),
      );
    }
    if (_previewNews.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen())),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _previewNews.first['importance'] == 'high'
                    ? const Color(0xFFFF3D57).withOpacity(0.3)
                    : const Color(0xFFEEEDFE),
                width: _previewNews.first['importance'] == 'high' ? 2 : 1,
              ),
              boxShadow: [BoxShadow(color: const Color(0xFF5B5FEF).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _previewNews.first['importance'] == 'high' ? const Color(0xFFFFEBEE) : const Color(0xFFEEEDFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _previewNews.first['importance'] == 'high' ? '🔴 Quan trọng' : '🟡 Chú ý',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: _previewNews.first['importance'] == 'high' ? const Color(0xFFFF3D57) : const Color(0xFFFF6B35)),
                  ),
                ),
                const Spacer(),
                Text(_previewNews.first['source'] as String? ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF8A8FA3))),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_previewNews.first['emoji'] as String? ?? '📰', style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(_previewNews.first['title_vi'] as String? ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1D2E), height: 1.4))),
              ]),
              const SizedBox(height: 8),
              Text(_previewNews.first['summary_vi'] as String? ?? '',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8FA3), height: 1.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if ((_previewNews.first['action'] as String? ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEEEDFE), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Text('⚡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(_previewNews.first['action'] as String? ?? '',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5B5FEF)))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (_previewNews.length > 1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: _previewNews.skip(1).take(2).map((n) {
            final isFirst = n == _previewNews[1];
            return Expanded(child: Container(
              margin: EdgeInsets.only(right: isFirst ? 8 : 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEDFE)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen())),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n['emoji'] as String? ?? '📰', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  Text(n['title_vi'] as String? ?? '',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E), height: 1.3),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ));
          }).toList()),
        ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen())),
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEDFE))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('📰', style: TextStyle(fontSize: 14)),
              SizedBox(width: 8),
              Text('Xem tất cả tin tức', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5B5FEF))),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF5B5FEF)),
            ]),
          ),
        ),
      ),
    ]);
  }
  // ── TIPS ──────────────────────────────────────────────────
  Widget _buildTips() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(children: [
      _TipCard(icon: '💬', title: 'Chat với Yuki', desc: 'Luyện hội thoại tự nhiên với bạn AI người Đài Loan',
          color: _DS.pink, onTap: () => context.go('/chat')),
      const SizedBox(height: 10),
      _TipCard(icon: '📝', title: 'Dịch hợp đồng lao động', desc: 'Hiểu rõ điều khoản hợp đồng trước khi ký',
          color: _DS.orange, onTap: () => context.go('/tools')),
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
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))],
    ),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _DS.textDark)),
          const SizedBox(height: 3),
          Text(desc, style: const TextStyle(fontSize: 12, color: _DS.textGrey, height: 1.4)),
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
    {'zh': '你好', 'vi': 'Xin chào', 'situation': 'Gặp người lần đầu', 'emoji': '👋', 'c': 0xFF5B5FEF},
    {'zh': '謝謝', 'vi': 'Cảm ơn', 'situation': 'Khi được giúp đỡ', 'emoji': '🙏', 'c': 0xFF2979FF},
    {'zh': '多少錢', 'vi': 'Bao nhiêu tiền?', 'situation': 'Ở siêu thị / chợ', 'emoji': '💰', 'c': 0xFF00C853},
    {'zh': '工作', 'vi': 'Công việc', 'situation': 'Nói chuyện với sếp', 'emoji': '💼', 'c': 0xFFFF6D00},
    {'zh': '不好意思', 'vi': 'Xin lỗi / Thứ lỗi', 'situation': 'Khi cần hỏi đường', 'emoji': '🗺️', 'c': 0xFF651FFF},
    {'zh': '臺灣', 'vi': 'Đài Loan', 'situation': 'Giới thiệu bản thân', 'emoji': '🇹🇼', 'c': 0xFF5B5FEF},
    {'zh': '醫院', 'vi': 'Bệnh viện', 'situation': 'Khi cần khám bệnh', 'emoji': '🏥', 'c': 0xFFE91E8C},
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
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Situation badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(w['emoji'] as String, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Text(w['situation'] as String, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          // Big Chinese character
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(w['zh'] as String,
                  style: TextStyle(fontSize: w['zh'].toString().length > 2 ? 18 : 28,
                      fontWeight: FontWeight.w900, color: color)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w['vi'] as String,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 6),
            Text('Từ sinh tồn · Tap để nghe',
                style: TextStyle(fontSize: 11, color: _DS.textGrey.withOpacity(0.8))),
          ])),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.volume_up_rounded, size: 22, color: Colors.white),
          ),
        ]),
      ]),
    );
  }
}
  

class _SkeletonBox extends StatefulWidget {
  final double height;
  final double radius;
  final double? width;
  const _SkeletonBox({required this.height, required this.radius, this.width});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(_anim.value),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}
