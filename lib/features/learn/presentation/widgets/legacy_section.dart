import 'package:flutter/material.dart';

/// "Bài luyện thêm (giáo trình cũ)" (CTO 31/10): bài A1 cũ KHÔNG nằm trong lộ trình chính, không là "bài kế tiếp".
/// Thu gọn mặc định; mở ra là danh sách nhóm 10 bài ("Bài 1–10"...). Server (`layout=v2`) trả `legacy_units` đã mở hết, giữ nguyên tiến độ.
class LegacySection extends StatelessWidget {
  final List<Map<String, dynamic>> units;
  final int completed;
  final Widget Function(Map<String, dynamic> unit) tileBuilder;
  const LegacySection({super.key, required this.units, required this.completed, required this.tileBuilder});

  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) return const SizedBox.shrink();
    final sorted = [...units]..sort((a, b) => ((a['unit_order'] as num?) ?? 0).compareTo((b['unit_order'] as num?) ?? 0));
    final groups = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < sorted.length; i += 10) {
      groups.add(sorted.sublist(i, i + 10 > sorted.length ? sorted.length : i + 10));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('legacy_section'),
            initiallyExpanded: false,
            leading: const Icon(Icons.library_books_outlined, color: Color(0xFF8A8FA3)),
            title: const Text('Bài luyện thêm (giáo trình cũ)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1D2E))),
            subtitle: Text('Đã học $completed/${units.length} bài · không bắt buộc',
                key: const Key('legacy_section_count'), style: const TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text('Bài ${g.first['unit_order']}–${g.last['unit_order']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8A8FA3))),
                ),
                for (final u in g) tileBuilder(u),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng "Đã học N bài giáo trình cũ" cạnh thanh tiến độ (CTO 31/10: N > 0 thì BẮT BUỘC hiện, không để công sức mất trắng).
Widget legacyDoneLine(int n, {Key? key}) => n > 0
    ? Text('Đã học $n bài giáo trình cũ',
        key: key ?? const Key('legacy_done_line'), style: const TextStyle(fontSize: 11, color: Color(0xFF00897B), fontWeight: FontWeight.w700))
    : const SizedBox.shrink();
