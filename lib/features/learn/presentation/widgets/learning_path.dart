// ═══════════════════════════════════════════════════════════════
// LEARNING PATH WIDGET
// File: lib/features/learn/presentation/widgets/learning_path.dart
// Dùng chung cho HomeScreen và LearnScreen
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Design System ────────────────────────────────────────────
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
  static const yellow = Color(0xFFFFB300);
  static const purple = Color(0xFF7C4DFF);
  static const purpleLight = Color(0xFFEDE7F6);
  static const red = Color(0xFFFF3D57);
  static const radiusSm = 14.0;
  static const radius = 20.0;
}

// ─── Level data ───────────────────────────────────────────────
class _LevelInfo {
  final String level;
  final String label;
  final String desc;
  final Color color;
  final Color lightColor;
  final String emoji;
  final int targetWords;

  const _LevelInfo({
    required this.level,
    required this.label,
    required this.desc,
    required this.color,
    required this.lightColor,
    required this.emoji,
    required this.targetWords,
  });
}

const _zhLevels = [
  _LevelInfo(level: 'A1', label: 'Sơ cấp 1', desc: 'Chào hỏi, số đếm, màu sắc', color: Color(0xFF00C853), lightColor: Color(0xFFE8F5E9), emoji: '🌱', targetWords: 300),
  _LevelInfo(level: 'A2', label: 'Sơ cấp 2', desc: 'Mua sắm, nhà hàng, đi lại', color: Color(0xFF2979FF), lightColor: Color(0xFFE8F0FF), emoji: '📘', targetWords: 600),
  _LevelInfo(level: 'B1', label: 'Trung cấp 1', desc: 'Công việc, bệnh viện, hợp đồng', color: Color(0xFFFF6B35), lightColor: Color(0xFFFFF0EC), emoji: '🔥', targetWords: 1000),
  _LevelInfo(level: 'B2', label: 'Trung cấp 2', desc: 'Thảo luận, đàm phán, tin tức', color: Color(0xFF7C4DFF), lightColor: Color(0xFFEDE7F6), emoji: '⚡', targetWords: 1500),
  _LevelInfo(level: 'C1', label: 'Cao cấp', desc: 'Thành thạo như người bản địa', color: Color(0xFFFFB300), lightColor: Color(0xFFFFF8E1), emoji: '👑', targetWords: 2000),
];

const _enLevels = [
  _LevelInfo(level: 'A1', label: 'Beginner', desc: 'Hello, numbers, daily basics', color: Color(0xFF00C853), lightColor: Color(0xFFE8F5E9), emoji: '🌱', targetWords: 100),
  _LevelInfo(level: 'A2', label: 'Elementary', desc: 'Work, shopping, health', color: Color(0xFF2979FF), lightColor: Color(0xFFE8F0FF), emoji: '📘', targetWords: 250),
  _LevelInfo(level: 'B1', label: 'Intermediate', desc: 'Labor law, finance, office', color: Color(0xFFFF6B35), lightColor: Color(0xFFFFF0EC), emoji: '🔥', targetWords: 450),
  _LevelInfo(level: 'B2', label: 'Upper-Intermediate', desc: 'Negotiation, complex topics', color: Color(0xFF7C4DFF), lightColor: Color(0xFFEDE7F6), emoji: '⚡', targetWords: 650),
];

// ═══════════════════════════════════════════════════════════════
// LEARNING PATH WIDGET — compact cho HomeScreen
// ═══════════════════════════════════════════════════════════════
class LearningPathCard extends StatefulWidget {
  final String lang; // 'zh' hoặc 'en'
  final VoidCallback? onTapLearn;

  const LearningPathCard({
    super.key,
    required this.lang,
    this.onTapLearn,
  });

  @override
  State<LearningPathCard> createState() => _LearningPathCardState();
}

class _LearningPathCardState extends State<LearningPathCard> {
  final _storage = const FlutterSecureStorage();
  Map<String, int> _learnedPerLevel = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(LearningPathCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary?lang=${widget.lang}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final words = List<Map<String, dynamic>>.from(res.data);
      final Map<String, int> counts = {};
      for (final w in words) {
        final srs = (w['srs_level'] as num?)?.toInt() ?? 0;
        if (srs > 0) {
          final level = widget.lang == 'zh'
              ? (w['tocfl_level'] ?? w['cefr_level'] ?? 'A1').toString()
              : (w['cefr_level'] ?? 'A1').toString();
          counts[level] = (counts[level] ?? 0) + 1;
        }
      }
      if (mounted) setState(() => _learnedPerLevel = counts);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<_LevelInfo> get _levels => widget.lang == 'zh' ? _zhLevels : _enLevels;

  // Tìm level hiện tại (level đang học dở)
  _LevelInfo get _currentLevel {
    for (final lv in _levels) {
      final learned = _learnedPerLevel[lv.level] ?? 0;
      if (learned < lv.targetWords) return lv;
    }
    return _levels.last;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radius)),
        child: const Center(child: CircularProgressIndicator(color: _DS.orange, strokeWidth: 2)),
      );
    }

    final current = _currentLevel;
    final learned = _learnedPerLevel[current.level] ?? 0;
    final progress = (learned / current.targetWords).clamp(0.0, 1.0);
    final langLabel = widget.lang == 'zh' ? '🇹🇼 Tiếng Trung' : '🇺🇸 Tiếng Anh';

    return GestureDetector(
      onTap: widget.onTapLearn,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: current.lightColor, borderRadius: BorderRadius.circular(20)),
              child: Text(langLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: current.color)),
            ),
            const Spacer(),
            Text('$learned/${current.targetWords} từ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: current.color)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text(current.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(current.level, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: current.color)),
                const SizedBox(width: 6),
                Text(current.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
              ]),
              const SizedBox(height: 2),
              Text(current.desc, style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
            ])),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: current.lightColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: current.color),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress, minHeight: 8,
              backgroundColor: current.color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(current.color),
            ),
          ),
          const SizedBox(height: 6),
          // Mini level dots
          Row(
            children: _levels.map((lv) {
              final lvLearned = _learnedPerLevel[lv.level] ?? 0;
              final isDone = lvLearned >= lv.targetWords;
              final isCurrent = lv.level == current.level;
              return Expanded(child: Column(children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isDone ? lv.color : isCurrent ? lv.color.withOpacity(0.4) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(lv.level, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: isDone || isCurrent ? lv.color : _DS.textGrey,
                )),
              ]));
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LEARNING PATH TAB — full cho LearnScreen (thay tab Chủ đề)
// ═══════════════════════════════════════════════════════════════
class LearningPathTab extends StatefulWidget {
  final String lang;
  final VoidCallback onStartLearn;

  const LearningPathTab({
    super.key,
    required this.lang,
    required this.onStartLearn,
  });

  @override
  State<LearningPathTab> createState() => _LearningPathTabState();
}

class _LearningPathTabState extends State<LearningPathTab> {
  final _storage = const FlutterSecureStorage();
  Map<String, int> _learnedPerLevel = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(LearningPathTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lang != widget.lang) _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary?lang=${widget.lang}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final words = List<Map<String, dynamic>>.from(res.data);
      final Map<String, int> counts = {};
      for (final w in words) {
        final srs = (w['srs_level'] as num?)?.toInt() ?? 0;
        if (srs > 0) {
          final level = widget.lang == 'zh'
              ? (w['tocfl_level'] ?? w['cefr_level'] ?? 'A1').toString()
              : (w['cefr_level'] ?? 'A1').toString();
          counts[level] = (counts[level] ?? 0) + 1;
        }
      }
      if (mounted) setState(() => _learnedPerLevel = counts);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<_LevelInfo> get _levels => widget.lang == 'zh' ? _zhLevels : _enLevels;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _DS.orange));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.lang == 'zh' ? '🇹🇼 Lộ trình tiếng Trung' : '🇺🇸 Lộ trình tiếng Anh',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              widget.lang == 'zh' ? 'Từ A1 đến C1 — ${_levels.last.targetWords} từ' : 'Từ A1 đến B2 — ${_levels.last.targetWords} từ',
              style: const TextStyle(fontSize: 13, color: _DS.textGrey),
            ),
          ])),
          // Tổng progress
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${_learnedPerLevel.values.fold(0, (a, b) => a + b)} từ đã học',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.orange),
            ),
          ),
        ]),
        const SizedBox(height: 20),

        // Level cards
        ...List.generate(_levels.length, (i) {
          final lv = _levels[i];
          final learned = _learnedPerLevel[lv.level] ?? 0;
          final progress = (learned / lv.targetWords).clamp(0.0, 1.0);
          final isDone = learned >= lv.targetWords;
          final isLocked = i > 0 && (_learnedPerLevel[_levels[i-1].level] ?? 0) < (_levels[i-1].targetWords * 0.3).toInt();

          return Column(children: [
            // Connector line
            if (i > 0) Container(
              width: 2, height: 20,
              margin: const EdgeInsets.only(left: 28),
              color: isDone ? lv.color : Colors.grey.shade200,
            ),

            // Level card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDone ? lv.lightColor : _DS.white,
                borderRadius: BorderRadius.circular(_DS.radius),
                border: Border.all(
                  color: isDone ? lv.color.withOpacity(0.4) : isLocked ? Colors.grey.shade200 : lv.color.withOpacity(0.2),
                  width: isDone ? 2 : 1,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                Row(children: [
                  // Level badge
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: isLocked
                          ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200])
                          : LinearGradient(colors: [lv.color, lv.color.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(
                      isLocked ? '🔒' : lv.emoji,
                      style: const TextStyle(fontSize: 24),
                    )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isLocked ? Colors.grey.shade200 : lv.lightColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(lv.level, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: isLocked ? _DS.textGrey : lv.color,
                        )),
                      ),
                      const SizedBox(width: 8),
                      Text(lv.label, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: isLocked ? _DS.textGrey : _DS.textDark,
                      )),
                      if (isDone) ...[
                        const SizedBox(width: 6),
                        const Text('✅', style: TextStyle(fontSize: 14)),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(lv.desc, style: TextStyle(
                      fontSize: 11,
                      color: isLocked ? Colors.grey.shade400 : _DS.textGrey,
                    )),
                  ])),
                  // Word count
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$learned', style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: isLocked ? Colors.grey.shade300 : lv.color,
                    )),
                    Text('/ ${lv.targetWords}', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                  ]),
                ]),

                if (!isLocked) ...[
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress, minHeight: 8,
                      backgroundColor: lv.color.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(lv.color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(
                      isDone ? '🎉 Hoàn thành!' : '${(progress * 100).toInt()}% hoàn thành',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: lv.color),
                    ),
                    if (!isDone)
                      GestureDetector(
                        onTap: widget.onStartLearn,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [lv.color, lv.color.withOpacity(0.8)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: lv.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: const Text('Học ngay →',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                  ]),
                ],

                if (isLocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Hoàn thành 30% ${_levels[i-1].level} để mở khóa',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic),
                  ),
                ],
              ]),
            ),
          ]);
        }),

        const SizedBox(height: 24),

        // Motivational footer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(_DS.radius),
            boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            const Text('💪', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Học 20 từ mỗi ngày', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
              SizedBox(height: 2),
              Text('Sau 3 tháng bạn đạt B1 — đủ dùng trong cuộc sống!',
                  style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4)),
            ])),
            GestureDetector(
              onTap: widget.onStartLearn,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: const Text('Bắt đầu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.orange)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
