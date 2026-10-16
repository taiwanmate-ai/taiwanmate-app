import 'package:flutter/material.dart';

/// Chia danh sach bai cua 1 cap thanh "chang" ~10 bai (client tinh tu `unit_order`, khong doi DB/server). Bai moi duoc them o CUOI cap nen
/// ranh gioi chang cua bai cu khong doi. Cap it bai (<= [kFlatLimit]) hien danh sach phang nhu cu.
const int kStageSize = 10;
const int kFlatLimit = 12;

class StageInfo {
  final int index; // 1-based
  final List<Map<String, dynamic>> units;
  StageInfo(this.index, this.units);

  int get total => units.length;
  int get completed => units.where((u) => u['status'] == 'completed').length;
  bool get isDone => total > 0 && completed == total;
  bool get hasPlayable => units.any((u) => u['status'] == 'unlocked');
  int get firstOrder => (units.first['unit_order'] as num).toInt();
  int get lastOrder => (units.last['unit_order'] as num).toInt();

  /// 2-3 chu de noi bat cua chang (bo so thu tu "Am thuc 2" -> "Am thuc"), theo thu tu xuat hien.
  List<String> get topics {
    final seen = <String>[];
    for (final u in units) {
      final t = ((u['topic_vi'] as String?) ?? '').replaceAll(RegExp(r'\s+\d+$'), '').trim();
      if (t.isNotEmpty && !seen.contains(t)) seen.add(t);
      if (seen.length == 3) break;
    }
    return seen;
  }
}

List<StageInfo> groupIntoStages(List<Map<String, dynamic>> units, {int size = kStageSize}) {
  final sorted = [...units]..sort((a, b) => ((a['unit_order'] as num?) ?? 0).compareTo((b['unit_order'] as num?) ?? 0));
  final byStage = <int, List<Map<String, dynamic>>>{};
  for (final u in sorted) {
    final order = ((u['unit_order'] as num?) ?? 1).toInt();
    byStage.putIfAbsent(((order - 1) ~/ size) + 1, () => []).add(u);
  }
  final keys = byStage.keys.toList()..sort();
  return [for (final k in keys) StageInfo(k, byStage[k]!)];
}

/// Bai dang hoc: bai 'unlocked' co unit_order nho nhat (chua hoan thanh); khong co -> null.
Map<String, dynamic>? currentUnit(List<Map<String, dynamic>> units) {
  Map<String, dynamic>? best;
  for (final u in units) {
    if (u['status'] != 'unlocked') continue;
    if (best == null || ((u['unit_order'] as num).toInt() < (best['unit_order'] as num).toInt())) best = u;
  }
  return best;
}

/// Chang dang hoc (chua xong va co bai mo); khong co -> chang cuoi.
int currentStageIndex(List<StageInfo> stages) {
  for (var i = 0; i < stages.length; i++) {
    if (!stages[i].isDone && stages[i].hasPlayable) return i;
  }
  return stages.isEmpty ? 0 : stages.length - 1;
}

const _teal = Color(0xFF00BFA5);
const _green = Color(0xFF00C853);
const _dark = Color(0xFF1A1D2E);
const _grey = Color(0xFF8A8FA3);

/// Danh sach bai theo chang: nut "Tiep tuc", moi chang co thanh tien do + chu de noi bat; chi chang dang hoc mo san, cham tieu de de mo/dong.
/// [tileBuilder] ve 1 bai (giu nguyen giao dien the bai hien co).
class StageUnitList extends StatefulWidget {
  final List<Map<String, dynamic>> units;
  final void Function(Map<String, dynamic> unit) onOpen;
  final Widget Function(Map<String, dynamic> unit) tileBuilder;
  const StageUnitList({super.key, required this.units, required this.onOpen, required this.tileBuilder});

  @override
  State<StageUnitList> createState() => _StageUnitListState();
}

class _StageUnitListState extends State<StageUnitList> {
  late List<StageInfo> _stages;
  final Set<int> _open = {};

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void didUpdateWidget(StageUnitList old) {
    super.didUpdateWidget(old);
    if (old.units != widget.units) _recompute();
  }

  void _recompute() {
    _stages = groupIntoStages(widget.units);
    _open
      ..clear()
      ..add(_stages.isEmpty ? 0 : _stages[currentStageIndex(_stages)].index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.units.length <= kFlatLimit) {
      return Column(children: [for (final u in widget.units) widget.tileBuilder(u)]);
    }
    final cur = currentUnit(widget.units);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cur != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ElevatedButton.icon(
            key: const Key('stage_continue'),
            onPressed: () => widget.onOpen(cur),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text('Tiếp tục: ${cur['topic_vi']} (bài ${cur['unit_order']})', overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      for (final st in _stages) ...[
        _header(st),
        if (_open.contains(st.index)) ...[
          const SizedBox(height: 8),
          for (final u in st.units) widget.tileBuilder(u),
        ],
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _header(StageInfo st) {
    final isOpen = _open.contains(st.index);
    final isCurrent = _stages.isNotEmpty && _stages[currentStageIndex(_stages)].index == st.index;
    final reached = st.isDone || st.hasPlayable || st.completed > 0;
    return InkWell(
      key: Key('stage_header_${st.index}'),
      onTap: () => setState(() => isOpen ? _open.remove(st.index) : _open.add(st.index)),
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: reached ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isCurrent ? _teal : Colors.grey.shade200, width: isCurrent ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(st.isDone ? Icons.check_circle_rounded : (isCurrent ? Icons.radio_button_checked : Icons.lock_outline_rounded),
                color: st.isDone ? _green : (isCurrent ? _teal : _grey), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Chặng ${st.index} · bài ${st.firstOrder}–${st.lastOrder}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _dark)),
                if (st.topics.isNotEmpty) Text(st.topics.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _grey)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: st.total == 0 ? 0 : st.completed / st.total, minHeight: 5, backgroundColor: _teal.withOpacity(0.12), valueColor: AlwaysStoppedAnimation(st.isDone ? _green : _teal)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Text('${st.completed}/${st.total}', key: Key('stage_count_${st.index}'), style: const TextStyle(fontWeight: FontWeight.w700, color: _dark)),
            Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _grey),
          ]),
        ),
      ),
    );
  }
}
