import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';

/// Cau hoi "sap xep tu thanh cau" (kind = arrange_sentence): hien ban dich tieng Viet, nguoi hoc cham lan luot cac manh de ghep thanh cau.
/// Dap an dung = cau goc (server chi gui thu tu goc + `accepts`: moi chuoi duoc chap nhan). Khong goi mang.
class ArrangeCard extends StatefulWidget {
  final Map<String, dynamic> question;
  final void Function(bool correct, int ms) onDone;
  final VoidCallback? onReport;
  final bool isRetry;

  const ArrangeCard({super.key, required this.question, required this.onDone, this.onReport, this.isRetry = false});

  @override
  State<ArrangeCard> createState() => _ArrangeCardState();
}

class _ArrangeCardState extends State<ArrangeCard> {
  final _started = DateTime.now();
  final List<String> _placed = []; // id manh da dat theo thu tu
  bool _checked = false;
  bool _correct = false;

  Map<String, dynamic> get _p => Map<String, dynamic>.from(widget.question['payload'] as Map);
  List<Map<String, dynamic>> get _pieces => (_p['pieces'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  String get _sep => (_p['sep'] as String?) ?? '';
  String get _suffix => (_p['suffix'] as String?) ?? '';

  String _textOf(String id) => _pieces.firstWhere((x) => x['id'] == id)['text'] as String;

  String get _built => _placed.map(_textOf).join(_sep);

  void _tap(String id) {
    if (_checked) return;
    setState(() => _placed.contains(id) ? _placed.remove(id) : _placed.add(id));
  }

  void _check() {
    final accepts = ((_p['accepts'] as List?) ?? [_p['answer_text']]).map((e) => e.toString()).toList();
    final ok = accepts.contains(_built);
    setState(() {
      _checked = true;
      _correct = ok;
    });
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
  }

  Widget _chip(Map<String, dynamic> piece, {required bool placed}) {
    final id = piece['id'] as String;
    final sub = (piece['sub'] as String?) ?? '';
    return InkWell(
      key: Key(placed ? 'arrange_placed_$id' : 'arrange_piece_$id'),
      onTap: () => _tap(id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: placed ? const Color(0xFFEDEBFF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: placed ? kLessonPurple : const Color(0xFFE0E3F0), width: 1.6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(piece['text'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kLessonDark)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 11, color: kLessonGrey)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final x in _pieces) x['id'] as String: x};
    final remaining = _pieces.where((x) => !_placed.contains(x['id'])).toList();
    final stem = Map<String, dynamic>.from(_p['stem'] as Map);
    final explain = (_p['explain'] as String?) ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.isRetry)
        const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Làm lại câu đã sai — thử cách khác nhé', style: TextStyle(color: kLessonPurple, fontSize: 12, fontWeight: FontWeight.w600))),
      Text(_p['prompt'] as String? ?? 'Sắp xếp các từ thành câu', style: const TextStyle(color: kLessonGrey, fontSize: 13)),
      const SizedBox(height: 10),
      Center(child: Text(stem['text'] as String? ?? '', key: const Key('arrange_stem'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLessonDark))),
      const SizedBox(height: 16),
      Container(
        key: const Key('arrange_answer_area'),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _checked ? (_correct ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE)) : const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _checked ? (_correct ? kLessonGreen : kLessonRed) : const Color(0xFFE0E3F0), width: 1.6),
        ),
        child: _placed.isEmpty
            ? const Text('Chạm các từ bên dưới theo đúng thứ tự', style: TextStyle(color: kLessonGrey))
            : Wrap(spacing: 8, runSpacing: 8, children: [for (final id in _placed) _chip(byId[id]!, placed: true), if (_suffix.isNotEmpty) Text(_suffix, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [for (final x in remaining) _chip(x, placed: false)]),
      const SizedBox(height: 18),
      if (!_checked)
        ElevatedButton(
          key: const Key('arrange_check_btn'),
          onPressed: _placed.length == _pieces.length ? _check : null,
          style: ElevatedButton.styleFrom(backgroundColor: kLessonPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Kiểm tra'),
        )
      else
        Container(
          key: const Key('lesson_feedback'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _correct ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_correct ? '✔ Chính xác!' : '✗ Chưa đúng', style: TextStyle(fontWeight: FontWeight.w800, color: _correct ? kLessonGreen : kLessonRed, fontSize: 16)),
            if (explain.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(explain, style: const TextStyle(color: kLessonDark))),
            if (!_correct) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Câu này sẽ quay lại sau ít câu nữa.', style: TextStyle(color: kLessonGrey, fontSize: 12))),
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
        ),
    ]);
  }
}
