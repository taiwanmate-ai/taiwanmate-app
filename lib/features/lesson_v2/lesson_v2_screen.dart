import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/lesson_v2/lesson_runner.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/match_widgets.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';

/// Bai hoc moi (6 buoc + mini-game + man ket thuc). Moi cau hoi lay tu phien server tra 1 lan; KHONG goi AI khi dang hoc.
/// Chay sau cong tac `lesson_v2_enabled` (server). Pop ket qua: Map {next_unit_id, level_completed, ...} khi nguoi hoc bam "Bai tiep theo".
class LessonV2Screen extends ConsumerStatefulWidget {
  final String unitId;
  final String? title;
  final LessonV2Api? api; // test hook
  const LessonV2Screen({super.key, required this.unitId, this.title, this.api});

  @override
  ConsumerState<LessonV2Screen> createState() => _LessonV2ScreenState();
}

class _LessonV2ScreenState extends ConsumerState<LessonV2Screen> {
  late final LessonV2Api _api = widget.api ?? ref.read(lessonV2ApiProvider);
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _steps = [];
  int _idx = 0;
  String? _error;
  bool _fellBack = false;
  final List<AnswerRecord> _records = [];
  Map<String, dynamic>? _summary;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Tai phien that bai (loi server / mang / cong tac tat) -> TU DONG quay ve bai hoc cu: dong man hinh va bao [fallback] cho man goi.
  /// Chi ap dung luc TAI phien (chua hoc gi); loi luc luu ket qua van o lai man hinh voi nut Thu lai de khong mat bai da lam.
  void _fallbackToOldLesson() {
    if (!mounted || _fellBack) return;
    _fellBack = true;
    Navigator.pop(context, {'fallback': true});
  }

  Future<void> _load() async {
    setState(() { _error = null; _session = null; });
    try {
      final s = await _api.fetchSession(widget.unitId);
      if (!mounted) return;
      final steps = visibleSteps(s);
      if (steps.isEmpty) {
        _fallbackToOldLesson(); // phien rong/khong hop le -> bai cu
        return;
      }
      setState(() { _session = s; _steps = steps; _idx = 0; });
    } catch (_) {
      _fallbackToOldLesson();
    }
  }

  void _next() {
    if (_idx + 1 < _steps.length) {
      setState(() => _idx++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _submitError = null; });
    try {
      final res = await _api.submitAnswers(widget.unitId, buildAnswersBody(_session!['session_id'] as String, _records));
      if (mounted) setState(() { _summary = res; _submitting = false; });
    } catch (_) {
      if (mounted) setState(() { _submitting = false; _submitError = 'Chưa lưu được kết quả. Thử lại nhé.'; });
    }
  }

  Future<void> _report(Map<String, dynamic> q) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('Báo lỗi câu này'), children: [
        for (final r in ['Đáp án sai', 'Dịch / nghĩa sai', 'Câu khó hiểu', 'Âm thanh lỗi', 'Khác'])
          SimpleDialogOption(key: Key('report_reason_$r'), onPressed: () => Navigator.pop(ctx, r), child: Text(r)),
      ]),
    );
    if (reason == null) return;
    try {
      await _api.reportQuestion(q['id'] as String, reason: reason);
    } catch (_) {}
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn! Chúng tôi sẽ kiểm tra câu này.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kLessonDark,
        title: Text(widget.title ?? (_session?['unit']?['topic_vi'] as String?) ?? 'Bài học', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        bottom: _session == null || _summary != null || _steps.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: (_idx + 1) / _steps.length, minHeight: 4, backgroundColor: const Color(0xFFE0E3F0), color: kLessonPurple)),
      ),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: _body())),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(key: const Key('lesson_retry_load'), onPressed: _load, child: const Text('Thử lại')),
      ]));
    }
    if (_session == null) return const Center(child: CircularProgressIndicator());
    if (_summary != null || _idx >= _steps.length) return _summaryView();
    if (_submitting || _submitError != null) return _submittingView();
    final step = _steps[_idx];
    // key theo buoc de moi buoc co state rieng
    return KeyedSubtree(key: ValueKey('step_$_idx'), child: _stepView(step));
  }

  Widget _stepView(Map<String, dynamic> step) {
    switch (step['type']) {
      case 'intro':
        return _intro(step);
      case 'review':
        return _QuestionFlow(
          questions: (step['questions'] as List).cast<Map<String, dynamic>>(), alts: const {}, api: _api, header: 'Ôn lại những từ bạn hay quên',
          onRecord: _records.add, onReport: _report, onFinished: _next, retry: false);
      case 'new_words':
        return _NewWordsFlow(pairs: (step['pairs'] as List).cast<Map<String, dynamic>>(), api: _api, onRecord: _records.add, onReport: _report, onFinished: _next);
      case 'dialogue':
        return _DialogueStep(step: step, api: _api, onRecord: _records.add, onReport: _report, onFinished: _next);
      case 'grammar':
        return _GrammarStep(step: step, api: _api, onRecord: _records.add, onReport: _report, onFinished: _next);
      case 'practice':
        final alts = <String, List<Map<String, dynamic>>>{
          for (final e in ((_session!['retry'] as Map)['alts'] as Map).entries) e.key as String: (e.value as List).cast<Map<String, dynamic>>(),
        };
        return _QuestionFlow(
          questions: (step['questions'] as List).cast<Map<String, dynamic>>(), alts: alts, api: _api, header: 'Luyện tập',
          onRecord: _records.add, onReport: _report, onFinished: _next, retry: true);
      case 'minigame':
        return _MinigameStep(step: step, api: _api, onDone: _next);
      default:
        return Center(child: ElevatedButton(onPressed: _next, child: const Text('Tiếp')));
    }
  }

  Widget _intro(Map<String, dynamic> step) {
    final goals = (step['goals'] as List?)?.cast<String>() ?? const [];
    final unit = _session!['unit'] as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Chặng ${unit['level']} · Bài ${unit['order']} / ${unit['total_units']}', style: const TextStyle(color: kLessonGrey)),
      const Spacer(),
      Center(child: Text(step['title'] as String? ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kLessonDark))),
      if (step['title_target'] != null) Center(child: Text(step['title_target'] as String, style: const TextStyle(fontSize: 18, color: kLessonGrey))),
      if (step['scene'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text(step['scene'] as String, style: const TextStyle(color: kLessonGrey)))),
      const SizedBox(height: 24),
      const Text('Hôm nay bạn sẽ làm được:', style: TextStyle(fontWeight: FontWeight.w700, color: kLessonDark)),
      const SizedBox(height: 8),
      for (final g in goals) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('✦ $g', style: const TextStyle(fontSize: 16, color: kLessonDark))),
      const SizedBox(height: 8),
      Text('~${step['estimated_minutes']} phút', style: const TextStyle(color: kLessonGrey)),
      const Spacer(),
      ElevatedButton(
        key: const Key('lesson_start_btn'),
        onPressed: _next,
        style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('Bắt đầu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  Widget _submittingView() {
    if (_submitting) return const Center(child: CircularProgressIndicator());
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_submitError!),
      const SizedBox(height: 12),
      ElevatedButton(key: const Key('lesson_retry_submit'), onPressed: _submit, child: const Text('Thử lại')),
    ]));
  }

  Widget _summaryView() {
    if (_summary == null) return _submittingView();
    final s = _summary!;
    if (s['duplicate'] == true) {
      return Center(child: ElevatedButton(onPressed: () => Navigator.pop(context, s), child: const Text('Xong')));
    }
    final score = s['score'] as Map;
    final progress = s['progress'] as Map;
    final done = (progress['completed_units'] as num).toInt();
    final total = (progress['total_units'] as num).toInt();
    final levelDone = s['level_completed'] == true;
    final wrong = (s['wrong_word_ids'] as List).length;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        Center(child: Text(levelDone ? '🏆 Hoàn thành chặng ${progress['level']}!' : '🎉 Xong bài!', key: const Key('summary_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kLessonDark))),
        const SizedBox(height: 8),
        Center(child: Text('Đúng ${score['correct']}/${score['total']} câu (${score['percent']}%)', key: const Key('summary_score'), style: const TextStyle(fontSize: 18, color: kLessonDark))),
        const SizedBox(height: 18),
        const Text('Bạn làm được:', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final c in (s['can_do'] as List).cast<String>()) Padding(padding: const EdgeInsets.only(top: 6), child: Text('✔ $c', style: const TextStyle(fontSize: 16))),
        const SizedBox(height: 16),
        if ((s['due_tomorrow'] as num) > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEDEEFF), borderRadius: BorderRadius.circular(12)),
            child: Text('🔁 Mai ôn lại ${s['due_tomorrow']} từ (ở mục Học hôm nay)', key: const Key('summary_due')),
          ),
        const SizedBox(height: 10),
        Text('⭐ +${s['xp_gained']} XP     🔥 Chuỗi ${s['streak_days']} ngày', key: const Key('summary_xp'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Text('Chặng ${progress['level']}: $done/$total bài', style: const TextStyle(color: kLessonGrey)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 10, color: kLessonGreen, backgroundColor: const Color(0xFFE0E3F0))),
        if (wrong > 0) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Có $wrong từ cần ôn lại — hệ thống sẽ nhắc bạn.', style: const TextStyle(color: kLessonGrey))),
        const SizedBox(height: 22),
        ElevatedButton(
          key: const Key('summary_continue'),
          onPressed: () => Navigator.pop(context, s),
          style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(levelDone ? 'Về danh sách' : 'Bài tiếp theo →', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

typedef _Report = Future<void> Function(Map<String, dynamic> q);

/// Hang doi cau hoi (on lai / luyen tap / cau hoi sau hoi thoai-ngu phap). Co "sai -> hoi lai bang dang khac" khi [retry].
class _QuestionFlow extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<String, List<Map<String, dynamic>>> alts;
  final LessonV2Api api;
  final String header;
  final void Function(AnswerRecord) onRecord;
  final _Report onReport;
  final VoidCallback onFinished;
  final bool retry;
  const _QuestionFlow({required this.questions, required this.alts, required this.api, required this.header, required this.onRecord, required this.onReport, required this.onFinished, required this.retry});

  @override
  State<_QuestionFlow> createState() => _QuestionFlowState();
}

class _QuestionFlowState extends State<_QuestionFlow> {
  late final PracticeQueue _queue = PracticeQueue(widget.questions, alts: widget.retry ? widget.alts : const {});
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (_queue.isDone) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
  }

  void _done(bool correct, int ms) {
    _queue.answer(correct, ms: ms);
    widget.onRecord(_queue.records.last);
    if (_queue.isDone) {
      widget.onFinished();
    } else {
      setState(() => _tick++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _queue.current;
    if (q == null) return const SizedBox.shrink();
    final isMatch = q['kind'] == 'match_pairs';
    final key = ValueKey('${q['id']}_${_queue.attemptOfCurrent}_$_tick');
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(widget.header, style: const TextStyle(fontWeight: FontWeight.w800, color: kLessonDark)),
          const Spacer(),
          Text('${_queue.position + 1}/${_queue.total}', key: const Key('flow_progress'), style: const TextStyle(color: kLessonGrey)),
        ]),
        const SizedBox(height: 14),
        if (isMatch)
          MatchPairsCard(key: key, question: q, onDone: _done)
        else
          QuestionCard(
            key: key, question: q, api: widget.api, onDone: _done, isRetry: _queue.attemptOfCurrent > 1,
            reasonLabel: q['reason'] == 'wrong' ? 'Từ này bạn hay nhầm' : (q['reason'] == 'due' ? 'Đến lúc ôn lại từ này' : null),
            onReport: () => widget.onReport(q)),
      ]),
    );
  }
}

/// Tu moi theo cap: the 1, the 2, roi 1 cau hoi nhanh NGAY (nho chu dong).
class _NewWordsFlow extends StatefulWidget {
  final List<Map<String, dynamic>> pairs;
  final LessonV2Api api;
  final void Function(AnswerRecord) onRecord;
  final _Report onReport;
  final VoidCallback onFinished;
  const _NewWordsFlow({required this.pairs, required this.api, required this.onRecord, required this.onReport, required this.onFinished});

  @override
  State<_NewWordsFlow> createState() => _NewWordsFlowState();
}

class _NewWordsFlowState extends State<_NewWordsFlow> {
  int _pair = 0;
  int _card = 0; // 0..words-1 = the; words.length = cau hoi nhanh

  @override
  void initState() {
    super.initState();
    if (widget.pairs.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinished());
  }

  void _advance() {
    final words = (widget.pairs[_pair]['words'] as List);
    final micro = widget.pairs[_pair]['micro'];
    if (_card < words.length - 1) {
      setState(() => _card++);
    } else if (_card == words.length - 1 && micro != null) {
      setState(() => _card = words.length);
    } else {
      _nextPair();
    }
  }

  void _nextPair() {
    if (_pair + 1 < widget.pairs.length) {
      setState(() { _pair++; _card = 0; });
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) return const SizedBox.shrink();
    final pair = widget.pairs[_pair];
    final words = (pair['words'] as List).cast<Map<String, dynamic>>();
    final total = widget.pairs.length;
    if (_card >= words.length) {
      final q = (pair['micro'] as Map).cast<String, dynamic>();
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Kiểm tra nhanh · cặp ${_pair + 1}/$total', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          QuestionCard(
            key: ValueKey('micro_${q['id']}'), question: q, api: widget.api, onReport: () => widget.onReport(q),
            onDone: (ok, ms) {
              widget.onRecord(AnswerRecord(q['id'] as String, ok, 1, ms));
              _nextPair();
            }),
        ]),
      );
    }
    final w = words[_card];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Từ mới · cặp ${_pair + 1}/$total', style: const TextStyle(fontWeight: FontWeight.w800)),
      const Spacer(),
      Center(child: Text(w['text'] as String, key: const Key('word_text'), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: kLessonDark))),
      Center(child: Text(w['pron'] as String? ?? '', style: const TextStyle(fontSize: 18, color: kLessonGrey))),
      const SizedBox(height: 6),
      Center(child: Text(w['meaning'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kLessonPurple))),
      Center(child: IconButton(key: const Key('word_audio'), iconSize: 36, onPressed: () => widget.api.playAudio(w['audio'] as Map<String, dynamic>?), icon: const Icon(Icons.volume_up_rounded, color: kLessonPurple))),
      if ((w['example'] as String?)?.isNotEmpty == true) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(w['example'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => widget.api.playAudio(w['example_audio'] as Map<String, dynamic>?), icon: const Icon(Icons.volume_up_outlined, color: kLessonGrey)),
            ]),
            if ((w['example_vi'] as String?)?.isNotEmpty == true) Text(w['example_vi'] as String, style: const TextStyle(color: kLessonGrey)),
          ]),
        ),
      ],
      const Spacer(),
      ElevatedButton(
        key: const Key('word_next'),
        onPressed: _advance,
        style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('Tiếp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    ]);
  }
}

class _DialogueStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final void Function(AnswerRecord) onRecord;
  final _Report onReport;
  final VoidCallback onFinished;
  const _DialogueStep({required this.step, required this.api, required this.onRecord, required this.onReport, required this.onFinished});

  @override
  State<_DialogueStep> createState() => _DialogueStepState();
}

class _DialogueStepState extends State<_DialogueStep> {
  bool _pinyin = true;
  bool _vi = false;
  bool _questions = false;

  @override
  Widget build(BuildContext context) {
    final qs = (widget.step['questions'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (_questions && qs.isNotEmpty) {
      return _QuestionFlow(questions: qs, alts: const {}, api: widget.api, header: 'Hiểu hội thoại', onRecord: widget.onRecord, onReport: widget.onReport, onFinished: widget.onFinished, retry: false);
    }
    final lines = (widget.step['lines'] as List).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Hội thoại · ${widget.step['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
      Row(children: [
        FilterChip(label: const Text('Pinyin'), selected: _pinyin, onSelected: (v) => setState(() => _pinyin = v)),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Dịch'), selected: _vi, onSelected: (v) => setState(() => _vi = v)),
      ]),
      Expanded(
        child: ListView(children: [
          for (final l in lines)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['speaker'] ?? ''}  ${l['text']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  if (_pinyin && (l['pinyin'] as String?)?.isNotEmpty == true) Text(l['pinyin'] as String, style: const TextStyle(color: kLessonGrey)),
                  if (_vi && (l['vi'] as String?)?.isNotEmpty == true) Text(l['vi'] as String, style: const TextStyle(color: kLessonPurple)),
                ])),
                IconButton(onPressed: () => widget.api.playAudio(l['audio'] is Map ? Map<String, dynamic>.from(l['audio'] as Map) : {'text': l['text'], 'lang': l['lang'] ?? 'zh-TW'}), icon: const Icon(Icons.volume_up_outlined)),
              ]),
            ),
        ]),
      ),
      ElevatedButton(
        key: const Key('dialogue_next'),
        onPressed: () => qs.isEmpty ? widget.onFinished() : setState(() => _questions = true),
        style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        child: const Text('Tiếp'),
      ),
    ]);
  }
}

class _GrammarStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final void Function(AnswerRecord) onRecord;
  final _Report onReport;
  final VoidCallback onFinished;
  const _GrammarStep({required this.step, required this.api, required this.onRecord, required this.onReport, required this.onFinished});

  @override
  State<_GrammarStep> createState() => _GrammarStepState();
}

class _GrammarStepState extends State<_GrammarStep> {
  bool _practice = false;

  @override
  Widget build(BuildContext context) {
    final qs = (widget.step['questions'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (_practice && qs.isNotEmpty) {
      return _QuestionFlow(questions: qs, alts: const {}, api: widget.api, header: 'Làm thử mẫu câu', onRecord: widget.onRecord, onReport: widget.onReport, onFinished: widget.onFinished, retry: false);
    }
    final g = Map<String, dynamic>.from(widget.step['grammar'] as Map);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Mẫu câu', style: TextStyle(fontWeight: FontWeight.w800)),
      Expanded(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g['title'] as String? ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (g['formula'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(g['formula'] as String, style: const TextStyle(fontSize: 18, color: kLessonPurple, fontWeight: FontWeight.w700))),
              if (g['explanation'] != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(g['explanation'] as String)),
              for (final e in ((g['examples'] as List?) ?? const [])) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $e')),
              if (g['common_mistake'] != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('💡 ${g['common_mistake']}', style: const TextStyle(color: kLessonGrey))),
            ]),
          ),
        ),
      ),
      ElevatedButton(
        key: const Key('grammar_next'),
        onPressed: () => qs.isEmpty ? widget.onFinished() : setState(() => _practice = true),
        style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
        child: Text(qs.isEmpty ? 'Tiếp' : 'Làm thử'),
      ),
    ]);
  }
}

class _MinigameStep extends StatefulWidget {
  final Map<String, dynamic> step;
  final LessonV2Api api;
  final VoidCallback onDone;
  const _MinigameStep({required this.step, required this.api, required this.onDone});

  @override
  State<_MinigameStep> createState() => _MinigameStepState();
}

class _MinigameStepState extends State<_MinigameStep> {
  Map<String, dynamic>? _result;

  Future<void> _finish(int matched, int misses) async {
    try {
      final r = await widget.api.submitGame(matched, misses);
      if (mounted) setState(() => _result = r);
    } catch (_) {
      if (mounted) setState(() => _result = {'score': (matched * 10 - misses * 2).clamp(0, 99999), 'xp_gained': 0, 'best': null, 'is_new_best': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      final r = _result!;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('⚡ Hết giờ!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Điểm ${r['score']}${r['is_new_best'] == true ? '  🏅 Kỷ lục mới!' : ''}', key: const Key('match60_result'), style: const TextStyle(fontSize: 18)),
        if (r['best'] != null) Text('Cao nhất của bạn: ${r['best']}', style: const TextStyle(color: kLessonGrey)),
        if ((r['xp_gained'] as num? ?? 0) > 0) Text('+${r['xp_gained']} XP', style: const TextStyle(color: kLessonGreen, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        ElevatedButton(key: const Key('match60_continue'), onPressed: widget.onDone, style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white), child: const Text('Xem kết quả bài học')),
      ]);
    }
    return Match60Widget(pool: (widget.step['pairs'] as List).cast<Map<String, dynamic>>(), onFinish: _finish, onSkip: widget.onDone, durationSeconds: (widget.step['duration'] as num?)?.toInt() ?? 60);
  }
}
