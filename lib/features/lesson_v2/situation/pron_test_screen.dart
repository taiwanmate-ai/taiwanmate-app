import 'package:flutter/material.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';

/// Đạt khi đúng >= 8/10 (khớp server: pron_session.passed).
bool pronTestPassed(int correct, int total) => total >= 10 && correct / total >= 0.8;

/// Bài kiểm tra bỏ qua Chặng 0: 10 câu cố định (2 câu/bài P1–P5). Đạt -> server đánh dấu P1–P5 xong và mở bài 1. Pop true khi đạt (để làm mới danh sách bài).
class PronTestScreen extends StatefulWidget {
  final LessonV2Api api;
  const PronTestScreen({super.key, required this.api});

  @override
  State<PronTestScreen> createState() => _PronTestScreenState();
}

class _PronTestScreenState extends State<PronTestScreen> {
  List<Map<String, dynamic>>? _qs;
  String? _error;
  int _i = 0;
  int _correct = 0;
  Map<String, dynamic>? _result;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; _qs = null; _i = 0; _correct = 0; _result = null; });
    try {
      final a = widget.api;
      if (a is! SituationApi) throw StateError('no situation api');
      final t = await (a as SituationApi).fetchPronTest();
      final qs = (t['questions'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      if (qs.isEmpty) {
        setState(() => _error = 'Bài kiểm tra chưa sẵn sàng.');
      } else {
        setState(() => _qs = qs);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Bài kiểm tra chưa sẵn sàng. Thử lại sau nhé.');
    }
  }

  Future<void> _answered(bool ok) async {
    if (ok) _correct++;
    if (_i + 1 < _qs!.length) {
      setState(() => _i++);
      return;
    }
    setState(() => _sending = true);
    try {
      final r = await (widget.api as SituationApi).submitPronTest(_correct, _qs!.length);
      if (mounted) setState(() { _result = r; _sending = false; });
    } catch (_) {
      if (mounted) setState(() { _result = {'passed': pronTestPassed(_correct, _qs!.length), 'offline': true}; _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: kLessonDark, title: const Text('Kiểm tra nhanh phát âm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: _body())),
    );
  }

  Widget _body() {
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Thử lại'))]));
    if (_qs == null || _sending) return const Center(child: CircularProgressIndicator());
    if (_result != null) {
      final passed = _result!['passed'] == true;
      return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Text(passed ? '🎉 Đạt!' : 'Chưa đạt', key: const Key('pron_test_title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
        const SizedBox(height: 8),
        Center(child: Text('Đúng $_correct/${_qs!.length} câu (cần ≥ 8/10)', key: const Key('pron_test_score'))),
        const SizedBox(height: 8),
        Center(child: Text(passed ? 'Chặng 0 đã được bỏ qua — bài 1 đã mở.' : 'Bạn nên học Chặng 0 (5 bài ngắn) để nắm chắc phát âm.', textAlign: TextAlign.center, style: const TextStyle(color: kLessonGrey))),
        const SizedBox(height: 20),
        ElevatedButton(
          key: const Key('pron_test_done'),
          onPressed: () => Navigator.pop(context, passed),
          style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(passed ? 'Về danh sách bài' : 'Học Chặng 0', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
      ]);
    }
    final q = _qs![_i];
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Câu ${_i + 1}/${_qs!.length}', key: const Key('pron_test_progress'), style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        QuestionCard(key: ValueKey('pt_${q['id']}'), question: q, api: widget.api, onDone: (ok, ms) => _answered(ok)),
      ]),
    );
  }
}
