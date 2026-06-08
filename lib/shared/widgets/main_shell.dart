import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Timer? _feedbackTimer;
  bool _feedbackShown = false;

  @override
  void initState() {
    super.initState();
    // Hiện popup feedback sau 3 phút dùng app
    _feedbackTimer = Timer(const Duration(minutes: 3), () {
      if (!mounted || _feedbackShown) return;
      _feedbackShown = true;
      _showFeedbackDialog();
    });
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB300)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('💬', style: TextStyle(fontSize: 32))),
            ),
            const SizedBox(height: 16),
            const Text('Bạn thấy app thế nào?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
            const SizedBox(height: 8),
            const Text(
              'Góp ý của bạn giúp mình cải thiện app tốt hơn mỗi ngày. Chỉ mất 2 phút thôi!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8FA3), height: 1.6),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                launchUrl(
                  Uri.parse('https://forms.gle/YOUR_FORM_ID'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB300)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Góp ý ngay 🙏',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Để sau',
                  style: TextStyle(color: Color(0xFF8A8FA3), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ),
    );
  }

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/home')) return 0;
    if (loc.startsWith('/translate')) return 1;
    if (loc.startsWith('/learn')) return 2;
    if (loc.startsWith('/chat')) return 3;
    if (loc.startsWith('/tools')) return 5;
    if (loc.startsWith('/profile')) return 6;
    return 0;
  }

  void _onTap(BuildContext context, int i) {
    if (i == 4) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFB300)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🎙️', style: TextStyle(fontSize: 36))),
              ),
              const SizedBox(height: 20),
              const Text('Live AI đang phát triển',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E))),
              const SizedBox(height: 10),
              const Text(
                'Tính năng trò chuyện trực tiếp với AI đang được xây dựng.\nSẽ ra mắt sớm nhất có thể! 🚀',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8A8FA3), height: 1.6),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFFB300)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('OK, tôi chờ!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      );
      return;
    }

    const routes = {
      0: '/home',
      1: '/translate',
      2: '/learn',
      3: '/chat',
      5: '/tools',
      6: '/profile',
    };

    final route = routes[i];
    if (route != null) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(context),
        onTap: (i) => _onTap(context, i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF6B35),
        unselectedItemColor: const Color(0xFF8A8FA3),
        backgroundColor: Colors.white,
        elevation: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.translate_outlined), activeIcon: Icon(Icons.translate), label: 'Dịch'),
          BottomNavigationBarItem(icon: Icon(Icons.school_outlined), activeIcon: Icon(Icons.school), label: 'Học'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.mic_outlined), activeIcon: Icon(Icons.mic), label: 'Live'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), activeIcon: Icon(Icons.build), label: 'Công cụ'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    );
  }
}