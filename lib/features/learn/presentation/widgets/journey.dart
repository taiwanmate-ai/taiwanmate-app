// ════════════════════════════════════════════════════════════════
// JOURNEY TAB — "30 NGÀY SINH TỒN TẠI ĐÀI LOAN" (FILE LOGIC + UI)
// MODEL + GIAO DIỆN. Nội dung các ngày ở journey_data.dart.
// Muốn thêm tháng mới → CHỈ sửa journey_data.dart, KHÔNG đụng file này.
// ════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'journey_data.dart';

class JDS {
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
  static const purpleLight = Color(0xFFEDE7F6);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const yellow = Color(0xFFFFB300);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── MODEL (PUBLIC) ───────────────────────────────────────────
class Variant {
  final String zh, en, py, note;
  const Variant({required this.zh, required this.en, required this.py, this.note = ''});
}
class Equip {
  final String zh, en, py, ipa, vi;
  final List<Variant> variants;
  const Equip({required this.zh, required this.en, required this.py, this.ipa = '',
      required this.vi, this.variants = const []});
}
class NpcLine {
  final String zh, en, vi;
  const NpcLine({required this.zh, required this.en, required this.vi});
}
class Turn {
  final List<NpcLine> npcLines;
  final List<String> options;
  final List<String> optionsEn;
  final String hintVi;
  const Turn({required this.npcLines, required this.options, required this.optionsEn, required this.hintVi});
}
class Native {
  final String zh, en, py, vi;
  const Native({required this.zh, required this.en, required this.py, required this.vi});
}
class Day {
  final int day;
  final String emoji, titleVi, titleEn, sceneVi, sceneEn, tipVi, tipEn, badgeVi, badgeEn;
  final List<Equip> equips;
  final List<Turn> turns;
  final List<Native> natives;
  const Day({required this.day, required this.emoji, required this.titleVi, required this.titleEn,
      required this.sceneVi, required this.sceneEn, required this.equips, required this.turns,
      this.natives = const [], required this.tipVi, required this.tipEn,
      required this.badgeVi, required this.badgeEn});
}

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
  void initState() { super.initState(); _loadProgress(); }

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

  bool _isUnlocked(int index) {
    if (index == 0) return true;
    return _completed.contains(journeyDays[index - 1].day);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: JDS.orange));
    final done = _completed.length;
    final total = journeyDays.length;
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [JDS.orange, JDS.yellow]),
          borderRadius: BorderRadius.circular(JDS.radius),
          boxShadow: [BoxShadow(color: JDS.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
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
          ClipRRect(borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: journeyDays.length,
        itemBuilder: (context, i) => _buildDayCard(journeyDays[i], _isUnlocked(i)),
      )),
    ]);
  }

  Widget _buildDayCard(Day d, bool unlocked) {
    final isDone = _completed.contains(d.day);
    return GestureDetector(
      onTap: unlocked
          ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DayQuestScreen(day: d, isEn: _isEn, onComplete: () => _markDone(d.day))))
          : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_isEn ? 'Complete the previous day first!' : 'Hoàn thành ngày trước đã!'),
              behavior: SnackBarBehavior.floating)),
      child: Opacity(opacity: unlocked ? 1 : 0.5, child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: JDS.white, borderRadius: BorderRadius.circular(JDS.radius),
            border: Border.all(color: isDone ? JDS.green.withOpacity(0.4) : Colors.transparent, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(children: [
          Container(width: 48, height: 48,
            decoration: BoxDecoration(color: isDone ? JDS.greenLight : (unlocked ? JDS.orangeLight : JDS.bg),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: unlocked
                ? Text(d.emoji, style: const TextStyle(fontSize: 24))
                : const Icon(Icons.lock_rounded, color: JDS.textGrey, size: 22))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_isEn ? "Day" : "Ngày"} ${d.day}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: JDS.orange)),
            const SizedBox(height: 2),
            Text(_isEn ? d.titleEn : d.titleVi,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: JDS.textDark)),
          ])),
          if (isDone) const Icon(Icons.check_circle_rounded, color: JDS.green, size: 24)
          else if (unlocked) const Icon(Icons.chevron_right_rounded, color: JDS.textGrey, size: 24),
        ]),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════
class _DayQuestScreen extends StatefulWidget {
  final Day day;
  final bool isEn;
  final VoidCallback onComplete;
  const _DayQuestScreen({required this.day, required this.isEn, required this.onComplete});
  @override
  State<_DayQuestScreen> createState() => _DayQuestScreenState();
}

class _DayQuestScreenState extends State<_DayQuestScreen> {
  final _storage = const FlutterSecureStorage();
  int _step = 0;
  int _turnIndex = 0;
  int? _picked;
  bool _turnAnswered = false;
  late List<List<int>> _shuffledOrders;
  late List<int> _npcPick;
  final Set<int> _expandedEquip = {};
  bool _playing = false;

  bool get _isEn => widget.isEn;
  Day get d => widget.day;

  @override
  void initState() {
    super.initState();
    final rand = Random();
    _shuffledOrders = d.turns.map((t) =>
        List<int>.generate(t.options.length, (i) => i)..shuffle()).toList();
    _npcPick = d.turns.map((t) => rand.nextInt(t.npcLines.length)).toList();
  }

  Future<void> _speak(String text) async {
    if (_playing) return;
    setState(() => _playing = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60), responseType: ResponseType.bytes));
      final res = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts',
        data: {'text': text, 'lang': _isEn ? 'en-US' : 'zh-TW', 'slow': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}));
      final b64 = base64Encode(res.data as List<int>);
      webEval('''
        (function(){ if(window._journeyAudio){window._journeyAudio.pause();}
        var a=new Audio("data:audio/mpeg;base64,$b64"); window._journeyAudio=a; a.play(); })();
      ''');
    } catch (_) {} finally {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _playing = false);
    }
  }

  void _nextStep() => setState(() => _step++);

  void _nextTurn() {
    if (_turnIndex + 1 < d.turns.length) {
      setState(() { _turnIndex++; _picked = null; _turnAnswered = false; });
    } else {
      setState(() => _step = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JDS.bg,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: JDS.textDark),
        title: Text('${_isEn ? "Day" : "Ngày"} ${d.day} · ${_isEn ? d.titleEn : d.titleVi}',
            style: const TextStyle(color: JDS.textDark, fontWeight: FontWeight.w800, fontSize: 15))),
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

  Widget _buildScene() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const Spacer(),
      Text(d.emoji, style: const TextStyle(fontSize: 64)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: JDS.white, borderRadius: BorderRadius.circular(JDS.radius),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Text(_isEn ? d.sceneEn : d.sceneVi, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.6, color: JDS.textDark, fontWeight: FontWeight.w500))),
      const Spacer(),
      _bigBtn(_isEn ? 'Start →' : 'Bắt đầu →', _nextStep),
    ]),
  );

  Widget _buildEquip() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        const Text('📚', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(_isEn ? 'Equip these phrases' : 'Trang bị các câu sau',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: JDS.textDark)),
      ])),
    Expanded(child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        ...d.equips.asMap().entries.map((entry) => _buildEquipCard(entry.key, entry.value)),
        if (d.natives.isNotEmpty) _buildNativeBox(),
      ],
    )),
    Padding(padding: const EdgeInsets.all(20),
      child: _bigBtn(_isEn ? 'Ready to fight →' : 'Sẵn sàng thực chiến →', _nextStep)),
  ]);

  Widget _buildEquipCard(int idx, Equip e) {
    final main = _isEn ? e.en : e.zh;
    final phon = _isEn ? (e.ipa.isEmpty ? e.py : e.ipa) : e.py;
    final hasVar = e.variants.isNotEmpty;
    final expanded = _expandedEquip.contains(idx);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: JDS.white, borderRadius: BorderRadius.circular(JDS.radiusSm),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(main, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: JDS.textDark)),
              if (phon.isNotEmpty) ...[const SizedBox(height: 2),
                Text(phon, style: const TextStyle(fontSize: 13, color: JDS.orange, fontStyle: FontStyle.italic))],
              const SizedBox(height: 4),
              Text(e.vi, style: const TextStyle(fontSize: 14, color: JDS.textGrey, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(onTap: () => _speak(main),
              child: Container(width: 44, height: 44,
                decoration: const BoxDecoration(color: JDS.orangeLight, shape: BoxShape.circle),
                child: const Icon(Icons.volume_up_rounded, color: JDS.orange, size: 22))),
          ])),
        if (hasVar)
          GestureDetector(
            onTap: () => setState(() => expanded ? _expandedEquip.remove(idx) : _expandedEquip.add(idx)),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: JDS.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(JDS.radiusSm))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_isEn ? 'Other ways to say (${e.variants.length})' : 'Cách nói khác (${e.variants.length})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: JDS.blue)),
                Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18, color: JDS.blue),
              ]))),
        if (hasVar && expanded)
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(children: e.variants.map((v) {
              final vmain = _isEn ? v.en : v.zh;
              return Padding(padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(vmain, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: JDS.textDark))),
                      const SizedBox(width: 8),
                      Text(v.py, style: const TextStyle(fontSize: 11, color: JDS.orange, fontStyle: FontStyle.italic)),
                    ]),
                    if (v.note.isNotEmpty) Text(v.note, style: const TextStyle(fontSize: 11, color: JDS.textGrey)),
                  ])),
                  GestureDetector(onTap: () => _speak(vmain),
                    child: const Icon(Icons.volume_up_rounded, color: JDS.textGrey, size: 18)),
                ]));
            }).toList())),
      ]),
    );
  }

  Widget _buildNativeBox() => Container(
    margin: const EdgeInsets.only(top: 4, bottom: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: JDS.purpleLight, borderRadius: BorderRadius.circular(JDS.radiusSm),
        border: Border.all(color: JDS.purple.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('🗨️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(_isEn ? 'Locals also say' : 'Người bản xứ hay nói',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: JDS.purple)),
      ]),
      const SizedBox(height: 10),
      ...d.natives.map((n) {
        final nmain = _isEn ? n.en : n.zh;
        return Padding(padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(nmain, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: JDS.textDark))),
                const SizedBox(width: 8),
                Text(n.py, style: const TextStyle(fontSize: 11, color: JDS.purple, fontStyle: FontStyle.italic)),
              ]),
              const SizedBox(height: 2),
              Text(n.vi, style: const TextStyle(fontSize: 12, color: JDS.textGrey, height: 1.4)),
            ])),
            GestureDetector(onTap: () => _speak(nmain),
              child: const Icon(Icons.volume_up_rounded, color: JDS.purple, size: 18)),
          ]));
      }),
    ]),
  );

  Widget _buildBattle() {
    final t = d.turns[_turnIndex];
    final order = _shuffledOrders[_turnIndex];
    final opts = _isEn ? t.optionsEn : t.options;
    final npc = t.npcLines[_npcPick[_turnIndex]];

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(children: [
          const Text('🗣️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text('${_isEn ? "Conversation" : "Hội thoại"} ${_turnIndex + 1}/${d.turns.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: JDS.textGrey, fontSize: 13)),
        ])),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: JDS.purple.withOpacity(0.15), shape: BoxShape.circle),
              child: const Center(child: Text('🧑', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 10),
            Expanded(child: Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: JDS.white, borderRadius: BorderRadius.circular(JDS.radiusSm),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_isEn ? npc.en : npc.zh,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: JDS.textDark))),
                  GestureDetector(onTap: () => _speak(_isEn ? npc.en : npc.zh),
                      child: const Icon(Icons.volume_up_rounded, color: JDS.orange, size: 20)),
                ]),
                const SizedBox(height: 4),
                Text(npc.vi, style: const TextStyle(fontSize: 12, color: JDS.textGrey, fontStyle: FontStyle.italic)),
              ]))),
          ]),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: JDS.blueLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(child: Text(t.hintVi, style: const TextStyle(fontSize: 12, color: JDS.blue, fontWeight: FontWeight.w600))),
            ])),
          const SizedBox(height: 16),
          Text(_isEn ? 'Choose your reply:' : 'Chọn câu đáp:',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JDS.textGrey)),
          const SizedBox(height: 10),
          ...order.map((realIndex) {
            final displayIndex = order.indexOf(realIndex);
            final isCorrect = realIndex == 0;
            Color bg = JDS.white, border = Colors.grey.shade200, txt = JDS.textDark;
            Widget? icon;
            if (_turnAnswered) {
              if (isCorrect) { bg = JDS.greenLight; border = JDS.green; txt = JDS.green; icon = const Icon(Icons.check_circle_rounded, color: JDS.green, size: 20); }
              else if (_picked == displayIndex) { bg = JDS.redLight; border = JDS.red; txt = JDS.red; icon = const Icon(Icons.cancel_rounded, color: JDS.red, size: 20); }
            }
            return Padding(padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () { if (!_turnAnswered) setState(() { _picked = displayIndex; _turnAnswered = true; }); },
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(JDS.radiusSm),
                      border: Border.all(color: border, width: _turnAnswered && (isCorrect || _picked == displayIndex) ? 2 : 1)),
                  child: Row(children: [
                    Expanded(child: Text(opts[realIndex], style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: txt))),
                    if (icon != null) icon,
                  ]))));
          }),
        ]),
      )),
      if (_turnAnswered)
        Padding(padding: const EdgeInsets.all(20),
          child: _bigBtn(_turnIndex + 1 < d.turns.length
              ? (_isEn ? 'Next →' : 'Tiếp →') : (_isEn ? 'Finish →' : 'Hoàn thành →'), _nextTurn)),
    ]);
  }

  Widget _buildVictory() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: JDS.orangeLight, borderRadius: BorderRadius.circular(JDS.radius),
            border: Border.all(color: JDS.orange.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🛡️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(_isEn ? 'Survival Tip' : 'Mẹo sinh tồn',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: JDS.orange)),
          ]),
          const SizedBox(height: 10),
          Text(_isEn ? d.tipEn : d.tipVi, style: const TextStyle(fontSize: 14, height: 1.6, color: JDS.textDark)),
        ])),
      const Spacer(),
      Container(width: 120, height: 120,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [JDS.orange, JDS.yellow]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: JDS.orange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Center(child: Text(d.emoji, style: const TextStyle(fontSize: 56)))),
      const SizedBox(height: 16),
      Text(_isEn ? '🎉 Badge unlocked!' : '🎉 Mở khóa huy hiệu!',
          style: const TextStyle(fontSize: 14, color: JDS.textGrey, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(_isEn ? d.badgeEn : d.badgeVi, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: JDS.textDark)),
      const Spacer(),
      _bigBtn(_isEn ? 'Complete Day ${d.day} ✓' : 'Hoàn thành Ngày ${d.day} ✓', () {
        widget.onComplete(); Navigator.pop(context);
      }),
    ]),
  );

  Widget _bigBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [JDS.orange, JDS.yellow]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: JDS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
  );
}