import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/stage_unit_list.dart';

List<Map<String, dynamic>> makeUnits(int n, {int completed = 0, List<String>? topics}) => [
      for (var i = 1; i <= n; i++)
        {
          'unit_id': 'u$i',
          'unit_order': i,
          'topic_vi': topics != null ? topics[(i - 1) % topics.length] + (i > topics.length ? ' ${(i - 1) ~/ topics.length + 1}' : '') : 'Bài $i',
          'status': i <= completed ? 'completed' : (i == completed + 1 ? 'unlocked' : 'locked'),
        }
    ];

void main() {
  group('groupIntoStages', () {
    test('chia 57 bai thanh 6 chang ~10 bai, chang cuoi 7 bai', () {
      final st = groupIntoStages(makeUnits(57));
      expect(st.map((s) => s.total).toList(), [10, 10, 10, 10, 10, 7]);
      expect(st.first.firstOrder, 1);
      expect(st.last.firstOrder, 51);
      expect(st.last.lastOrder, 57);
    });

    test('bai moi them o cuoi KHONG doi ranh gioi chang cua bai cu', () {
      final before = groupIntoStages(makeUnits(12));
      final after = groupIntoStages(makeUnits(60));
      expect(after[0].units.map((u) => u['unit_id']), before[0].units.map((u) => u['unit_id']));       // chang 1 y nguyen
      expect(after[1].units.first['unit_id'], 'u11');                                                  // chang 2 bat dau bai 11 (bai cu 11-12 + bai moi)
      expect(before[1].units.length, 2);
    });

    test('sap theo unit_order du server tra lan xon; tien do, chu de noi bat bo so thu tu', () {
      final units = makeUnits(25, completed: 10, topics: ['Ẩm thực', 'Du lịch', 'Quần áo', 'Tài chính']).reversed.toList();
      final st = groupIntoStages(units);
      expect(st.first.units.first['unit_order'], 1);
      expect(st[0].isDone, true);
      expect(st[1].completed, 0);
      expect(st[1].topics, ['Quần áo', 'Tài chính', 'Ẩm thực']);              // bo so thu tu ("Quần áo 3" -> "Quần áo"), khong lap
      expect(currentStageIndex(st), 1);                                       // chang 1 xong, chang 2 co bai mo
      expect(currentUnit(units)!['unit_id'], 'u11');
    });

    test('khong co bai mo: chang hien tai = chang cuoi; khong co bai dang hoc', () {
      final all = makeUnits(30, completed: 30);
      expect(currentUnit(all), isNull);
      expect(currentStageIndex(groupIntoStages(all)), 2);
      expect(currentStageIndex([]), 0);
    });
  });

  group('StageUnitList', () {
    Future<List<String>> pump(WidgetTester tester, List<Map<String, dynamic>> units, {List<String>? opened}) async {
      final opens = opened ?? <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StageUnitList(
              units: units,
              onOpen: (u) => opens.add(u['unit_id'] as String),
              tileBuilder: (u) => ListTile(key: Key('tile_${u['unit_id']}'), title: Text(u['topic_vi'] as String), onTap: () => opens.add(u['unit_id'] as String)),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return opens;
    }

    testWidgets('cap it bai (<=12): danh sach phang nhu cu, khong co chang', (tester) async {
      await pump(tester, makeUnits(12));
      expect(find.byKey(const Key('stage_header_1')), findsNothing);
      expect(find.byKey(const Key('stage_continue')), findsNothing);
      expect(find.byType(ListTile), findsNWidgets(12));
    });

    testWidgets('nhieu bai: chi chang dang hoc mo san; cham tieu de de mo/dong; chi dung ~10 the', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, makeUnits(57, completed: 12));
      expect(find.byKey(const Key('stage_header_1')), findsOneWidget);
      expect(find.byKey(const Key('stage_header_6')), findsOneWidget);
      expect(find.text('Chặng 2 · bài 11–20'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(10));                       // chi chang 2 (bai 11-20) mo
      expect(find.byKey(const Key('tile_u15')), findsOneWidget);
      expect(find.byKey(const Key('tile_u1')), findsNothing);
      expect(find.byKey(const Key('stage_count_1')), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);                              // chang 1 xong
      expect(find.text('2/10'), findsOneWidget);                               // chang 2: bai 11, 12 xong
      await tester.tap(find.byKey(const Key('stage_header_1')));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(20));
      await tester.tap(find.byKey(const Key('stage_header_2')));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(10));
      expect(find.byKey(const Key('tile_u1')), findsOneWidget);
    });

    testWidgets('nut Tiep tuc mo dung bai dang hoc', (tester) async {
      final opens = <String>[];
      await pump(tester, makeUnits(40, completed: 13), opened: opens);
      expect(find.text('Tiếp tục: Bài 14 (bài 14)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('stage_continue')));
      expect(opens, ['u14']);
    });

    testWidgets('khong co bai mo (hoc het): khong hien nut Tiep tuc, mo chang cuoi', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, makeUnits(25, completed: 25));
      expect(find.byKey(const Key('stage_continue')), findsNothing);
      expect(find.byKey(const Key('tile_u25')), findsOneWidget);
      expect(find.byKey(const Key('tile_u1')), findsNothing);
    });

    testWidgets('cap nhat danh sach (hoan thanh them bai) -> chang hien tai tinh lai', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      Widget host(List<Map<String, dynamic>> units) => MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: StageUnitList(key: key, units: units, onOpen: (_) {}, tileBuilder: (u) => ListTile(key: Key('tile_${u['unit_id']}'), title: Text(u['topic_vi'] as String))))),
          );
      await tester.pumpWidget(host(makeUnits(30, completed: 9)));
      expect(find.byKey(const Key('tile_u9')), findsOneWidget);
      await tester.pumpWidget(host(makeUnits(30, completed: 10)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tile_u11')), findsOneWidget);               // da sang chang 2
      expect(find.byKey(const Key('tile_u9')), findsNothing);
    });
  });
}
