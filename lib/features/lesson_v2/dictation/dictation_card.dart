import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/features/lesson_v2/dictation/dictation_grader.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';

/// Chế độ nhập của nghe chép (thiết kế backend docs/lesson_write_design.md §1.2, CTO duyệt 02/11/2026).
enum DictationMode { tiles, pinyin, hanzi }

const _modeLabel = {DictationMode.tiles: 'Chọn chữ', DictationMode.pinyin: 'Gõ pinyin', DictationMode.hanzi: 'Gõ chữ Hán'};
const kDictationModePref = 'dictation_mode';
const kDictationStrictTonesPref = 'dictation_strict_tones';

/// Bảng âm tiết pinyin (asset chép nguyên văn từ backend) — tải 1 lần, giữ KẾT QUẢ (không giữ Future).
Set<String>? _syllables;
Future<Set<String>> loadSyllables(AssetBundle bundle) async {
  final cached = _syllables;
  if (cached != null) return cached;
  final s = await bundle.loadString('assets/data/dictation_pinyin_syllables.json');
  return _syllables = {for (final x in (jsonDecode(s) as Map)['syllables'] as List) x as String};
}

/// Mặc định theo cấp (thiết kế §1.2): A2 'Chọn chữ' (chưa cần bàn phím tiếng Trung), B1+ 'Gõ chữ Hán'. Người học đổi thì app nhớ.
DictationMode defaultModeFor(String? level) => (level == null || level == 'A1' || level == 'A2') ? DictationMode.tiles : DictationMode.hanzi;

/// Câu NGHE CHÉP (kind = dictation): nghe câu (file tĩnh; 1× / 0,75×) → chọn chữ / gõ pinyin / gõ chữ Hán → chấm NGAY trên máy
/// (dictation_grader.dart, không gọi mạng) → chỉ chỗ sai, giải thích biến điệu. Gọi [onDone] khi bấm "Tiếp".
class DictationCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final LessonV2Api api;
  final void Function(bool correct, int ms) onDone;
  final VoidCallback? onReport;
  final bool isRetry;
  final String? level;
  final bool autoplay;

  const DictationCard({super.key, required this.question, required this.api, required this.onDone, this.onReport, this.isRetry = false, this.level, this.autoplay = true});

  @override
  State<DictationCard> createState() => _DictationCardState();
}

class _DictationCardState extends State<DictationCard> {
  final _started = DateTime.now();
  final _text = TextEditingController();
  final List<int> _placed = []; // chỉ số thẻ đã chọn (thẻ có thể trùng chữ)
  DictationMode? _mode;
  bool _strict = false;
  Set<String>? _table;
  DictationResult? _result;

  Map<String, dynamic> get _p => Map<String, dynamic>.from(widget.question['payload'] as Map);
  List<String> get _tiles => [for (final t in (_p['tiles'] as List? ?? const [])) t as String];

  @override
  void initState() {
    super.initState();
    _init();
    if (widget.autoplay) WidgetsBinding.instance.addPostFrameCallback((_) => _play(1.0));
  }

  Future<void> _init() async {
    final bundle = DefaultAssetBundle.of(context);
    var mode = defaultModeFor(widget.level);
    var strict = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      mode = DictationMode.values.firstWhere((m) => m.name == prefs.getString(kDictationModePref), orElse: () => mode);
      strict = prefs.getBool(kDictationStrictTonesPref) ?? false;
    } catch (_) {}
    final table = await loadSyllables(bundle);
    if (!mounted) return;
    setState(() {
      _mode = mode;
      _strict = strict;
      _table = table;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _play(double rate) {
    final a = _p['audio'];
    if (a is Map) widget.api.playAudio({...Map<String, dynamic>.from(a), if (rate != 1.0) 'rate': rate});
  }

  Future<void> _setMode(DictationMode m) async {
    setState(() {
      _mode = m;
      _placed.clear();
      _text.clear();
    });
    try {
      (await SharedPreferences.getInstance()).setString(kDictationModePref, m.name);
    } catch (_) {}
  }

  Future<void> _setStrict(bool v) async {
    setState(() => _strict = v);
    try {
      (await SharedPreferences.getInstance()).setBool(kDictationStrictTonesPref, v);
    } catch (_) {}
  }

  bool get _canCheck => _mode == DictationMode.tiles ? _placed.isNotEmpty : _text.text.trim().isNotEmpty;

  void _check() {
    final chars = charsOf(_p);
    final r = switch (_mode!) {
      DictationMode.tiles => gradeTiles(chars, [for (final i in _placed) _tiles[i]]),
      DictationMode.pinyin => gradePinyin(chars, _text.text, _table!, strictTones: _strict),
      DictationMode.hanzi => gradeHanzi(chars, _text.text),
    };
    FocusScope.of(context).unfocus();
    setState(() => _result = r);
    r.correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.isRetry)
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Làm lại câu đã sai', style: TextStyle(color: kLessonPurple, fontSize: 12, fontWeight: FontWeight.w600))),
      Text(_p['prompt'] as String? ?? 'Nghe và chép lại câu', style: const TextStyle(color: kLessonGrey, fontSize: 13)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filled(key: const Key('dictation_play'), iconSize: 34, onPressed: () => _play(1.0), icon: const Icon(Icons.volume_up_rounded),
            style: IconButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white)),
        const SizedBox(width: 12),
        OutlinedButton.icon(key: const Key('dictation_play_slow'), onPressed: () => _play(0.75), icon: const Icon(Icons.slow_motion_video_rounded, size: 18), label: const Text('Chậm 0,75×')),
      ]),
      const SizedBox(height: 14),
      if (mode == null)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
      else ...[
        if (_result == null) ...[
          SegmentedButton<DictationMode>(
            key: const Key('dictation_mode'),
            segments: [for (final m in DictationMode.values) ButtonSegment(value: m, label: Text(_modeLabel[m]!, key: Key('dictation_mode_${m.name}')))],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _setMode(s.first),
          ),
          const SizedBox(height: 12),
          if (mode == DictationMode.tiles) _tilesInput() else _textInput(mode),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const Key('dictation_check_btn'),
            onPressed: _canCheck ? _check : null,
            style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Kiểm tra'),
          ),
        ] else
          _feedback(_result!),
      ],
    ]);
  }

  Widget _tilesInput() {
    final tiles = _tiles;
    Widget chip(int i, {required bool placed}) => InkWell(
          key: Key(placed ? 'dictation_placed_$i' : 'dictation_tile_$i'),
          onTap: () => setState(() => placed ? _placed.remove(i) : _placed.add(i)),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: placed ? const Color(0xFFEDEBFF) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: placed ? kLessonPurple : const Color(0xFFE0E3F0), width: 1.6),
            ),
            child: Text(tiles[i], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kLessonDark)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        key: const Key('dictation_answer_area'),
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0E3F0), width: 1.6)),
        child: _placed.isEmpty
            ? const Text('Chạm các chữ bên dưới theo đúng thứ tự bạn nghe', style: TextStyle(color: kLessonGrey))
            : Wrap(spacing: 6, runSpacing: 6, children: [for (final i in _placed) chip(i, placed: true)]),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (var i = 0; i < tiles.length; i++) if (!_placed.contains(i)) chip(i, placed: false)]),
    ]);
  }

  Widget _textInput(DictationMode mode) {
    final hanzi = mode == DictationMode.hanzi;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        key: const Key('dictation_input'),
        controller: _text,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        style: TextStyle(fontSize: hanzi ? 22 : 18),
        decoration: InputDecoration(
          hintText: hanzi ? '例：我明天要去看醫生' : 'vd: wo mingtian yao qu kan yisheng',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canCheck ? _check() : null,
      ),
      const SizedBox(height: 6),
      if (hanzi)
        const Text('Cần bàn phím tiếng Trung: Gboard → Ngôn ngữ → 中文 (台灣) — 注音 hoặc 拼音. Chưa có thì chọn "Chọn chữ".',
            key: Key('dictation_keyboard_hint'), style: TextStyle(color: kLessonGrey, fontSize: 12))
      else
        Row(children: [
          const Expanded(child: Text('Có/không dấu thanh đều được; gõ số thanh cũng được (ni3 hao3).', style: TextStyle(color: kLessonGrey, fontSize: 12))),
          const Text('Bắt buộc đúng thanh', style: TextStyle(fontSize: 12)),
          Switch(key: const Key('dictation_strict_switch'), value: _strict, onChanged: _setStrict),
        ]),
    ]);
  }

  Widget _feedback(DictationResult r) {
    final answer = (_p['answer_text'] as String?) ?? '';
    final pinyin = (_p['pinyin'] as String?) ?? '';
    final vi = (_p['vi'] as String?) ?? '';
    final msgs = {for (final o in r.ops) if (o.msg != null) o.msg!};
    final simplified = r.ops.any((o) => o.note == 'simplified');
    final ok = r.correct;
    return Container(
      key: const Key('lesson_feedback'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ok ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ok ? (r.hasToneIssue ? '✔ Đúng — để ý thanh điệu nhé' : '✔ Chính xác!') : '✗ Chưa đúng (${(r.accuracy * 100).round()}%)',
            key: const Key('dictation_verdict'), style: TextStyle(fontWeight: FontWeight.w800, color: ok ? kLessonGreen : kLessonRed, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(key: const Key('dictation_diff'), spacing: 4, runSpacing: 6, children: [for (var i = 0; i < r.ops.length; i++) _opChip(r.ops[i], i)]),
        if (simplified)
          const Padding(padding: EdgeInsets.only(top: 6), child: Text('Bạn đang gõ chữ giản thể; ở Đài Loan dùng chữ phồn thể như đáp án.', key: Key('dictation_simplified_note'), style: TextStyle(fontSize: 12, color: kLessonDark))),
        for (final m in msgs) Padding(padding: const EdgeInsets.only(top: 6), child: Text('💡 $m', key: const Key('dictation_msg'), style: const TextStyle(fontSize: 13, color: kLessonDark))),
        const SizedBox(height: 8),
        Text(answer, key: const Key('dictation_answer'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLessonDark)),
        if (pinyin.isNotEmpty) Text(pinyin, style: const TextStyle(color: kLessonGrey)),
        if (vi.isNotEmpty) Text(vi, style: const TextStyle(color: kLessonDark)),
        if (!ok && widget.isRetry == false) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Nghe lại vài lần rồi chép tiếp câu sau nhé.', style: TextStyle(color: kLessonGrey, fontSize: 12))),
        const SizedBox(height: 10),
        Row(children: [
          if (widget.onReport != null)
            TextButton.icon(key: const Key('lesson_report_btn'), onPressed: widget.onReport, icon: const Icon(Icons.flag_outlined, size: 16), label: const Text('Báo lỗi câu này', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: kLessonGrey)),
          const Spacer(),
          ElevatedButton(
            key: const Key('lesson_next_btn'),
            onPressed: () => widget.onDone(ok, DateTime.now().difference(_started).inMilliseconds),
            style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Tiếp'),
          ),
        ]),
      ]),
    );
  }

  /// 1 vị trí của bản so sánh: đúng (xanh) · sai (đỏ: gõ → đúng) · thiếu (cam) · thừa (gạch ngang) · sai thanh (vàng / đỏ khi bắt dấu thanh).
  Widget _opChip(DictationOp o, int i) {
    final (Color bg, Color fg, String label) = switch (o.op) {
      'ok' => (const Color(0xFFDFF5E7), kLessonDark, _show(o.exp)),
      'sub' => (const Color(0xFFFFD6D6), kLessonRed, '${_show(o.got)}→${_show(o.exp)}'),
      'del' => (const Color(0xFFFFE6C7), const Color(0xFFB45F06), '+${_show(o.exp)}'),
      'ins' => (const Color(0xFFEDEEF2), kLessonGrey, _show(o.got)),
      'tone_warn' => (const Color(0xFFFFF4C2), const Color(0xFF8A6D00), '${_show(o.got)}→${_show(o.exp)}'),
      _ => (const Color(0xFFFFD6D6), kLessonRed, '${_show(o.got)}→${_show(o.exp)}'), // tone
    };
    return Container(
      key: Key('dictation_op_${i}_${o.op}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg, decoration: o.op == 'ins' ? TextDecoration.lineThrough : null)),
    );
  }

  /// 'hao3' → 'hǎo' (âm tiết pinyin hiển thị có dấu); chữ Hán giữ nguyên.
  String _show(String? s) {
    if (s == null) return '';
    final m = RegExp(r'^([a-zü]+?)([0-5]?)$').firstMatch(s.replaceAll('v', 'ü'));
    if (m == null) return s;
    final t = int.tryParse(m[2] ?? '') ?? 0;
    return mark(m[1]!.replaceAll('ü', 'v'), t);
  }
}
