// A2 dung chang 7..11 trong unit_order (CTO 02/11) nhung hien "Chặng 1..": server tra `stage_no`; app nhom theo `stage`, hien `stage_no`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/stage_unit_list.dart';
import 'package:chinesemate/features/lesson_v2/situation/next_stage_card.dart';

Map<String, dynamic> _u(String id, int order, int stage, int? no, String status) => {
      'unit_id': id, 'level': 'A2', 'unit_order': order, 'topic_vi': 'Bài $id', 'status': status, 'stage': stage,
      if (no != null) 'stage_no': no, 'stage_title': stage == 7 ? 'Cuộc sống ổn định' : 'Đi làm',
    };

void main() {
  test('nhom theo stage, so hien = stage_no; thieu stage_no thi dung stage (server cu / A1)', () {
    final st = groupIntoStages([_u('a', -860, 7, 1, 'unlocked'), _u('b', -859, 7, 1, 'locked'), _u('c', -840, 8, 2, 'locked'), _u('d', -980, 1, null, 'completed')]);
    expect([for (final s in st) s.index], [1, 7, 8]);
    expect([for (final s in st) s.shown], [1, 1, 2]);
  });

  testWidgets('tieu de chang A2 hien "Chặng 1 · …" (khong phai "Chặng 7")', (tester) async {
    final units = [for (var i = 0; i < 9; i++) _u('a$i', -860 + i, 7, 1, i == 0 ? 'unlocked' : 'locked'), for (var i = 0; i < 9; i++) _u('b$i', -840 + i, 8, 2, 'locked')];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: StageUnitList(units: units, onOpen: (_) {}, tileBuilder: (u) => Text(u['topic_vi'] as String))))));
    await tester.pumpAndSettle();
    expect(find.text('Chặng 1 · Cuộc sống ổn định'), findsOneWidget);
    expect(find.text('Chặng 2 · Đi làm'), findsOneWidget);
    expect(find.textContaining('Chặng 7'), findsNothing);
  });

  testWidgets('the chang tiep theo dung stage_no', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: NextStageCard(nextStage: {'after_unit_id': 'x', 'next': 'stage', 'stage': 9, 'stage_no': 3, 'launch_date': null}))));
    expect(find.text('Chặng 3 đang được soạn và sẽ ra mắt sớm.'), findsOneWidget);
  });
}
