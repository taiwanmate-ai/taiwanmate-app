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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/translate', builder: (c, s) => const TranslateScreen()),
        GoRoute(path: '/learn', builder: (c, s) => const LearnScreen()),
        GoRoute(path: '/chat', builder: (c, s) => const ChatScreen()),
        GoRoute(path: '/live', builder: (c, s) => const LiveChatScreen()),
        GoRoute(path: '/tools', builder: (c, s) => const ToolsScreen()),
        GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      ],
    ),
  ],
);

// ═══════════════════════════════════════════════════════════════
// SPLASH SCREEN — VN → TW Journey Animation
// ═══════════════════════════════════════════════════════════════
// Thay toàn bộ class SplashScreen và các class liên quan trong app_router.dart
// Giữ nguyên phần router, chỉ thay từ "class SplashScreen" trở xuống

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _planeCtrl;
  late AnimationController _textCtrl;
  late AnimationController _progressCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressVal;
  late Animation<double> _planeFade;

  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat(reverse: true);
    _particleCtrl = AnimationController(duration: const Duration(seconds: 6), vsync: this)..repeat();

    // Plane flies across screen
    _planeCtrl = AnimationController(duration: const Duration(milliseconds: 2800), vsync: this);
    _planeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _planeCtrl, curve: const Interval(0.0, 0.1, curve: Curves.easeIn)),
    );

    _logoCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.5)));

    _textCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _textFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _progressCtrl = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    _progressVal = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut));

    // Generate particles
    for (int i = 0; i < 35; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(), y: _rng.nextDouble(),
        size: _rng.nextDouble() * 2.5 + 0.5,
        phase: _rng.nextDouble(), speed: _rng.nextDouble() * 0.4 + 0.1,
      ));
    }

    // Sequence: plane flies → logo → text + progress
    _planeCtrl.forward().then((_) {
      _logoCtrl.forward().then((_) {
        _textCtrl.forward();
        _progressCtrl.forward();
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
    _textCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 4000));
    if (!mounted) return;
    final hasToken = await SecureStorage.hasToken();
    if (!hasToken) { context.go('/login'); return; }
    final storage = const FlutterSecureStorage();
    final onboardingDone = await storage.read(key: 'onboarding_done');
    context.go(onboardingDone == 'true' ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgCtrl, _particleCtrl, _planeCtrl]),
        builder: (_, __) => Container(
          width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF0D1B2A), const Color(0xFF1A0A2E), _bgCtrl.value)!,
                Color.lerp(const Color(0xFF1A0A2E), const Color(0xFF0A1628), _bgCtrl.value)!,
                Color.lerp(const Color(0xFF0A2440), const Color(0xFF1A1040), _bgCtrl.value)!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Stack(children: [
            // Starfield
            ..._buildStarfield(size),

            // Radial glow
            Center(child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFFB300).withOpacity(0.07 + _bgCtrl.value * 0.05),
                  Colors.transparent,
                ]),
              ),
            )),

            // ── Airplane animation ──
            _buildPlane(size),

            // ── VN → TW flag trail ──
            if (_planeCtrl.value > 0.1 && _planeCtrl.value < 0.95)
              _buildFlagTrail(size),

            // ── Main content ──
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                // Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: _buildLogo(),
                  ),
                ),
                const SizedBox(height: 36),
                // Text
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: _buildText(),
                  ),
                ),
                const SizedBox(height: 56),
                // Progress
                FadeTransition(
                  opacity: _textFade,
                  child: _buildProgress(),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPlane(Size size) {
    // Plane flies from left-bottom to right-top in an arc
    final t = _planeCtrl.value;
    final startX = -60.0;
    final endX = size.width + 60.0;
    final midY = size.height * 0.28;

    // Bezier arc
    final x = startX + (endX - startX) * t;
    final y = midY + math.sin(t * math.pi) * (-80); // arc upward

    // Slight rotation based on movement direction
    final angle = -0.15 + math.sin(t * math.pi) * 0.1;

    return Positioned(
      left: x - 24,
      top: y - 24,
      child: Opacity(
        opacity: _planeFade.value * (t > 0.9 ? (1 - t) * 10 : 1),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB300).withOpacity(0.2),
              boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.4), blurRadius: 16, spreadRadius: 2)],
            ),
            child: const Center(child: Text('✈️', style: TextStyle(fontSize: 24))),
          ),
        ),
      ),
    );
  }

  Widget _buildFlagTrail(Size size) {
    final t = _planeCtrl.value;
    // Show flags at start and end positions
    return Stack(children: [
      // VN flag at left
      Positioned(
        left: 30, top: size.height * 0.25,
        child: Opacity(
          opacity: (t * 5).clamp(0.0, 1.0),
          child: Column(children: [
            const Text('🇻🇳', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5252).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)),
              ),
              child: const Text('Việt Nam', style: TextStyle(fontSize: 10, color: Color(0xFFFF5252), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
      // Dotted trail line
      Positioned(
        left: 80, top: size.height * 0.28,
        child: Opacity(
          opacity: (t * 3).clamp(0.0, 0.4),
          child: CustomPaint(
            size: Size(size.width - 160, 2),
            painter: _DottedLinePainter(progress: t, color: const Color(0xFFFFB300)),
          ),
        ),
      ),
      // TW flag at right
      Positioned(
        right: 30, top: size.height * 0.22,
        child: Opacity(
          opacity: ((t - 0.6) * 5).clamp(0.0, 1.0),
          child: Column(children: [
            const Text('🇹🇼', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF40C4FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF40C4FF).withOpacity(0.4)),
              ),
              child: const Text('Đài Loan', style: TextStyle(fontSize: 10, color: Color(0xFF40C4FF), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildLogo() => Container(
    width: 110, height: 110,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(colors: [Color(0xFF1E3A5F), Color(0xFF0D1B2A)]),
      border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.7), width: 2),
      boxShadow: [
        BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.25), blurRadius: 24, spreadRadius: 4),
      ],
    ),
    child: Stack(alignment: Alignment.center, children: [
      // Rotating dashed ring
      AnimatedBuilder(
        animation: _bgCtrl,
        builder: (_, __) => Transform.rotate(
          angle: _bgCtrl.value * 2 * math.pi * 0.3,
          child: CustomPaint(
            size: const Size(100, 100),
            painter: _DashedRingPainter(color: const Color(0xFFFFB300).withOpacity(0.4), strokeWidth: 1.5, dashCount: 16),
          ),
        ),
      ),
      // Flags
      const Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🇻🇳', style: TextStyle(fontSize: 14)),
          SizedBox(width: 4),
          Text('🇹🇼', style: TextStyle(fontSize: 14)),
        ]),
      ]),
    ]),
  );

  Widget _buildText() => Column(children: [
    RichText(text: const TextSpan(children: [
      TextSpan(text: 'Taiwan', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
      TextSpan(text: 'Mate', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFFFFB300), letterSpacing: -0.5)),
      TextSpan(text: ' AI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Colors.white54, letterSpacing: -0.5)),
    ])),
    const SizedBox(height: 8),
    Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('🇻🇳', style: TextStyle(fontSize: 18)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('✈', style: TextStyle(fontSize: 16, color: const Color(0xFFFFB300).withOpacity(0.9))),
      ),
      const Text('🇹🇼', style: TextStyle(fontSize: 18)),
    ]),
    const SizedBox(height: 8),
    Text('Người bạn AI cho người Việt tại Đài Loan',
        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45), letterSpacing: 0.3)),
  ]);

  Widget _buildProgress() => AnimatedBuilder(
    animation: _progressVal,
    builder: (_, __) => Column(children: [
      Container(
        width: 160, height: 2,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(2)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 160 * _progressVal.value, height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(colors: [Color(0xFFFFB300), Color(0xFFFF6B35)]),
              boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.6), blurRadius: 6)],
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text('ĐANG TẢI...', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3), letterSpacing: 3)),
    ]),
  );

  List<Widget> _buildStarfield(Size size) => _particles.map((p) {
    final twinkle = (math.sin((_particleCtrl.value * p.speed * 2 * math.pi) + p.phase * 2 * math.pi) + 1) / 2;
    return Positioned(
      left: p.x * size.width, top: p.y * size.height,
      child: Container(
        width: p.size, height: p.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(twinkle * 0.7)),
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
