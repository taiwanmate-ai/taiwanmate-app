// "Chặng tiếp theo ra mắt ngày X": học xong BÀI MỚI CUỐI CÙNG (server trả next_stage.after_unit_id) -> màn kết quả hiện thẻ ngày ra mắt
// (ngày lấy từ server) + gợi ý ôn tập / học bài cũ, nút "Về danh sách". Bài khác không hiện thẻ.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/situation/next_stage_card.dart';

import 'situation_r3_test.dart' show SitApi;

class _Adapter implements HttpClientAdapter {
  final Map<String, Object> routes;
  _Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final key = routes.keys.firstWhere((k) => o.path.endsWith(k), orElse: () => '');
    if (key.isEmpty) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromString(jsonEncode(routes[key]), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> _u(String id, int order, String topic, int stage, String status) => {
      'unit_id': id, 'level': 'A1', 'unit_order': order, 'topic_vi': topic, 'topic_translated': '', 'status': status,
      'estimated_minutes': 6, 'is_vip_locked': false, 'stage': stage, 'stage_title': stage == 1 ? 'Những ngày đầu ở Đài Loan' : '',
    };

Map<String, dynamic> _session() => {
      'session_id': 'S-b1',
      'version': 'situation_v1',
      'unit': {'id': 'b1', 'order': -971, 'total_units': 11, 'topic_vi': 'Ôn tập', 'topic_zh': '複習', 'level': 'A1', 'language': 'zh', 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'kind': 'situation'},
      'steps': [
        {'type': 'intro', 'title': 'Ôn tập', 'title_target': '複習', 'goals': ['Ôn lại cả chặng.'], 'scene': 'Một ngày của 小安.', 'estimated_minutes': 11,
         'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'characters': []},
        {'type': 'summary', 'can_do': ['你好 — Xin chào'], 'lines': [{'zh': '你好', 'pinyin': 'nǐ hǎo', 'vi': 'Xin chào'}]},
      ],
      'retry': {'alts': {}},
    };

Future<void> _finish(WidgetTester tester, Map<String, Object> unitsBody) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final adapter = _Adapter({
    '/zh/levels': {'levels': [{'level': 'A1', 'total_units': 3, 'completed_units': 0}]},
    '/zh/A1/units': unitsBody,
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      lessonV2FetcherProvider.overrideWithValue(() async => true),
      lessonV2ApiProvider.overrideWithValue(SitApi(_session())),
    ],
    child: MaterialApp(home: Scaffold(body: CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: Dio()..httpClientAdapter = adapter, readToken: () async => 'tok'))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('stage_continue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('lesson_start_btn')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('situation_summary_next')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('summary_title')), findsOneWidget);
}

List<Map<String, Object>> _units() => [
      for (var i = 0; i < 5; i++) {..._u('p${i + 1}', -1000 + i, 'Phát âm ${i + 1}', 0, 'completed'), 'stage_title': 'Phát âm'},
      for (var i = 0; i < 9; i++) _u('c${i + 1}', -980 + i, 'Bài ${i + 1}', 1, 'completed'),
      _u('b1', -971, 'Ôn tập', 1, 'unlocked'),
      _u('o1', 1, 'Bài cũ 1', 2, 'locked'),
      _u('o2', 2, 'Bài cũ 2', 2, 'locked'),
    ];

void main() {
  test('ngày ra mắt: YYYY-MM-DD -> dd/mm/yyyy; rỗng / sai -> null', () {
    expect(nextStageDateLabel('2026-11-10'), '10/11/2026');
    expect(nextStageDateLabel(null), isNull);
    expect(nextStageDateLabel('11/10'), isNull);
  });

  testWidgets('bài mới cuối cùng: màn kết quả hiện "Chặng 2 ra mắt ngày 10/11/2026" + gợi ý, nút "Về danh sách"', (tester) async {
    await _finish(tester, {'units': _units(), 'next_stage': {'after_unit_id': 'b1', 'stage': 2, 'launch_date': '2026-11-10'}});
    expect(find.byKey(const Key('next_stage_card')), findsOneWidget);
    expect(find.text('Chặng 2 ra mắt ngày 10/11/2026.'), findsOneWidget);
    expect(find.text('Về danh sách'), findsOneWidget);
  });

  testWidgets('server chưa đặt ngày: "đang được soạn và sẽ ra mắt sớm"', (tester) async {
    await _finish(tester, {'units': _units(), 'next_stage': {'after_unit_id': 'b1', 'stage': 2, 'launch_date': null}});
    expect(find.text('Chặng 2 đang được soạn và sẽ ra mắt sớm.'), findsOneWidget);
  });

  testWidgets('không phải bài mới cuối cùng / server không trả next_stage: không có thẻ, nút "Bài tiếp theo →"', (tester) async {
    await _finish(tester, {'units': _units(), 'next_stage': {'after_unit_id': 'khac', 'stage': 2, 'launch_date': '2026-11-10'}});
    expect(find.byKey(const Key('next_stage_card')), findsNothing);
    expect(find.text('Bài tiếp theo →'), findsOneWidget);
  });
}
