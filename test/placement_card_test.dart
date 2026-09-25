// Test cho PlacementCard / loadPlacementInfo (CAT đầu vào TÙY CHỌN, 2026-09-26). Không gọi mạng thật:
// Dio dùng adapter giả, lưu trữ/điều hướng được tiêm vào.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/placement_card.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> routes; // hậu tố path -> JSON (hoặc Exception để mô phỏng lỗi mạng)
  final List<RequestOptions> calls = [];
  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    calls.add(o);
    final key = routes.keys.firstWhere((k) => o.path.endsWith(k), orElse: () => '');
    if (key.isEmpty) return ResponseBody.fromString('not found', 404);
    final v = routes[key]!;
    if (v is Exception) throw v;
    return ResponseBody.fromString(jsonEncode(v), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(Map<String, Object> routes) {
  final d = Dio();
  d.httpClientAdapter = _FakeAdapter(routes);
  return d;
}

Map<String, Object> _status({bool completed = false, bool readingIn = false, bool listeningIn = false}) => {
      'completed': completed,
      'reading': {'completed': completed, 'in_progress': readingIn},
      'listening': {'completed': completed, 'in_progress': listeningIn},
    };

final _now = DateTime(2026, 9, 26, 12);
Future<String?> _noKey(String k) async => null;

void main() {
  group('loadPlacementInfo', () {
    test('chưa làm + bài sẵn sàng -> notTaken', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': _status(), '/availability': {'available': true}}),
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.notTaken);
    });

    test('đang làm dở -> inProgress', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': _status(readingIn: true), '/availability': {'available': true}}),
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.inProgress);
    });

    test('đã xong -> completed kèm cấp + bài gợi ý, KHÔNG cần availability', () async {
      final info = await loadPlacementInfo(
        dio: _dio({
          '/status': _status(completed: true),
          '/result': {'overall_level': 'A2', 'recommended': {'level': 'A2', 'topic_vi': 'Mua sắm', 'unit_order': 1}},
        }),
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.completed);
      expect(info.overallLevel, 'A2');
      expect(info.recommendedLevel, 'A2');
      expect(info.recommendedTopic, 'Mua sắm');
    });

    test('đã xong nhưng result lỗi -> hidden (không chặn, không lỗi)', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': _status(completed: true)}), // /result trả 404
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.hidden);
    });

    test('bài kiểm tra chưa sẵn sàng (available=false) -> hidden', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': _status(), '/availability': {'available': false}}),
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.hidden);
    });

    test('lỗi mạng / server lỗi -> hidden', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': DioException(requestOptions: RequestOptions(path: '/status'))}),
        testType: 'tocfl', readKey: _noKey, now: _now,
      );
      expect(info.state, PlacementState.hidden);
      final info2 = await loadPlacementInfo(dio: _dio({}), testType: 'tocfl', readKey: _noKey, now: _now);
      expect(info2.state, PlacementState.hidden);
    });

    test('"Để sau" ẩn $placementSnoozeDays ngày rồi mời lại', () async {
      final routes = {'/status': _status(), '/availability': {'available': true}};
      Future<String?> dismissedDaysAgo(int d) async => _now.subtract(Duration(days: d)).toIso8601String();
      final key = placementDismissKey('tocfl');

      final recent = await loadPlacementInfo(
        dio: _dio(routes), testType: 'tocfl', now: _now,
        readKey: (k) => k == key ? dismissedDaysAgo(2) : Future.value(null),
      );
      expect(recent.state, PlacementState.hidden);

      final old = await loadPlacementInfo(
        dio: _dio(routes), testType: 'tocfl', now: _now,
        readKey: (k) => k == key ? dismissedDaysAgo(8) : Future.value(null),
      );
      expect(old.state, PlacementState.notTaken);
    });

    test('đã làm xong thì hiện kết quả kể cả khi từng bấm "Để sau"', () async {
      final info = await loadPlacementInfo(
        dio: _dio({'/status': _status(completed: true), '/result': {'overall_level': 'B1', 'recommended': null}}),
        testType: 'tocfl', now: _now,
        readKey: (k) async => _now.toIso8601String(),
      );
      expect(info.state, PlacementState.completed);
      expect(info.recommendedLevel, isNull);
    });

    test('ngôn ngữ en -> test_type english', () {
      expect(placementTestType('en'), 'english');
      expect(placementTestType('zh'), 'tocfl');
    });
  });

  group('PlacementCard widget', () {
    Widget host(PlacementCard card) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card)));

    PlacementCard card({
      required Map<String, Object> routes,
      String lang = 'zh',
      void Function(String, String)? onStart,
      Future<String?> Function(String)? readKey,
      Future<void> Function(String, String)? writeKey,
      Future<void> Function(BuildContext, String)? openTest,
      _FakeAdapter? adapter,
    }) {
      final d = Dio()..httpClientAdapter = adapter ?? _FakeAdapter(routes);
      return PlacementCard(
        lang: lang, onStartFromLevel: onStart ?? (_, __) {}, dio: d,
        readKey: readKey ?? _noKey, writeKey: writeKey ?? (_, __) async {},
        readToken: () async => 'tok', clock: () => _now, openTest: openTest,
      );
    }

    testWidgets('notTaken: hiện thẻ + "Để sau" ẩn thẻ và ghi thời điểm', (t) async {
      final writes = <String, String>{};
      await t.pumpWidget(host(card(
        routes: {'/status': _status(), '/availability': {'available': true}},
        writeKey: (k, v) async => writes[k] = v,
      )));
      await t.pumpAndSettle();
      expect(find.text('Kiểm tra trình độ (khoảng 3 phút)'), findsOneWidget);
      expect(find.text('Làm bài kiểm tra'), findsOneWidget);

      await t.tap(find.text('Để sau'));
      await t.pumpAndSettle();
      expect(find.text('Kiểm tra trình độ (khoảng 3 phút)'), findsNothing);
      expect(writes[placementDismissKey('tocfl')], _now.toIso8601String());
    });

    testWidgets('bấm "Làm bài kiểm tra" mở bài đúng test_type rồi làm mới trạng thái', (t) async {
      final adapter = _FakeAdapter({'/status': _status(), '/availability': {'available': true}});
      String? opened;
      await t.pumpWidget(host(card(
        routes: const {}, adapter: adapter, lang: 'en',
        openTest: (ctx, type) async => opened = type,
      )));
      await t.pumpAndSettle();
      final before = adapter.calls.where((c) => c.path.endsWith('/status')).length;
      expect(adapter.calls.first.queryParameters['test_type'], 'english');

      await t.tap(find.text('Làm bài kiểm tra'));
      await t.pumpAndSettle();
      expect(opened, 'english');
      expect(adapter.calls.where((c) => c.path.endsWith('/status')).length, before + 1);
    });

    testWidgets('inProgress: nút "Tiếp tục"', (t) async {
      await t.pumpWidget(host(card(routes: {'/status': _status(listeningIn: true), '/availability': {'available': true}})));
      await t.pumpAndSettle();
      expect(find.text('Bạn đang làm dở bài kiểm tra trình độ'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
    });

    testWidgets('completed: hiện trình độ và nút bắt đầu từ cấp gợi ý (đúng ngôn ngữ+cấp)', (t) async {
      final started = <List<String>>[];
      await t.pumpWidget(host(card(
        routes: {
          '/status': _status(completed: true),
          '/result': {'overall_level': 'A2', 'recommended': {'level': 'A2', 'topic_vi': 'Mua sắm'}},
        },
        onStart: (l, lv) => started.add([l, lv]),
      )));
      await t.pumpAndSettle();
      expect(find.text('Trình độ của bạn: A2'), findsOneWidget);
      expect(find.text('Để sau'), findsNothing);
      await t.tap(find.text('Bắt đầu học từ A2'));
      expect(started, [['zh', 'A2']]);
    });

    testWidgets('bài chưa sẵn sàng / lỗi: KHÔNG hiện gì (không chặn, không báo lỗi)', (t) async {
      await t.pumpWidget(host(card(routes: {'/status': _status(), '/availability': {'available': false}})));
      await t.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);

      await t.pumpWidget(host(card(routes: const {})));
      await t.pumpAndSettle();
      expect(find.byType(ElevatedButton), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('LearnScreen không còn chặn bằng CAT (bảo vệ chống quay lại cổng cứng)', () {
    final src = File('lib/features/learn/presentation/screens/learn_screen.dart').readAsStringSync();

    test('không còn trạng thái/nhánh cổng CAT', () {
      for (final gone in ['_CatGateStatus', 'needsCat', 'testTypeUnavailable', '_checkCatGateStatus', 'CatTestTab(']) {
        expect(src.contains(gone), isFalse, reason: '$gone không được xuất hiện lại trong learn_screen.dart');
      }
    });

    test('heatmap 30 ngày giả (i % 3) đã bị gỡ', () {
      expect(src.contains('_calendarData'), isFalse);
      expect(src.contains('_loadCalendarData'), isFalse);
    });

    test('hub vẫn có thẻ CAT tùy chọn', () {
      final hub = File('lib/features/learn/presentation/widgets/learn_hub_tab.dart').readAsStringSync();
      expect(hub.contains('PlacementCard('), isTrue);
    });
  });
}
