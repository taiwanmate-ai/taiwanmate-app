import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chinesemate/features/lesson_v2/match_board.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';

/// Cau hoi ghep cap (kind = match_pairs) trong phan luyen tap: chon 1 chu roi 1 nghia. Dung het, it loi -> dung.
class MatchPairsCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final void Function(bool correct, int ms) onDone;
  const MatchPairsCard({super.key, required this.question, required this.onDone});

  @override
  State<MatchPairsCard> createState() => _MatchPairsCardState();
}

class _MatchPairsCardState extends State<MatchPairsCard> {
  late final List<Map<String, dynamic>> _pairs;
  late final List<Map<String, dynamic>> _rights;
  final Set<String> _done = {};
  String? _selLeft;
  String? _wrongFlash;
  int _misses = 0;
  final _started = DateTime.now();

  @override
  void initState() {
    super.initState();
    final p = Map<String, dynamic>.from(widget.question['payload'] as Map);
    _pairs = (p['pairs'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _rights = List.of(_pairs)..shuffle();
  }

  void _tapRight(String id) {
    if (_selLeft == null || _done.contains(id)) return;
    if (_selLeft == id) {
      setState(() { _done.add(id); _selLeft = null; });
      if (_done.length == _pairs.length) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) widget.onDone(_misses == 0, DateTime.now().difference(_started).inMilliseconds);
        });
      }
    } else {
      setState(() { _misses++; _wrongFlash = id; _selLeft = null; });
      Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _wrongFlash = null); });
    }
  }

  Widget _tile(String key, String text, String? sub, {required bool done, required bool selected, required bool wrong, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: Key(key),
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: done ? const Color(0xFFE8F8EE) : (selected ? const Color(0xFFEDEEFF) : Colors.white),
            border: Border.all(color: done ? kLessonGreen : (wrong ? kLessonRed : (selected ? kLessonPurple : const Color(0xFFE0E3F0))), width: 1.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: done ? kLessonGreen : kLessonDark)),
            if (sub != null && sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11, color: kLessonGrey)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prompt = (widget.question['payload'] as Map)['prompt'] as String? ?? 'Ghép từ với nghĩa';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(prompt, style: const TextStyle(color: kLessonGrey, fontSize: 13)),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [
          for (final p in _pairs)
            _tile('match_l_${p['id']}', p['left'] as String, p['sub'] as String?, done: _done.contains(p['id']), selected: _selLeft == p['id'], wrong: false,
                onTap: () => setState(() => _selLeft = p['id'] as String)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [
          for (final p in _rights)
            _tile('match_r_${p['id']}', p['right'] as String, null, done: _done.contains(p['id']), selected: false, wrong: _wrongFlash == p['id'], onTap: () => _tapRight(p['id'] as String)),
        ])),
      ]),
    ]);
  }
}

/// Mini-game "Ghep nhanh 60 giay": sinh bang code tu cac cap chu–nghia da duyet. Co nut Bo qua. Server tu tinh diem/XP tu (matched, misses).
class Match60Widget extends StatefulWidget {
  final List<Map<String, dynamic>> pool;
  final int durationSeconds;
  final void Function(int matched, int misses) onFinish;
  final VoidCallback onSkip;
  const Match60Widget({super.key, required this.pool, required this.onFinish, required this.onSkip, this.durationSeconds = 60});

  @override
  State<Match60Widget> createState() => _Match60WidgetState();
}

class _Match60WidgetState extends State<Match60Widget> {
  late final MatchBoard _board;
  late int _left;
  Timer? _timer;
  String? _selLeft;
  String? _wrongRight;
  bool _started = false;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    _board = MatchBoard(widget.pool);
    _left = widget.durationSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _finish() {
    if (_over) return;
    _over = true;
    _timer?.cancel();
    setState(() {});
    widget.onFinish(_board.matched, _board.misses);
  }

  void _tapRight(String id) {
    if (_selLeft == null || _over) return;
    final ok = _board.select(_selLeft!, id);
    setState(() {
      _selLeft = null;
      _wrongRight = ok ? null : id;
    });
    if (!ok) Future.delayed(const Duration(milliseconds: 350), () { if (mounted) setState(() => _wrongRight = null); });
    if (_board.isEmpty) _finish();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚡ Ghép nhanh 60 giây', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kLessonDark)),
        const SizedBox(height: 8),
        const Text('Ghép chữ với nghĩa càng nhiều càng tốt. Thưởng XP nếu lập điểm cao!', textAlign: TextAlign.center, style: TextStyle(color: kLessonGrey)),
        const SizedBox(height: 20),
        ElevatedButton(key: const Key('match60_start'), onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white), child: const Text('Bắt đầu')),
        TextButton(key: const Key('match60_skip'), onPressed: widget.onSkip, child: const Text('Bỏ qua', style: TextStyle(color: kLessonGrey))),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('⏱ $_left s', key: const Key('match60_time'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const Spacer(),
        Text('Điểm ${_board.score}', key: const Key('match60_score'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kLessonPurple)),
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(children: [
          for (final p in _board.lefts)
            _gameTile('g_l_${p['word_id']}', p['left'] as String, _selLeft == p['word_id'], false, () => setState(() => _selLeft = p['word_id'] as String)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(children: [
          for (final p in _board.rights) _gameTile('g_r_${p['word_id']}', p['right'] as String, false, _wrongRight == p['word_id'], () => _tapRight(p['word_id'] as String)),
        ])),
      ]),
      const SizedBox(height: 8),
      TextButton(key: const Key('match60_end'), onPressed: _finish, child: const Text('Kết thúc', style: TextStyle(color: kLessonGrey))),
    ]);
  }

  Widget _gameTile(String key, String text, bool selected, bool wrong, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          key: Key(key),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEDEEFF) : Colors.white,
              border: Border.all(color: wrong ? kLessonRed : (selected ? kLessonPurple : const Color(0xFFE0E3F0)), width: 1.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kLessonDark)),
          ),
        ),
      );
}
