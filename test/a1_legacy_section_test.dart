// Lộ trình A1 CHỈ có Chặng 0..n; bài A1 cũ ở mục riêng "Bài luyện thêm (giáo trình cũ)" (CTO 31/10, server layout=v2).
// Không gọi mạng thật: Dio dùng adapter giả theo path; kiểm cả việc app gửi layout=v2.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';

class _Adapter implements HttpClientAdapter {
  final Map<String, Object> routes;
  final List<RequestOptions> seen = [];
  _Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    final key = routes.keys.firstWhere((k) => o.path.endsWith(k), orElse: () => '');
    if (key.isEmpty) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromString(jsonEncode(routes[key]), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object> _u(String id, int order, String topic, String status, {int? stage, bool legacy = false}) => {
      'unit_id': id, 'level': 'A1', 'unit_order': order, 'topic_vi': topic, 'topic_translated': '', 'status': status,
      'estimated_minutes': 6, 'is_vip_locked': false,
      if (stage != null) 'stage': stage, if (stage != null) 'stage_title': stage == 0 ? 'Phát âm' : 'Những ngày đầu ở Đài Loan',
      if (legacy) 'legacy': true, if (legacy) 'label': 'Bài $order',
    };

Map<String, Object> _body({required bool experienced, int legacyDone = 0}) => {
      'units': [
        for (var i = 0; i < 5; i++) _u('p${i + 1}', -1000 + i, 'Phát âm ${i + 1}', experienced || i == 0 ? 'unlocked' : 'locked', stage: 0),
        for (var i = 0; i < 10; i++) _u('c${i + 1}', -980 + i, 'Tình huống ${i + 1}', experienced ? 'unlocked' : 'locked', stage: 1),
      ],
      'legacy_units': [for (var i = 1; i <= 12; i++) _u('o$i', i, 'Bài cũ $i', i <= legacyDone ? 'completed' : 'unlocked', legacy: true)],
      'legacy_total': 12, 'legacy_completed': legacyDone, 'experienced': experienced,
      'next_stage': {'after_unit_id': 'c10', 'next': 'level', 'next_level': 'A2', 'launch_date': null},
    };

Future<_Adapter> _open(WidgetTester tester, Map<String, Object> body, {int legacyDone = 0}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final a = _Adapter({
    '/zh/levels': {'levels': [{'level': 'A1', 'total_units': 15, 'completed_units': 0, 'legacy_total': 12, 'legacy_completed': legacyDone}]},
    '/zh/A1/units': body,
  });
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: Dio()..httpClientAdapter = a, readToken: () async => 'tok'))));
  await tester.pumpAndSettle();
  return a;
}

void main() {
  testWidgets('app gửi layout=v2; lộ trình chỉ có bài mới, bài cũ nằm trong mục luyện thêm THU GỌN', (tester) async {
    final a = await _open(tester, _body(experienced: false));
    expect(a.seen.where((o) => o.path.endsWith('/zh/A1/units')).single.queryParameters['layout'], 'v2');
    expect(a.seen.where((o) => o.path.endsWith('/zh/levels')).single.queryParameters['layout'], 'v2');
    expect(find.byKey(const Key('legacy_section')), findsOneWidget);
    expect(find.text('Bài luyện thêm (giáo trình cũ)'), findsOneWidget);
    expect(find.text('Đã học 0/12 bài · không bắt buộc'), findsOneWidget);
    expect(find.text('Bài cũ 1'), findsNothing);                       // thu gọn mặc định
    expect(find.textContaining('Tiếp tục: Phát âm 1'), findsOneWidget);  // "Tiếp tục" trong lộ trình
    expect(find.byKey(const Key('legacy_done_line')), findsNothing);    // N = 0 -> không hiện
    expect(find.byKey(const Key('experienced_hint')), findsNothing);
    await tester.tap(find.text('Bài luyện thêm (giáo trình cũ)'));
    await tester.pumpAndSettle();
    expect(find.text('Bài cũ 1'), findsOneWidget);
    expect(find.text('Bài 1–10'), findsOneWidget);
    expect(find.text('Bài 11–12'), findsOneWidget);
  });

  testWidgets('đã học bài cũ: hiện "Đã học N bài giáo trình cũ" + gợi ý bắt đầu từ Chặng 0 / kiểm tra bỏ qua', (tester) async {
    await _open(tester, _body(experienced: true, legacyDone: 7), legacyDone: 7);
    expect(find.text('Đã học 7 bài giáo trình cũ'), findsOneWidget);
    expect(find.text('Đã học 7/12 bài · không bắt buộc'), findsOneWidget);
    expect(find.byKey(const Key('experienced_hint')), findsOneWidget);
    expect(find.textContaining('Chặng 0 (Phát âm)'), findsOneWidget);
  });

  testWidgets('danh sách cấp: dòng "Đã học N bài giáo trình cũ" cạnh thanh tiến độ khi N > 0', (tester) async {
    await _open(tester, _body(experienced: true, legacyDone: 7), legacyDone: 7);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('0/15 buổi'), findsOneWidget);
    expect(find.byKey(const Key('legacy_done_line_A1')), findsOneWidget);
    expect(find.text('Đã học 7 bài giáo trình cũ'), findsOneWidget);
  });
}
