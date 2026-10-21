// Test cho CurriculumTab — "Hôm nay" v1 (2026-10-04) thêm initialUnitId, mở thẳng ĐÚNG 1 unit
// (sau khi tải danh sách bài NHƯ BÌNH THƯỜNG, không tự chế lối tắt) để nút back trả về đúng
// danh sách đã tải, không phải màn trống. Không gọi mạng thật: Dio dùng adapter giả theo path.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Object> routes; // hậu tố path -> JSON (hoặc Exception để mô phỏng lỗi mạng)
  _FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
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

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

const _unitA = {
  'unit_id': 'u-a', 'level': 'A1', 'unit_order': 1, 'topic_vi': 'Chào Hỏi',
  'topic_translated': '打招呼', 'status': 'unlocked', 'estimated_minutes': 5, 'is_vip_locked': false,
};
const _unitB = {
  'unit_id': 'u-b', 'level': 'A1', 'unit_order': 2, 'topic_vi': 'Gia Đình',
  'topic_translated': '家庭', 'status': 'locked', 'estimated_minutes': 5, 'is_vip_locked': false,
};

final Map<String, Object> _routes = {
  '/zh/levels': {'levels': [{'level': 'A1', 'total_units': 2, 'completed_units': 0}]},
  '/zh/A1/units': {'units': [_unitA, _unitB]},
  '/unit/u-a': {
    'unit_id': 'u-a', 'topic_vi': 'Chào Hỏi', 'topic_translated': '打招呼',
    'intro_text': 'Giới thiệu bài học', 'estimated_minutes': 5,
    'review_words': [], 'words': [], 'grammar': null,
  },
};

Dio _dio() {
  final d = Dio();
  d.httpClientAdapter = _FakeAdapter(_routes);
  return d;
}

void main() {
  group('initialUnitId (Hôm nay v1)', () {
    testWidgets('mở thẳng vào đúng unit detail, không dừng ở danh sách bài', (tester) async {
      await tester.pumpWidget(_host(CurriculumTab(
        initialLanguage: 'zh', initialLevel: 'A1', initialUnitId: 'u-a', dio: _dio(), readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Chào Hỏi'), findsOneWidget); // tiêu đề lớn ở unit detail
      expect(find.text('Bắt đầu buổi học'), findsOneWidget); // CTA chỉ có ở unit detail
      expect(find.text('Cấp A1'), findsNothing); // không dừng ở màn danh sách bài
    });

    testWidgets('bấm back quay về ĐÚNG danh sách bài đã tải (không trống)', (tester) async {
      await tester.pumpWidget(_host(CurriculumTab(
        initialLanguage: 'zh', initialLevel: 'A1', initialUnitId: 'u-a', dio: _dio(), readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Cấp A1'), findsOneWidget);
      expect(find.text('Chào Hỏi'), findsOneWidget); // ca 2 bai van hien day du
      expect(find.text('Gia Đình'), findsOneWidget);
    });

    testWidgets('unitId không tồn tại trong danh sách -> không crash, đứng yên ở danh sách bài',
        (tester) async {
      await tester.pumpWidget(_host(CurriculumTab(
        initialLanguage: 'zh', initialLevel: 'A1', initialUnitId: 'unit-khong-ton-tai', dio: _dio(), readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Cấp A1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('các lối mở hiện có — không bị ảnh hưởng', () {
    testWidgets('chỉ initialLanguage+initialLevel (không initialUnitId, như placement_card cũ)',
        (tester) async {
      await tester.pumpWidget(_host(CurriculumTab(
        initialLanguage: 'zh', initialLevel: 'A1', dio: _dio(), readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Cấp A1'), findsOneWidget);
    });

    testWidgets('không truyền gì -> màn chọn ngôn ngữ như cũ', (tester) async {
      await tester.pumpWidget(_host(CurriculumTab(dio: _dio())));
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Trung'), findsOneWidget);
      expect(find.text('Cấp A1'), findsNothing);
    });
  });


  group('bài tình huống (Q3, sau cờ SITUATION_V1)', () {
    Dio dioWith(List<Map<String, Object>> units) {
      final d = Dio();
      d.httpClientAdapter = _FakeAdapter({
        '/zh/levels': {'levels': [{'level': 'A1', 'total_units': units.length, 'completed_units': 0}]},
        '/zh/A1/units': {'units': units},
      });
      return d;
    }

    Map<String, Object> u(String id, int order, String topic, int stage, String title, {String status = 'locked', bool optional = false}) => {
          'unit_id': id, 'level': 'A1', 'unit_order': order, 'topic_vi': topic, 'topic_translated': '', 'status': status, 'estimated_minutes': 6, 'is_vip_locked': false,
          'stage': stage, 'stage_title': title, if (optional) 'optional': true,
        };

    testWidgets('chặng + tên chặng do server trả; nút Bảng pinyin + kiểm tra nhanh chỉ khi có bài mới', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final units = [
        u('p1', -14, 'Bốn thanh điệu', 0, 'Phát âm', status: 'unlocked'),
        u('b1', -9, 'Chào hỏi', 1, 'Những ngày đầu ở Đài Loan'),
        for (var i = 1; i <= 12; i++) u('o$i', i, 'Bài cũ $i', 2, ''),
      ];
      await tester.pumpWidget(_host(CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: dioWith(units), readToken: () async => 'tok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open_pinyin_chart')), findsOneWidget);
      expect(find.byKey(const Key('open_pron_test')), findsOneWidget);
      expect(find.text('Chặng 0 · Phát âm'), findsOneWidget);
      expect(find.text('Chặng 1 · Những ngày đầu ở Đài Loan'), findsOneWidget);
      expect(find.textContaining('Chặng 2 ·'), findsOneWidget);
      expect(find.text('Tiếp tục: Bốn thanh điệu (P1)'), findsOneWidget);
    });

    testWidgets('người ngoài cờ (không có bài order <= 0): không có nút mới, chặng theo server như cũ', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final units = [for (var i = 1; i <= 13; i++) u('o$i', i, 'Bài cũ $i', ((i - 1) ~/ 10) + 1, '', status: i == 1 ? 'unlocked' : 'locked')];
      await tester.pumpWidget(_host(CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: dioWith(units), readToken: () async => 'tok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open_pinyin_chart')), findsNothing);
      expect(find.byKey(const Key('open_pron_test')), findsNothing);
      expect(find.text('Chặng 1 · bài 1–10'), findsOneWidget);
    });
  });
}
