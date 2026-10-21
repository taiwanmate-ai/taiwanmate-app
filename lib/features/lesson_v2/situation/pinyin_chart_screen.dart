import 'package:flutter/material.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/question_card.dart';
import 'package:chinesemate/features/lesson_v2/situation/tone_text.dart';

/// Ô của bảng pinyin: (phụ âm, vần) -> ô. Ô KHÔNG có audio.url (hoặc playable=false) hiện MỜ và KHÔNG phát.
bool cellPlayable(Map<String, dynamic> cell) {
  final a = cell['audio'];
  return cell['playable'] != false && a is Map && (a['url'] as String?)?.isNotEmpty == true;
}

Map<String, Map<String, Map<String, dynamic>>> indexCells(List<dynamic> cells) {
  final out = <String, Map<String, Map<String, dynamic>>>{};
  for (final c in cells) {
    final m = Map<String, dynamic>.from(c as Map);
    out.putIfAbsent(m['row'] as String? ?? '', () => {})[m['final'] as String] = m;
  }
  return out;
}

/// Bảng pinyin tra cứu (phụ âm × vần, ~386 ô). Mở từ tab Học bất cứ lúc nào, không cần mở khoá. Bấm ô nghe âm thanh đã duyệt.
class PinyinChartScreen extends StatefulWidget {
  final LessonV2Api api;
  const PinyinChartScreen({super.key, required this.api});

  @override
  State<PinyinChartScreen> createState() => _PinyinChartScreenState();
}

class _PinyinChartScreenState extends State<PinyinChartScreen> {
  Map<String, dynamic>? _chart;
  String? _error;
  String? _playing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = null; _chart = null; });
    try {
      final a = widget.api;
      if (a is! SituationApi) throw StateError('no situation api');
      final c = await (a as SituationApi).fetchPinyinChart();
      if (mounted) setState(() => _chart = c);
    } catch (_) {
      if (mounted) setState(() => _error = 'Bảng pinyin chưa sẵn sàng. Thử lại sau nhé.');
    }
  }

  Future<void> _tap(Map<String, dynamic> cell) async {
    if (!cellPlayable(cell)) return;
    setState(() => _playing = cell['key'] as String?);
    await widget.api.playAudio(Map<String, dynamic>.from(cell['audio'] as Map));
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: kLessonDark, title: const Text('Bảng pinyin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 10), ElevatedButton(onPressed: _load, child: const Text('Thử lại'))]))
          : _chart == null
              ? const Center(child: CircularProgressIndicator())
              : _table(),
    );
  }

  Widget _table() {
    final rows = (_chart!['rows'] as List).cast<String>();
    final finals = (_chart!['finals'] as List).cast<String>();
    final cells = indexCells(_chart!['cells'] as List);
    final usedFinals = [for (final f in finals) if (cells.values.any((m) => m.containsKey(f))) f];
    final usedRows = [for (final r in rows) if (cells.containsKey(r)) r];
    const w = 64.0;
    Widget head(String t) => Container(width: w, height: 34, alignment: Alignment.center, color: const Color(0xFFEDEEFF), child: Text(t.isEmpty ? '∅' : t, style: const TextStyle(fontWeight: FontWeight.w800, color: kLessonPurple)));
    return Column(children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('Bấm một ô để nghe. Ô mờ là chưa có âm thanh. Hàng = phụ âm (y/w/∅ là âm viết thay), cột = vần.', style: TextStyle(color: kLessonGrey, fontSize: 12)),
      ),
      Expanded(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              key: const Key('pinyin_table'),
              defaultColumnWidth: const FixedColumnWidth(w),
              border: TableBorder.all(color: const Color(0xFFE0E3F0), width: 0.5),
              children: [
                TableRow(children: [head(''), for (final f in usedFinals) head(f)]),
                for (final r in usedRows)
                  TableRow(children: [
                    head(r),
                    for (final f in usedFinals) _cell(cells[r]?[f], w),
                  ]),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _cell(Map<String, dynamic>? c, double w) {
    if (c == null) return SizedBox(height: 46, width: w);
    final ok = cellPlayable(c);
    return InkWell(
      key: Key('cell_${c['key']}'),
      onTap: ok ? () => _tap(c) : null,
      child: Opacity(
        opacity: ok ? 1 : 0.3,
        child: Container(
          height: 46,
          color: _playing == c['key'] ? const Color(0xFFEDEEFF) : Colors.white,
          alignment: Alignment.center,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            PinyinText('${c['spelling']}', fontSize: 14, align: TextAlign.center),
            Text('${c['hanzi']}', style: const TextStyle(fontSize: 11, color: kLessonGrey)),
          ]),
        ),
      ),
    );
  }
}
