// ═══════════════════════════════════════════════════════════════
// LEARN HUB TAB
// File: lib/features/learn/presentation/widgets/learn_hub_tab.dart
//
// Màn hình gốc của tab "Lộ trình" — chỉ có 2 thẻ chọn:
// 1. Học theo Lộ trình (mở CurriculumTab)
// 2. 30 Ngày Sinh Tồn (mở JourneyTab)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/learn/presentation/widgets/journey.dart';

class LearnHubTab extends StatelessWidget {
  final String lang;
  const LearnHubTab({super.key, required this.lang});

  static const _bg = Color(0xFFF0F4FF);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);
  static const _purple = Color(0xFF5B5FEF);
  static const _orange = Color(0xFFFF6B35);

  void _openCurriculum(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('Lộ trình học',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: const CurriculumTab(),
    )));
  }

  void _openJourney(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('30 Ngày Sinh Tồn',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: JourneyTab(lang: lang),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _buildCard(
          context: context,
          emoji: '📚',
          title: 'Học theo Lộ trình',
          subtitle: 'Tiếng Trung & Tiếng Anh — học tuần tự theo cấp độ CEFR/TOCFL',
          color: _purple,
          onTap: () => _openCurriculum(context),
        ),
        const SizedBox(height: 14),
        _buildCard(
          context: context,
          emoji: '🖐️',
          title: '30 Ngày Sinh Tồn',
          subtitle: 'Vượt qua các tình huống đời thực tại Đài Loan',
          color: _orange,
          onTap: () => _openJourney(context),
        ),
      ]),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _textGrey, height: 1.4)),
          ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
        ]),
      ),
    );
  }
}