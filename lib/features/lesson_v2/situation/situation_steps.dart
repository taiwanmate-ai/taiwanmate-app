import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';
import 'package:chinesemate/features/lesson_v2/situation/tone_text.dart';

/// Các bước của bài học THEO TÌNH HUỐNG (Q3 R3, sau cờ SITUATION_V1): nghe trước, hội thoại bấm-từ-xem-nghĩa, ngữ pháp 6 phần, nói theo, tổng kết,
/// Chặng 0 (giải thích + nghe âm), bài 10 (đoạn kể, ôn lỗi, thử thách dịch có chấm). Mọi widget nhận [LessonV2Api] để phát âm thanh; KHÔNG gọi mạng khi học (trừ chấm dịch).

typedef QuestionFlowBuilder = Widget Function(List<Map<String, dynamic>> questions, String header, VoidCallback onFinished);

Map<String, dynamic>? audioOf(dynamic a) => a is Map ? Map<String, dynamic>.from(a) : null;

Widget nextButton(String label, VoidCallback onTap, {Key? key}) => ElevatedButton(
      key: key,
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    );

Widget _audioIcon(LessonV2Api api, dynamic audio, {double size = 22, Key? key}) => IconButton(
      key: key,
      visualDensity: VisualDensity.compact,
      iconSize: size,
      onPressed: audio == null ? null : () => api.playAudio(audioOf(audio)),
      icon: const Icon(Icons.volume_up_rounded, color: kLessonPurple),
    );

Widget _card({required Widget child, Color color = Colors.white, EdgeInsets padding = const EdgeInsets.all(14), Key? key}) =>
    Container(key: key, width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), child: child);

// ───────────────────────── tên nhân vật + chặng (bước intro) ─────────────────────────
Widget characterChips(List<dynamic> characters) {
  if (characters.isEmpty) return const SizedBox.shrink();
  return Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
    for (final c in characters)
      Chip(
        key: Key('character_${c['zh']}'),
        label: Text('${c['zh']} · ${c['vi']}', style: const TextStyle(fontSize: 13)),
        avatar: const Icon(Icons.record_voice_over_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      ),
  ]);
}

// ───────────────────────── 1. nghe trước ─────────────────────────
class ListenFirstStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  const ListenFirstStep({super.key, required this.step, required this.api, required this.onFinished});

  @override
  State<ListenFirstStep> createState() => _ListenFirstStepState();
}

class _ListenFirstStepState extends State<ListenFirstStep> {
  int _playing = -1;
  bool _all = false;

  List<Map<String, dynamic>> get _lines => (widget.step['lines'] as List).cast<Map<String, dynamic>>();

  Future<void> _playAll() async {
    if (_all) return;
    setState(() => _all = true);
    for (var i = 0; i < _lines.length && mounted && _all; i++) {
      setState(() => _playing = i);
      await widget.api.playAudio(audioOf(_lines[i]['audio']));
    }
    if (mounted) setState(() { _all = false; _playing = -1; });
  }

  @override
  void dispose() {
    _all = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Nghe trước', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 4),
      Text(widget.step['hint'] as String? ?? 'Nghe cả đoạn hội thoại trước, chưa cần hiểu hết.', style: const TextStyle(color: kLessonGrey)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        key: const Key('listen_all'),
        onPressed: _playAll,
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: Text(_all ? 'Đang phát…' : 'Nghe cả đoạn hội thoại'),
        style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: ListView(children: [
          for (final l in _lines)
            _card(
              color: _playing == l['i'] ? const Color(0xFFEDEEFF) : Colors.white,
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: kLessonPurple.withOpacity(0.12), child: Text('${(l['i'] as int) + 1}', style: const TextStyle(color: kLessonPurple, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(child: Text(l['speaker_vi'] as String? ?? l['speaker'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                _audioIcon(widget.api, l['audio']),
              ]),
            ),
        ]),
      ),
      nextButton('Đã nghe, xem từ mới', widget.onFinished, key: const Key('listen_first_next')),
    ]);
  }
}

// ───────────────────────── 3. thẻ từ chuẩn (Phần 3) ─────────────────────────
class RichWordCard extends StatelessWidget {
  final Map<String, dynamic> w;
  final LessonV2Api api;
  final VoidCallback onNext;
  final String header;
  const RichWordCard({super.key, required this.w, required this.api, required this.onNext, required this.header});

  @override
  Widget build(BuildContext context) {
    final text = w['text'] as String;
    final hv = displayHanViet(text, w['han_viet'] as String?);
    final cl = (w['classifier'] as String?)?.trim() ?? '';
    final split = w['split_example'] is Map ? Map<String, dynamic>.from(w['split_example'] as Map) : null;
    final chunks = (w['chunks'] as List?)?.cast<Map>() ?? const [];
    final note = (w['note'] as String?)?.trim() ?? '';
    final pos = (w['pos'] as String?)?.trim() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(header, style: const TextStyle(fontWeight: FontWeight.w800)),
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 14),
            Center(child: Text(text, key: const Key('word_text'), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: kLessonDark))),
            Center(child: PinyinText(w['pron'] as String? ?? '', fontSize: 22, align: TextAlign.center)),
            if (hv != null) Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(hv, key: const Key('word_han_viet'), style: const TextStyle(fontSize: 15, letterSpacing: 1, color: Color(0xFF6B6F85), fontWeight: FontWeight.w600)))),
            const SizedBox(height: 4),
            Center(child: Text(w['meaning'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kLessonPurple))),
            Center(child: _audioIcon(api, w['audio'], size: 36, key: const Key('word_audio'))),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
              if (pos.isNotEmpty) Chip(label: Text(pos, style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact),
              if (cl.isNotEmpty) Chip(key: const Key('word_classifier'), label: Text('Lượng từ: $cl', style: const TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact, backgroundColor: const Color(0xFFE8F0FE)),
              if (w['separable'] == true) Chip(key: const Key('word_separable'), label: const Text('Động từ ly hợp', style: TextStyle(fontSize: 12)), visualDensity: VisualDensity.compact, backgroundColor: const Color(0xFFFFF3E0)),
            ]),
            if (split != null && (split['zh'] as String?)?.isNotEmpty == true)
              _card(key: const Key('word_split'), color: const Color(0xFFFFF3E0), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ly hợp: có thể bị tách ra', style: TextStyle(fontSize: 12, color: Color(0xFF8D6E00), fontWeight: FontWeight.w700)),
                  Text(split['zh'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(split['vi'] as String? ?? '', style: const TextStyle(color: kLessonGrey)),
                ])),
                _audioIcon(api, {'type': 'audio', 'text': split['zh'], 'lang': 'zh-TW'}),
              ])),
            if (chunks.isNotEmpty)
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cụm hay dùng', style: TextStyle(fontSize: 12, color: kLessonGrey, fontWeight: FontWeight.w700)),
                for (final c in chunks)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${c['zh']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${c['vi']}', style: const TextStyle(color: kLessonGrey)),
                    ])),
                    _audioIcon(api, {'type': 'audio', 'text': c['zh'], 'lang': 'zh-TW'}),
                  ])),
              ])),
            if ((w['example'] as String?)?.isNotEmpty == true)
              _card(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w['example'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if ((w['example_vi'] as String?)?.isNotEmpty == true) Text(w['example_vi'] as String, style: const TextStyle(color: kLessonGrey)),
                ])),
                _audioIcon(api, w['example_audio']),
              ])),
            if (note.isNotEmpty)
              _card(
                key: const Key('word_note'),
                color: const Color(0xFFFFF8E1),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF8D6E00)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note, style: const TextStyle(color: Color(0xFF5D4700), fontSize: 14))),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      nextButton('Tiếp', onNext, key: const Key('word_next')),
    ]);
  }
}

/// Mục TÊN RIÊNG và CỤM CỐ ĐỊNH tách riêng khỏi danh sách từ mới (Phần 6B.4).
class SpecialEntriesPage extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final LessonV2Api api;
  final VoidCallback onNext;
  const SpecialEntriesPage({super.key, required this.entries, required this.api, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final names = entries.where((e) => e['entry'] == 'proper_noun').toList();
    final fixed = entries.where((e) => e['entry'] == 'fixed_phrase').toList();
    Widget section(String title, List<Map<String, dynamic>> items, Key key) => items.isEmpty
        ? const SizedBox.shrink()
        : Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            for (final e in items)
              _card(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['text'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  PinyinText(e['pron'] as String? ?? ''),
                  Text(e['meaning'] as String? ?? '', style: const TextStyle(color: kLessonPurple, fontWeight: FontWeight.w600)),
                ])),
                _audioIcon(api, e['audio']),
              ])),
          ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ghi nhớ thêm', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        section('Tên riêng', names, const Key('special_names')),
        section('Cụm cố định', fixed, const Key('special_fixed')),
      ]))),
      nextButton('Tiếp', onNext, key: const Key('special_next')),
    ]);
  }
}

// ───────────────────────── 4. hội thoại: giọng theo nhân vật, bấm từ xem nghĩa ─────────────────────────
void showGloss(BuildContext context, Map gloss, String word) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => Padding(
      key: const Key('gloss_sheet'),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(word, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        if ((gloss['pinyin'] as String?)?.isNotEmpty == true) PinyinText(gloss['pinyin'] as String, fontSize: 18),
        const SizedBox(height: 6),
        Text(gloss['vi'] as String? ?? '', style: const TextStyle(fontSize: 18, color: kLessonPurple, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class GlossedText extends StatelessWidget {
  final List<dynamic> tokens;
  final double fontSize;
  const GlossedText({super.key, required this.tokens, this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Wrap(children: [
      for (final t in tokens)
        if (t['gloss'] is Map)
          InkWell(
            key: Key('gloss_${t['t']}'),
            onTap: () => showGloss(context, t['gloss'] as Map, t['t'] as String),
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kLessonPurple, width: 1.6, style: BorderStyle.solid))),
              child: Text(t['t'] as String, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: kLessonDark)),
            ),
          )
        else
          Text(t['t'] as String, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: kLessonDark)),
    ]);
  }
}

class SituationDialogueStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  final bool narrative; // bài 10: đoạn kể (không tên người nói)
  const SituationDialogueStep({super.key, required this.step, required this.api, required this.onFinished, this.narrative = false});

  @override
  State<SituationDialogueStep> createState() => _SituationDialogueStepState();
}

class _SituationDialogueStepState extends State<SituationDialogueStep> {
  bool _pinyin = true;
  bool _vi = false;

  @override
  Widget build(BuildContext context) {
    final lines = ((widget.narrative ? widget.step['segments'] : widget.step['lines']) as List).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${widget.narrative ? 'Đoạn kể' : 'Hội thoại'} · ${widget.step['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(widget.narrative ? (widget.step['hint'] as String? ?? '') : 'Bấm từ gạch chân để xem nghĩa.', style: const TextStyle(color: kLessonGrey, fontSize: 12)),
      Row(children: [
        FilterChip(key: const Key('toggle_pinyin'), label: const Text('Pinyin'), selected: _pinyin, onSelected: (v) => setState(() => _pinyin = v)),
        const SizedBox(width: 8),
        FilterChip(key: const Key('toggle_vi'), label: const Text('Dịch'), selected: _vi, onSelected: (v) => setState(() => _vi = v)),
      ]),
      Expanded(
        child: ListView(children: [
          for (final l in lines)
            _card(
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!widget.narrative) Text(l['speaker_vi'] as String? ?? l['speaker'] as String? ?? '', style: const TextStyle(color: kLessonPurple, fontWeight: FontWeight.w800, fontSize: 12)),
                  GlossedText(tokens: (l['tokens'] as List?) ?? [{'t': l['text']}]),
                  if (_pinyin && (l['pinyin'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 2), child: PinyinText(l['pinyin'] as String, fontSize: 14)),
                  if (_vi && (l['vi'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l['vi'] as String, key: const Key('line_vi'), style: const TextStyle(color: kLessonPurple))),
                ])),
                _audioIcon(widget.api, l['audio']),
              ]),
            ),
        ]),
      ),
      nextButton('Tiếp', widget.onFinished, key: const Key('dialogue_next')),
    ]);
  }
}

// ───────────────────────── 5. ngữ pháp 6 phần (Phần 6B) ─────────────────────────
class SituationGrammarStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final QuestionFlowBuilder flow;
  final VoidCallback onFinished;
  const SituationGrammarStep({super.key, required this.step, required this.api, required this.flow, required this.onFinished});

  @override
  State<SituationGrammarStep> createState() => _SituationGrammarStepState();
}

class _SituationGrammarStepState extends State<SituationGrammarStep> {
  bool _practice = false;

  Widget _ex(Map e, Map<String, dynamic> audioBy, {bool wrong = false}) {
    final zh = (e['zh'] ?? e['right'] ?? e['wrong'] ?? '') as String;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(zh, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: wrong ? kLessonRed : kLessonDark, decoration: wrong ? TextDecoration.lineThrough : null)),
          if ((e['pinyin'] as String?)?.isNotEmpty == true) PinyinText(e['pinyin'] as String, fontSize: 13),
          if ((e['vi'] as String?)?.isNotEmpty == true) Text(e['vi'] as String, style: const TextStyle(color: kLessonGrey, fontSize: 13)),
        ])),
        if (!wrong) _audioIcon(widget.api, audioBy[zh] ?? {'type': 'audio', 'text': zh, 'lang': 'zh-TW'}),
      ]),
    );
  }

  Widget _sec(String title, Key key, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kLessonPurple, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          ...children,
        ]),
      );

  Widget _point(int i, Map<String, dynamic> p) {
    final audioBy = <String, dynamic>{for (final a in (p['examples_audio'] as List? ?? const [])) (a['zh'] as String): a['audio']};
    final st = Map<String, dynamic>.from(p['structures'] as Map);
    final ng = Map<String, dynamic>.from(p['negation'] as Map);
    final qs = Map<String, dynamic>.from(p['questions'] as Map);
    final contrasts = (p['usage_contrasts'] as List? ?? const []).cast<Map>();
    final mistakes = (p['mistakes'] as List? ?? const []).cast<Map>();
    return Container(
      key: Key('grammar_point_$i'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: i == 0 ? kLessonPurple.withOpacity(0.4) : const Color(0xFFE0E3F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i == 0 ? 'Điểm chính' : 'Điểm phụ', style: const TextStyle(fontSize: 11, color: kLessonGrey, fontWeight: FontWeight.w700)),
        Text(p['title'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        _sec('1 · CHỨC NĂNG', Key('gp${i}_function'), [Text(p['function'] as String? ?? '')]),
        _sec('2 · CẤU TRÚC', Key('gp${i}_structure'), [
          Text(st['formula'] as String? ?? '', style: const TextStyle(fontSize: 18, color: kLessonPurple, fontWeight: FontWeight.w800)),
          for (final e in (st['examples'] as List).cast<Map>()) _ex(e, audioBy),
        ]),
        _sec('3 · PHỦ ĐỊNH', Key('gp${i}_negation'), [
          Text(ng['rule'] as String? ?? ''),
          for (final e in (ng['examples'] as List).cast<Map>()) _ex(e, audioBy),
        ]),
        _sec('4 · CÂU HỎI', Key('gp${i}_questions'), [
          Text(qs['rule'] as String? ?? ''),
          for (final e in (qs['examples'] as List).cast<Map>()) _ex(e, audioBy),
        ]),
        if (contrasts.isNotEmpty)
          _sec('5 · CẶP DỄ NHẦM', Key('gp${i}_contrast'), [
            for (final c in contrasts) ...[
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF3F4FF), borderRadius: BorderRadius.circular(10)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(c['a'] as Map)['label']}', style: const TextStyle(fontSize: 11, color: kLessonGrey, fontWeight: FontWeight.w700)),
                  _ex(c['a'] as Map, audioBy),
                  const Divider(height: 14),
                  Text('${(c['b'] as Map)['label']}', style: const TextStyle(fontSize: 11, color: kLessonGrey, fontWeight: FontWeight.w700)),
                  _ex(c['b'] as Map, audioBy),
                  const SizedBox(height: 6),
                  Text('${c['note']}', style: const TextStyle(color: kLessonDark, fontSize: 13)),
                ]),
              ),
            ],
          ]),
        _sec('6 · LỖI NGƯỜI VIỆT HAY MẮC', Key('gp${i}_mistakes'), [
          for (final m in mistakes) ...[
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('✗ ${m['wrong']}', style: const TextStyle(fontSize: 18, color: kLessonRed, fontWeight: FontWeight.w700))),
            Row(children: [
              Expanded(child: Text('✓ ${m['right']}', style: const TextStyle(fontSize: 18, color: kLessonGreen, fontWeight: FontWeight.w700))),
              _audioIcon(widget.api, audioBy['${m['right']}'] ?? {'type': 'audio', 'text': m['right'], 'lang': 'zh-TW'}),
            ]),
            Text('${m['why']}', style: const TextStyle(color: kLessonGrey, fontSize: 13)),
          ],
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qs = (widget.step['questions'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (_practice && qs.isNotEmpty) return widget.flow(qs, 'Làm thử mẫu câu', widget.onFinished);
    final points = (widget.step['points'] as List).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Ngữ pháp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 8),
      Expanded(child: SingleChildScrollView(child: Column(children: [for (var i = 0; i < points.length; i++) _point(i, points[i])]))),
      nextButton(qs.isEmpty ? 'Tiếp' : 'Làm thử', () => qs.isEmpty ? widget.onFinished() : setState(() => _practice = true), key: const Key('grammar_next')),
    ]);
  }
}

// ───────────────────────── 7. nói theo (ghi âm cục bộ + nghe lại, KHÔNG chấm, KHÔNG tải lên) ─────────────────────────
class SpeakingStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  const SpeakingStep({super.key, required this.step, required this.api, required this.onFinished});

  @override
  State<SpeakingStep> createState() => _SpeakingStepState();
}

class _SpeakingStepState extends State<SpeakingStep> {
  int _i = 0;
  bool _recording = false;
  String? _error;
  final Map<int, String> _takes = {}; // base64 bản ghi — CHỈ trong bộ nhớ, không rời thiết bị

  List<Map<String, dynamic>> get _lines => (widget.step['lines'] as List).cast<Map<String, dynamic>>();

  Future<void> _toggle() async {
    if (_recording) {
      webStopRecording();
      return;
    }
    setState(() { _recording = true; _error = null; });
    try {
      await webStartRecording((b64) {
        if (!mounted) return;
        setState(() { _recording = false; _takes[_i] = b64; });
      }, (err) {
        if (!mounted) return;
        setState(() { _recording = false; _error = '$err Bạn có thể bỏ qua bước này.'; });
      });
    } catch (_) {
      if (mounted) setState(() { _recording = false; _error = 'Không ghi âm được. Bạn có thể bỏ qua bước này.'; });
    }
  }

  void _next() {
    if (_recording) webStopRecording();
    if (_i + 1 < _lines.length) {
      setState(() { _i++; _error = null; });
    } else {
      widget.onFinished();
    }
  }

  @override
  void dispose() {
    if (_recording) webStopRecording();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lines[_i];
    final take = _takes[_i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Nói theo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const Spacer(),
        Text('${_i + 1}/${_lines.length}', style: const TextStyle(color: kLessonGrey)),
      ]),
      Text(widget.step['privacy'] as String? ?? 'Không chấm điểm; bản ghi chỉ ở trên thiết bị của bạn.', key: const Key('speaking_privacy'), style: const TextStyle(color: kLessonGrey, fontSize: 12)),
      const Spacer(),
      Center(child: Text(l['zh'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))),
      if ((l['pinyin'] as String?)?.isNotEmpty == true) Center(child: PinyinText(l['pinyin'] as String, fontSize: 18, align: TextAlign.center)),
      if ((l['vi'] as String?)?.isNotEmpty == true) Center(child: Text(l['vi'] as String, style: const TextStyle(color: kLessonPurple, fontSize: 16))),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton.icon(key: const Key('speaking_listen'), onPressed: () => widget.api.playAudio(audioOf(l['audio'])), icon: const Icon(Icons.volume_up_rounded), label: const Text('Nghe mẫu')),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          key: const Key('speaking_record'),
          onPressed: _toggle,
          icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(_recording ? 'Dừng' : 'Ghi âm'),
          style: ElevatedButton.styleFrom(backgroundColor: _recording ? kLessonRed : kLessonPurple, foregroundColor: Colors.white),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          key: const Key('speaking_replay'),
          onPressed: take == null ? null : () => webPlayAudio(take, mime: 'audio/${getRecordingMimeType()}'),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Nghe lại'),
        ),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('speaking_error'), textAlign: TextAlign.center, style: const TextStyle(color: kLessonRed, fontSize: 13))),
      const Spacer(),
      Row(children: [
        TextButton(key: const Key('speaking_skip'), onPressed: widget.onFinished, child: const Text('Bỏ qua bước này')),
        const Spacer(),
        SizedBox(width: 160, child: nextButton(_i + 1 < _lines.length ? 'Câu tiếp' : 'Xong', _next, key: const Key('speaking_next'))),
      ]),
    ]);
  }
}

// ───────────────────────── 8. tổng kết (bước cuối trước màn kết quả) ─────────────────────────
class SituationSummaryStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  const SituationSummaryStep({super.key, required this.step, required this.api, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    final lines = (step['lines'] as List? ?? const []).cast<Map>();
    final canDo = (step['can_do'] as List? ?? const []).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Tổng kết', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 6),
      const Text('Giờ bạn nói được:', style: TextStyle(color: kLessonGrey)),
      Expanded(
        child: ListView(children: [
          if (lines.isNotEmpty)
            for (final l in lines)
              _card(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['zh']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if ('${l['pinyin'] ?? ''}'.isNotEmpty) PinyinText('${l['pinyin']}', fontSize: 14),
                  if ('${l['vi'] ?? ''}'.isNotEmpty) Text('${l['vi']}', style: const TextStyle(color: kLessonPurple)),
                ])),
                _audioIcon(api, {'type': 'audio', 'text': l['zh'], 'lang': 'zh-TW'}),
              ]))
          else
            for (final c in canDo) _card(child: Text('✦ $c', style: const TextStyle(fontSize: 16))),
        ]),
      ),
      nextButton('Hoàn thành bài', onFinished, key: const Key('situation_summary_next')),
    ]);
  }
}

// ───────────────────────── Chặng 0: giải thích + nghe âm ─────────────────────────
class PronExplainStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final VoidCallback onFinished;
  const PronExplainStep({super.key, required this.step, required this.onFinished});

  @override
  State<PronExplainStep> createState() => _PronExplainStepState();
}

class _PronExplainStepState extends State<PronExplainStep> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final secs = (widget.step['sections'] as List).cast<Map<String, dynamic>>();
    final s = secs[_i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Giải thích ${_i + 1}/${secs.length}', style: const TextStyle(color: kLessonGrey)),
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s['title'] as String? ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _card(child: Text(s['viet'] as String? ?? '', key: const Key('pron_viet'), style: const TextStyle(fontSize: 16, height: 1.5))),
            if ((s['compare'] as String?)?.isNotEmpty == true)
              _card(color: const Color(0xFFE8F8EE), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('So với tiếng Việt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kLessonGreen)),
                Text(s['compare'] as String, style: const TextStyle(height: 1.5)),
              ])),
            if ((s['pitfall'] as String?)?.isNotEmpty == true)
              _card(color: const Color(0xFFFFF8E1), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Người Việt hay sai', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8D6E00))),
                Text(s['pitfall'] as String, style: const TextStyle(height: 1.5)),
              ])),
          ]),
        ),
      ),
      nextButton(_i + 1 < secs.length ? 'Tiếp' : 'Nghe và nhắc lại', () => _i + 1 < secs.length ? setState(() => _i++) : widget.onFinished(), key: const Key('pron_explain_next')),
    ]);
  }
}

class PronListenStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  const PronListenStep({super.key, required this.step, required this.api, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    final items = (step['items'] as List).cast<Map<String, dynamic>>();
    final words = (step['words'] as List? ?? const []).cast<Map<String, dynamic>>();
    final groups = <dynamic, List<Map<String, dynamic>>>{};
    for (final it in items) {
      groups.putIfAbsent(it['group'], () => []).add(it);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Nghe và nhắc lại', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      Text(step['hint'] as String? ?? '', style: const TextStyle(color: kLessonGrey, fontSize: 12)),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final g in groups.values)
              _card(child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final it in g)
                  InkWell(
                    key: Key('pron_item_${it['spelling']}'),
                    onTap: () => api.playAudio(audioOf(it['audio'])),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 78,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFF3F4FF), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        PinyinText('${it['spelling']}', fontSize: 20, align: TextAlign.center),
                        Text('${it['hanzi']}', style: const TextStyle(fontSize: 16, color: kLessonGrey)),
                        const Icon(Icons.volume_up_rounded, size: 16, color: kLessonPurple),
                      ]),
                    ),
                  ),
              ])),
            if (words.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(top: 6, bottom: 6), child: Text('Từ cần đọc đúng', style: TextStyle(fontWeight: FontWeight.w800))),
              for (final w in words)
                _card(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${w['zh']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('viết: ${w['written']}  →  đọc: ${w['spoken']}', style: const TextStyle(color: kLessonGrey)),
                  ])),
                  _audioIcon(api, w['audio']),
                ])),
            ],
          ]),
        ),
      ),
      nextButton('Làm bài tập', onFinished, key: const Key('pron_listen_next')),
    ]);
  }
}

// ───────────────────────── Bài 10: ôn lỗi + thử thách dịch có chấm ─────────────────────────
class MistakesStep extends StatelessWidget {
  final Map<String, dynamic> step;
  final VoidCallback onFinished;
  const MistakesStep({super.key, required this.step, required this.onFinished});

  @override
  Widget build(BuildContext context) {
    final items = (step['items'] as List).cast<Map>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(step['title'] as String? ?? 'Lỗi hay mắc', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 8),
      Expanded(
        child: ListView(children: [
          for (final m in items)
            _card(key: const Key('mistake_card'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✗ ${m['wrong']}', style: const TextStyle(fontSize: 19, color: kLessonRed, fontWeight: FontWeight.w700)),
              Text('✓ ${m['right']}', style: const TextStyle(fontSize: 19, color: kLessonGreen, fontWeight: FontWeight.w700)),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('${m['why']}', style: const TextStyle(color: kLessonGrey))),
            ])),
        ]),
      ),
      nextButton('Tiếp', onFinished, key: const Key('mistakes_next')),
    ]);
  }
}

/// Số lượt chấm còn lại (server đếm theo BÀI dịch khác nhau/ngày): {used, limit} -> "Còn R/L lượt hôm nay".
String quotaLabel(Map? quota) {
  if (quota == null) return '';
  final used = (quota['used'] as num?)?.toInt() ?? 0;
  final limit = (quota['limit'] as num?)?.toInt() ?? 0;
  final left = (limit - used).clamp(0, limit);
  return 'Còn $left/$limit lượt chấm dịch hôm nay';
}

class ChallengeStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onFinished;
  const ChallengeStep({super.key, required this.step, required this.api, required this.onFinished});

  @override
  State<ChallengeStep> createState() => _ChallengeStepState();
}

class _ChallengeStepState extends State<ChallengeStep> {
  int _i = 0;
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _quota;

  @override
  void initState() {
    super.initState();
    _quota = widget.step['quota'] is Map ? Map<String, dynamic>.from(widget.step['quota'] as Map) : null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _segs => (widget.step['segments'] as List).cast<Map<String, dynamic>>();

  Future<void> _grade() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final sit = widget.api is SituationApi ? widget.api as SituationApi : null;
      if (sit == null) throw GradeError('UNSUPPORTED', 'Tính năng này chưa sẵn sàng');
      final r = await sit.gradeTranslation(widget.step['exercise_id'] as String, _segs[_i]['idx'] as int, t);
      if (!mounted) return;
      setState(() { _result = r; _quota = r['quota'] is Map ? Map<String, dynamic>.from(r['quota'] as Map) : _quota; _busy = false; });
    } on GradeError catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _busy = false; if (e.quota != null) _quota = e.quota; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Chấm bài tạm thời không được, thử lại sau nhé'; _busy = false; });
    }
  }

  void _next() {
    if (_i + 1 < _segs.length) {
      setState(() { _i++; _result = null; _error = null; _ctrl.clear(); });
    } else {
      widget.onFinished();
    }
  }

  Widget _score(String label, dynamic v) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(child: LinearProgressIndicator(value: ((v as num?) ?? 0) / 100, minHeight: 8, color: kLessonGreen, backgroundColor: const Color(0xFFE0E3F0))),
          SizedBox(width: 40, child: Text('  $v', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final seg = _segs[_i];
    final r = _result;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Text('Thử thách dịch', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const Spacer(),
        Text('${_i + 1}/${_segs.length}', style: const TextStyle(color: kLessonGrey)),
      ]),
      Text(quotaLabel(_quota), key: const Key('challenge_quota'), style: const TextStyle(color: kLessonPurple, fontSize: 12, fontWeight: FontWeight.w700)),
      Text(widget.step['hint'] as String? ?? '', style: const TextStyle(color: kLessonGrey, fontSize: 12)),
      const SizedBox(height: 10),
      Expanded(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _card(child: Row(children: [
              Expanded(child: Text(seg['source'] as String, key: const Key('challenge_source'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
              _audioIcon(widget.api, {'type': 'audio', 'text': seg['source'], 'lang': 'zh-TW'}),
            ])),
            TextField(key: const Key('challenge_input'), controller: _ctrl, enabled: !_busy && r == null, maxLength: 300, minLines: 2, maxLines: 4, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Dịch sang tiếng Việt…')),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('challenge_error'), style: const TextStyle(color: kLessonRed))),
            if (r != null)
              _card(key: const Key('challenge_result'), color: const Color(0xFFF3F4FF), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _score('Đúng nghĩa', (r['scores'] as Map?)?['meaning']),
                _score('Tự nhiên', (r['scores'] as Map?)?['natural']),
                _score('Ngữ pháp', (r['scores'] as Map?)?['grammar']),
                if ('${r['comment'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${r['comment']}')),
                if ('${r['natural_version'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Gợi ý: ${r['natural_version']}', style: const TextStyle(color: kLessonPurple, fontWeight: FontWeight.w700))),
                for (final s in ((r['literal_spots'] as List?) ?? const []).cast<Map>())
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('• "${s['user_part']}": ${s['issue']} → ${s['better']}', style: const TextStyle(fontSize: 13))),
                Align(alignment: Alignment.centerRight, child: TextButton(key: const Key('challenge_report'), onPressed: () { final a = widget.api; if (a is SituationApi) (a as SituationApi).reportGrade('${r['attempt_id']}'); }, child: const Text('Báo lỗi chấm', style: TextStyle(fontSize: 12)))),
              ])),
          ]),
        ),
      ),
      Row(children: [
        TextButton(key: const Key('challenge_skip'), onPressed: widget.onFinished, child: const Text('Bỏ qua thử thách')),
        const Spacer(),
        if (r == null)
          SizedBox(width: 160, child: nextButton(_busy ? 'Đang chấm…' : 'Chấm bài', _busy ? () {} : _grade, key: const Key('challenge_grade')))
        else
          SizedBox(width: 160, child: nextButton(_i + 1 < _segs.length ? 'Câu tiếp' : 'Xong', _next, key: const Key('challenge_next'))),
      ]),
    ]);
  }
}
