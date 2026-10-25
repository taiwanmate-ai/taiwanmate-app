// Điều hướng sau khi HOÀN THÀNH bài tình huống (SITUATION_V1), chạy qua CurriculumTab thật:
// "Hoàn thành bài" -> màn kết quả -> "Bài tiếp theo →" phải về DANH SÁCH bài (bài vừa học completed, bài kế mở khóa),
// không được hiện lại màn mở đầu của chính bài vừa học. Kết quả phải được gửi lên server.
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

import 'situation_r3_test.dart' show SitApi;

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> routes;
  final hits = <String>[];
  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    hits.add(o.path);
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

Map<String, dynamic> _session() => {
      'session_id': 'S-b1',
      'version': 'situation_v1',
      'unit': {'id': 'b1', 'order': -9, 'total_units': 17, 'topic_vi': 'Chào hỏi', 'topic_zh': '打招呼', 'level': 'A1', 'language': 'zh', 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'kind': 'situation'},
      'steps': [
        {'type': 'intro', 'title': 'Chào hỏi', 'title_target': '打招呼', 'goals': ['Chào hỏi được người mới gặp.'], 'scene': 'Ngày đầu ở Đài Loan.', 'estimated_minutes': 11,
         'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'characters': []},
        {'type': 'summary', 'can_do': ['你好 — Xin chào'], 'lines': [{'zh': '你好', 'pinyin': 'nǐ hǎo', 'vi': 'Xin chào'}]},
      ],
      'retry': {'alts': {}},
    };

/// Danh sách thật (CurriculumTab) -> mở bài 1 -> "Hoàn thành bài" -> đang ở màn kết quả.
Future<(SitApi, _FakeAdapter)> _finishLesson1(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final units = [
    for (var i = 0; i < 5; i++) _u('p${i + 1}', -14 + i, 'Phát âm ${i + 1}', 0, 'Phát âm', 'completed'),
    _u('b1', -9, 'Chào hỏi', 1, 'Những ngày đầu ở Đài Loan', 'unlocked'),
    _u('b2', -8, 'Giới thiệu bản thân', 1, 'Những ngày đầu ở Đài Loan', 'locked'),
    for (var i = 1; i <= 12; i++) _u('o$i', i, 'Bài cũ $i', 2, '', 'locked'),
  ];
  final adapter = _FakeAdapter({
    '/zh/levels': {'levels': [{'level': 'A1', 'total_units': units.length, 'completed_units': 5}]},
    '/zh/A1/units': {'units': units},
  });
  final api = SitApi(_session());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      lessonV2FetcherProvider.overrideWithValue(() async => true),
      lessonV2ApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(home: Scaffold(body: CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: Dio()..httpClientAdapter = adapter, readToken: () async => 'tok'))),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Tiếp tục: Chào hỏi (bài 1)'), findsOneWidget);
  await tester.tap(find.byKey(const Key('stage_continue')));
  await tester.pumpAndSettle();
  expect(find.byType(LessonV2Screen), findsOneWidget);
  await tester.tap(find.byKey(const Key('lesson_start_btn')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('situation_summary_next')));   // "Hoàn thành bài"
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('summary_title')), findsOneWidget);       // màn kết quả
  expect(api.submitted, isNotNull);                                     // đã gửi kết quả lên server
  expect(api.submitted!['session_id'], 'S-b1');
  return (api, adapter);
}

void _expectBackOnList(_FakeAdapter adapter) {
  expect(find.byType(LessonV2Screen), findsNothing);                    // không mở lại / không quay lại giữa bài vừa học
  expect(find.byKey(const Key('lesson_start_btn')), findsNothing);
  expect(find.text('Tiếp tục: Giới thiệu bản thân (bài 2)'), findsOneWidget);   // về danh sách, bài kế mở khóa + nổi bật
  expect(adapter.hits.where((p) => p.contains('/unit/b1')), isEmpty);  // không rơi sang màn mở đầu bài kiểu cũ
}

void main() {
  testWidgets('bài tình huống: Hoàn thành -> kết quả -> "Bài tiếp theo" -> về danh sách, bài kế được mở, kết quả gửi server', (tester) async {
    final (_, adapter) = await _finishLesson1(tester);
    await tester.tap(find.byKey(const Key('summary_continue')));          // "Bài tiếp theo →"
    await tester.pumpAndSettle();
    _expectBackOnList(adapter);
  });

  testWidgets('bài tình huống: ở màn kết quả bấm Back hệ thống (Android) -> về danh sách, không quay lại giữa bài', (tester) async {
    final (_, adapter) = await _finishLesson1(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _expectBackOnList(adapter);
  });
}
