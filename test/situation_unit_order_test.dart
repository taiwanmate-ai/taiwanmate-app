// Danh so bai tinh huong theo chang (giong server situation_feature.py): hieu ca danh so cu (-14…0) va moi (-1000 + 20*chang + vi tri),
// bai ke tiep = unit_order lon hon gan nhat (co khoang trong giua chang). Widget: hoc xong bai cuoi Chang 1 -> mo bai 1 Chang 2.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_screen.dart';
import 'package:chinesemate/features/lesson_v2/situation/unit_order.dart';

import 'situation_r3_test.dart' show SitApi;

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> routes;
  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final key = routes.keys.firstWhere((k) => o.path.endsWith(k), orElse: () => '');
    if (key.isEmpty) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromString(jsonEncode(routes[key]), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> _u(String id, int order, String topic, int stage, String title, String status) => {
      'unit_id': id, 'level': 'A1', 'unit_order': order, 'topic_vi': topic, 'topic_translated': '', 'status': status,
      'estimated_minutes': 6, 'is_vip_locked': false, 'stage': stage, 'stage_title': title,
    };

void main() {
  group('danh so (giong server)', () {
    test('danh so moi: chang + vi tri + nhan', () {
      expect(newStagePos(-1000), (0, 0));
      expect(newStagePos(-996), (0, 4));
      expect(newStagePos(-980), (1, 0));
      expect(newStagePos(-971), (1, 9));
      expect(newStagePos(-960), (2, 0));
      expect([-1000, -996, -980, -971, -960, -951].map(unitNumberLabel).toList(), ['P1', 'P5', 'bài 1', 'bài 10', 'bài 1', 'bài 10']);
      expect([isPronOrder(-1000), isPronOrder(-996), isPronOrder(-980), isPronOrder(-960), isPronOrder(1)], [true, true, false, false, false]);
    });

    test('danh so cu (truoc migration) van dung', () {
      expect([-14, -10, -9, 0].map(newStagePos).toList(), [(0, 0), (0, 4), (1, 0), (1, 9)]);
      expect([-14, -10, -9, 0, 7].map(unitNumberLabel).toList(), ['P1', 'P5', 'bài 1', 'bài 10', 'bài 7']);
      expect(newStagePos(1), isNull);
    });

    test('bai ke tiep = unit_order lon hon gan nhat', () {
      final units = [for (final o in [-1000, -980, -971, -960, 1, 2]) <String, dynamic>{'unit_id': 'u$o', 'unit_order': o}];
      expect(nextUnitAfter(units, -971)?['unit_id'], 'u-960'); // vuot khoang trong giua Chang 1 va Chang 2
      expect(nextUnitAfter(units, -960)?['unit_id'], 'u1'); // het chang moi -> A1 cu
      expect(nextUnitAfter(units, 1)?['unit_id'], 'u2');
      expect(nextUnitAfter(units, 2), isNull);
    });
  });

  testWidgets('hoc xong bai cuoi Chang 1 (-971) -> bai 1 Chang 2 (-960) duoc mo va thanh bai tiep tuc', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final units = [
      for (var i = 0; i < 5; i++) _u('p$i', -1000 + i, 'Phát âm $i', 0, 'Phát âm', 'completed'),
      for (var i = 0; i < 9; i++) _u('c1_$i', -980 + i, 'Chặng 1 bài $i', 1, 'Những ngày đầu ở Đài Loan', 'completed'),
      _u('c1_9', -971, 'Ôn tập chặng 1', 1, 'Những ngày đầu ở Đài Loan', 'unlocked'),
      _u('c2_0', -960, 'Ngày đầu đi làm', 2, 'Đi làm', 'locked'),
      for (var i = 1; i <= 3; i++) _u('o$i', i, 'Bài cũ $i', 3, '', 'locked'),
    ];
    final session = {
      'session_id': 'S-971', 'version': 'situation_v1',
      'unit': {'id': 'c1_9', 'order': -971, 'total_units': 10, 'topic_vi': 'Ôn tập chặng 1', 'level': 'A1', 'language': 'zh', 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'kind': 'review', 'label': 'Bài 10'},
      'steps': [
        {'type': 'intro', 'title': 'Ôn tập chặng 1', 'goals': ['Ôn lại cả chặng.'], 'estimated_minutes': 11, 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'label': 'Bài 10', 'characters': []},
        {'type': 'summary', 'can_do': ['Ôn xong'], 'lines': [{'zh': '你好', 'pinyin': 'nǐ hǎo', 'vi': 'Xin chào'}]},
      ],
      'retry': {'alts': {}},
    };
    final api = SitApi(session);
    final dio = Dio()..httpClientAdapter = _FakeAdapter({
      '/zh/levels': {'levels': [{'level': 'A1', 'total_units': units.length, 'completed_units': 14}]},
      '/zh/A1/units': {'units': units},
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [lessonV2FetcherProvider.overrideWithValue(() async => true), lessonV2ApiProvider.overrideWithValue(api)],
      child: MaterialApp(home: Scaffold(body: CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: dio, readToken: () async => 'tok'))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục: Ôn tập chặng 1 (bài 10)'), findsOneWidget);
    expect(find.byKey(const Key('open_pron_test')), findsNothing); // Chang 0 da xong -> khong goi y kiem tra bo qua

    await tester.tap(find.byKey(const Key('stage_continue')));
    await tester.pumpAndSettle();
    expect(find.text('Chặng 1 · Những ngày đầu ở Đài Loan · Bài 10 / 10'), findsOneWidget); // nhan do server tra
    await tester.tap(find.byKey(const Key('lesson_start_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('situation_summary_next')));
    await tester.pumpAndSettle();
    expect(find.text('Bài tiếp theo →'), findsOneWidget); // con bai ke tiep (Chang 2) -> khong phai "Về danh sách"
    await tester.tap(find.byKey(const Key('summary_continue')));
    await tester.pumpAndSettle();

    expect(find.byType(LessonV2Screen), findsNothing);
    expect(find.text('Tiếp tục: Ngày đầu đi làm (bài 1)'), findsOneWidget);
  });
}
