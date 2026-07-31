import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/translate/presentation/screens/translate_screen.dart';
import '../../features/learn/presentation/screens/learn_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/chat/presentation/screens/live_chat_screen.dart';
import '../../features/tools/presentation/screens/tools_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/tools/presentation/screens/tools_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/learn_v2/presentation/screens/learning_hub_screen_v2.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    if (state.matchedLocation == '/') return '/splash';
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/emergency', builder: (context, state) => const EmergencyPage()),
    // Route tam thoi de test learn_v2 (Tab Hoc moi) - KHONG thay the /learn cu.
    GoRoute(path: '/learn-v2', builder: (context, state) => const LearningHubScreenV2()),

    // ── StatefulShellRoute: giữ state từng tab, không rebuild khi chuyển tab ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/translate', builder: (c, s) => const TranslateScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/learn', builder: (c, s) => const LearnScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/live', builder: (c, s) => const LiveChatScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/tools', builder: (c, s) => const ToolsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/community', builder: (c, s) => const CommunityScreen()),
        ]),
      ],
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════
// SPLASH SCREEN — VN → TW Journey Animation
// ═══════════════════════════════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _planeCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _progressCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _progressVal;
  late Animation<double> _planeFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  bool _authDone = false;
  bool _animDone = false;
  String? _authRoute;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        duration: const Duration(seconds: 6), vsync: this)
      ..repeat(reverse: true);

    _particleCtrl = AnimationController(
        duration: const Duration(seconds: 6), vsync: this)
      ..repeat();

    _planeCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _planeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _planeCtrl,
          curve: const Interval(0.0, 0.15, curve: Curves.easeIn)),
    );

    _logoCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _logoCtrl, curve: const Interval(0, 0.5)));

    _progressCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _progressVal = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _progressCtrl, curve: Curves.easeInOut));

    _textFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.3, 1.0)));
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _logoCtrl, curve: Curves.easeOut));

    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2.5 + 0.5,
        phase: _rng.nextDouble(),
        speed: _rng.nextDouble() * 0.4 + 0.1,
      ));
    }

    // Sequence: plane flies → illustration fades in → progress
    _planeCtrl.forward().then((_) {
      _logoCtrl.forward();
      _progressCtrl.forward().then((_) {
        _animDone = true;
        _tryNavigate();
      });
    });

    _checkAuth();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _particleCtrl.dispose();
    _planeCtrl.dispose();
    _logoCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _tryNavigate() {
    if (!_authDone || !_animDone) return;
    if (!mounted) return;
    if (_authRoute != null) context.go(_authRoute!);
  }

  Future<void> _checkAuth() async {
    final hasToken = await SecureStorage.hasToken();
    if (!hasToken) {
      _authRoute = '/login';
      _authDone = true;
      _tryNavigate();
      return;
    }
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final onboardingDone = await storage.read(key: 'onboarding_done');
      _authRoute =
          onboardingDone == 'true' ? '/home' : '/onboarding';
    } catch (e) {
      await SecureStorage.deleteToken();
      _authRoute = '/login';
    }
    _authDone = true;
    _tryNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation:
            Listenable.merge([_bgCtrl, _particleCtrl, _planeCtrl]),
        builder: (_, __) => Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF1A1A4E), // Indigo đậm cố định
          child: Stack(children: [
            // Starfield
            ..._buildStarfield(size),

            // Glow center nhẹ
            Center(
              child: AnimatedBuilder(
                animation: _bgCtrl,
                builder: (_, __) => Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF5B5FEF)
                          .withOpacity(0.15 + _bgCtrl.value * 0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // Plane arc
            _buildPlane(size),

            // Main content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Illustration
               Center(
  child: SizedBox(
    width: 280,
    height: 280,
    child: Image.asset(
      'assets/images/Digital_tools-rafiki.webp',
      fit: BoxFit.contain,
    ),
  ),
),
                const SizedBox(height: 24),

                // App name
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: _buildText(),
                  ),
                ),

                const SizedBox(height: 48),

                // Progress bar
                FadeTransition(
                  opacity: _textFade,
                  child: _buildProgress(),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPlane(Size size) {
    final t = _planeCtrl.value;
    final startX = -50.0;
    final endX = size.width + 50.0;
    final midY = size.height * 0.15;
    final x = startX + (endX - startX) * t;
    final y = midY + math.sin(t * math.pi) * (-60);
    final angle = -0.12 + math.sin(t * math.pi) * 0.08;

    return Positioned(
      left: x - 22,
      top: y - 22,
      child: Opacity(
        opacity: _planeFade.value * (t > 0.88 ? (1 - t) * 8 : 1),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF5B5FEF).withOpacity(0.25),
            ),
            child: const Center(
              child: Text('✈️', style: TextStyle(fontSize: 22)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildText() => Column(children: [
        RichText(
          text: const TextSpan(children: [
            TextSpan(
              text: 'Taiwan',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5),
            ),
            TextSpan(
              text: 'Mate',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD166),
                  letterSpacing: -0.5),
            ),
            TextSpan(
              text: ' AI',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  color: Colors.white38,
                  letterSpacing: -0.5),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
          'Trợ lý AI thông minh của bạn',
          style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.3),
        ),
      ]);

  Widget _buildProgress() => AnimatedBuilder(
        animation: _progressVal,
        builder: (_, __) => Column(children: [
          Container(
            width: 140,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 140 * _progressVal.value,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: const Color(0xFF5B5FEF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ĐANG TẢI...',
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.25),
                letterSpacing: 3),
          ),
        ]),
      );

  List<Widget> _buildStarfield(Size size) => _particles.map((p) {
        final twinkle =
            (math.sin((_particleCtrl.value * p.speed * 2 * math.pi) +
                        p.phase * 2 * math.pi) +
                    1) /
                2;
        return Positioned(
          left: p.x * size.width,
          top: p.y * size.height,
          child: Container(
            width: p.size,
            height: p.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(twinkle * 0.6),
            ),
          ),
        );
      }).toList();
}

// ─── Dotted Line Painter ──────────────────────────────────────
class _DottedLinePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _DottedLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    const dashWidth = 8.0;
    const dashSpace = 6.0;
    double x = 0;
    final maxX = size.width * progress;
    while (x < maxX) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dashWidth, maxX), 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.progress != progress;
}

// ─── Dashed Ring Painter ──────────────────────────────────────
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  const _DashedRingPainter({required this.color, required this.strokeWidth, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final dashAngle = math.pi / dashCount;
    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), i * dashAngle * 2, dashAngle * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

// ─── Particle Model ───────────────────────────────────────────
class _Particle {
  final double x, y, size, phase, speed;
  const _Particle({required this.x, required this.y, required this.size, required this.phase, required this.speed});
}