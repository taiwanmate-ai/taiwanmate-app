import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';

const kLessonPurple = Color(0xFF5B5FEF);
const kLessonGreen = Color(0xFF00C853);
const kLessonRed = Color(0xFFE53935);
const kLessonDark = Color(0xFF1A1D2E);
const kLessonGrey = Color(0xFF8A8FA3);

/// 1 cau hoi trac nghiem (nghe-chon-nghia, nghia-chon-chu, nghe-chon-chu, hoi nhanh, dien cho trong, hieu hoi thoai, chon cau ngu phap).
/// Tu quan ly trang thai "da chon" + loi giai thich; goi [onDone] khi nguoi hoc bam "Tiep". Khong goi mang (chi phat audio qua [api]).
class QuestionCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final LessonV2Api api;
  final void Function(bool correct, int ms) onDone;
  final VoidCallback? onReport;
  final String? reasonLabel; // vd "Bạn hay nhầm từ này"
  final bool isRetry;

  const QuestionCard({super.key, required this.question, required this.api, required this.onDone, this.onReport, this.reasonLabel, this.isRetry = false});

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  String? _chosen;
  final _started = DateTime.now();

  Map<String, dynamic> get _p => Map<String, dynamic>.from(widget.question['payload'] as Map);
  Map<String, dynamic> get _stem => Map<String, dynamic>.from(_p['stem'] as Map);
  List<Map<String, dynamic>> get _options => (_p['options'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  bool get _answered => _chosen != null;
  bool get _correct => _chosen == _p['answer'];

  @override
  void initState() {
    super.initState();
    if (_stem['type'] == 'audio') {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.api.playAudio(_stem));
    }
  }

  void _choose(String id) {
    if (_answered) return;
    setState(() => _chosen = id);
    _correct ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
  }

  Color _tileColor(String id) {
    if (!_answered) return Colors.white;
    if (id == _p['answer']) return const Color(0xFFE8F8EE);
    if (id == _chosen) return const Color(0xFFFFEBEE);
    return Colors.white;
  }

  Color _borderColor(String id) {
    if (!_answered) return const Color(0xFFE0E3F0);
    if (id == _p['answer']) return kLessonGreen;
    if (id == _chosen) return kLessonRed;
    return const Color(0xFFE0E3F0);
  }

  @override
  Widget build(BuildContext context) {
    final stem = _stem;
    final type = stem['type'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.reasonLabel != null)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(widget.reasonLabel!, style: const TextStyle(color: kLessonGrey, fontSize: 12))),
      if (widget.isRetry)
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Làm lại câu đã sai — thử cách khác nhé', style: TextStyle(color: kLessonPurple, fontSize: 12, fontWeight: FontWeight.w600))),
      Text(_p['prompt'] as String? ?? '', style: const TextStyle(color: kLessonGrey, fontSize: 13)),
      const SizedBox(height: 12),
      if (type == 'audio')
        Center(
          child: InkWell(
            key: const Key('lesson_audio_btn'),
            onTap: () => widget.api.playAudio(stem),
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: kLessonPurple, shape: BoxShape.circle),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 38),
            ),
          ),
        )
      else
        Center(child: Text(stem['text'] as String? ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: type == 'sentence' ? 24 : 28, fontWeight: FontWeight.w800, color: kLessonDark))),
      if (stem['translation'] != null && (stem['translation'] as String).isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 8), child: Center(child: Text(stem['translation'] as String, textAlign: TextAlign.center, style: const TextStyle(color: kLessonGrey, fontSize: 14)))),
      const SizedBox(height: 18),
      for (final o in _options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            key: Key('lesson_opt_${o['id']}'),
            onTap: () => _choose(o['id'] as String),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: _tileColor(o['id'] as String), borderRadius: BorderRadius.circular(14), border: Border.all(color: _borderColor(o['id'] as String), width: 1.6)),
              child: Row(children: [
                Expanded(child: Text(o['text'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kLessonDark))),
                if (o['sub'] != null && (o['sub'] as String).isNotEmpty) Text(o['sub'] as String, style: const TextStyle(color: kLessonGrey, fontSize: 13)),
              ]),
            ),
          ),
        ),
      if (_answered) _feedback(),
    ]);
  }

  Widget _feedback() {
    final ok = _correct;
    return Container(
      key: const Key('lesson_feedback'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ok ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ok ? '✔ Chính xác!' : '✗ Chưa đúng', style: TextStyle(fontWeight: FontWeight.w800, color: ok ? kLessonGreen : kLessonRed, fontSize: 16)),
        if ((_p['explain'] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_p['explain'] as String, style: const TextStyle(color: kLessonDark))),
        if (!ok) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Câu này sẽ quay lại sau ít câu nữa.', style: TextStyle(color: kLessonGrey, fontSize: 12))),
        const SizedBox(height: 10),
        Row(children: [
          if (widget.onReport != null)
            TextButton.icon(
              key: const Key('lesson_report_btn'),
              onPressed: widget.onReport,
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Báo lỗi câu này', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: kLessonGrey),
            ),
          const Spacer(),
          ElevatedButton(
            key: const Key('lesson_next_btn'),
            onPressed: () => widget.onDone(_correct, DateTime.now().difference(_started).inMilliseconds),
            style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Tiếp'),
          ),
        ]),
      ]),
    );
  }
}
