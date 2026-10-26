/// Danh so bai tinh huong — GIONG HET server (app/services/situation_feature.py): chang s, vi tri p (0-based) -> unit_order = -1000 + 20*s + p
/// (Chang 0 P1 = -1000, Chang 1 bai 1 = -980, Chang 2 bai 1 = -960…). Danh so CU (P1 = -14 … bai 10 = 0) van hieu dung cho toi khi server chay migration.
const int kNewBase = -1000;
const int kStageStride = 20;
const int kLegacyMinOrder = -14;

/// Bai tinh huong -> (chang, vi tri 0-based); bai A1 cu (unit_order >= 1) -> null.
(int, int)? newStagePos(int order) {
  if (order > 0) return null;
  if (order >= kLegacyMinOrder) return order <= -10 ? (0, order - kLegacyMinOrder) : (1, order + 9);
  final r = order - kNewBase;
  return (r ~/ kStageStride, r % kStageStride);
}

/// Bai phat am (Chang 0, P1…P5).
bool isPronOrder(int order) => newStagePos(order)?.$1 == 0;

/// Nhan so bai hien cho nguoi hoc: bai tinh huong -> "P1…P5" (phat am) / "bai 1…10" (dem trong chang); bai A1 cu giu so cu.
String unitNumberLabel(int order) {
  final sp = newStagePos(order);
  if (sp == null) return 'bài $order';
  return sp.$1 == 0 ? 'P${sp.$2 + 1}' : 'bài ${sp.$2 + 1}';
}

/// Bai ke tiep = bai co unit_order LON HON gan nhat (danh so bai moi co khoang trong giua cac chang) — giong server (curriculum.mark_unit_completed).
Map<String, dynamic>? nextUnitAfter(List<Map<String, dynamic>> units, int order) {
  Map<String, dynamic>? best;
  for (final u in units) {
    final o = (u['unit_order'] as num?)?.toInt();
    if (o == null || o <= order) continue;
    if (best == null || o < (best['unit_order'] as num).toInt()) best = u;
  }
  return best;
}
