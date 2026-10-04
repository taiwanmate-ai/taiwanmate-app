// Audit chuan bi Phase 2 (2026-09-30, muc F) — test cho mastery_profile_tab.dart:
// 1. Trang thai RONG: hien noi dung moi + nut "Học ngay" bam duoc.
// 2. Danh sach co du lieu: gom nhom dung theo feature_type/tien to tag, dung thu tu co dinh,
//    gioi han hien thi + nut "Xem thêm" mo rong, CTA chi hien khi co cta_text va bam dung dich.
// Muc E (2026-10-02) — Lich hoat dong (GET /mastery/activity-calendar): cua so hien thi dung so
// o, phan biet duoc o "co theo doi, 0 su kien" voi o "co du lieu", va LOI O DAY KHONG CHAN ca tab.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/mastery_profile_tab.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Object response; // Map (200) hoac Exception (loi mang)
  _FakeAdapter(this.response);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (response is Exception) throw response as Exception;
    return ResponseBody.fromString(jsonEncode(response), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(Object response) {
  final d = Dio();
  d.httpClientAdapter = _FakeAdapter(response);
  return d;
}

/// Nhu _FakeAdapter nhung tra response KHAC NHAU theo duong dan — can cho test Lich hoat dong
/// (GET /mastery/profile va GET /mastery/activity-calendar la 2 request khac nhau tren CUNG 1
/// Dio, muon kiem soat rieng tung cai).
class _FakeMultiAdapter implements HttpClientAdapter {
  final Object Function(RequestOptions) responder;
  _FakeMultiAdapter(this.responder);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final r = responder(o);
    if (r is Exception) throw r;
    return ResponseBody.fromString(jsonEncode(r), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioMulti(Object Function(RequestOptions) responder) {
  final d = Dio();
  d.httpClientAdapter = _FakeMultiAdapter(responder);
  return d;
}

Map<String, dynamic> _topic(String tag, {
  String label = '', double score = 50, String? featureType, String? referenceId, String? ctaText,
}) => {
  'topic_tag': tag, 'label': label.isEmpty ? tag : label, 'language': 'zh',
  'mastery_score': score, 'times_correct': 1, 'times_wrong': 0, 'last_practiced_at': null,
  'feature_type': featureType, 'reference_id': referenceId, 'cta_text': ctaText,
};

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('groupFor (thuan tuy, khong can widget)', () {
    test('boss_arena -> Đấu Trường Boss', () {
      expect(groupForMasteryTopic(_topic('greeting_basic', featureType: 'boss_arena')), 'Đấu Trường Boss');
    });
    test('grammar_tool -> Ngữ pháp', () {
      expect(groupForMasteryTopic(_topic('grammar_le_completion', featureType: 'grammar_tool')), 'Ngữ pháp');
    });
    test('vocab_* (khong co feature_type) -> Từ vựng', () {
      expect(groupForMasteryTopic(_topic('vocab_food')), 'Từ vựng');
      expect(groupForMasteryTopic(_topic('vocab_food_en')), 'Từ vựng');
    });
    test('skill_* (khong co feature_type) -> Thi thử', () {
      expect(groupForMasteryTopic(_topic('skill_reading')), 'Thi thử');
    });
    test('tag la nao khac, khong feature_type -> Khác (dự phòng)', () {
      expect(groupForMasteryTopic(_topic('tag_chua_biet')), 'Khác');
    });
  });

  group('MasteryProfileTab — trạng thái rỗng', () {
    testWidgets('hiện nội dung mới + nút "Học ngay" bấm gọi đúng callback', (tester) async {
      var opened = false;
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioWith({'topics': []}),
        readToken: () async => 'tok',
        onOpenCurriculum: () => opened = true,
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('sẽ hiện ở đây'), findsOneWidget);
      expect(find.text('Học ngay'), findsOneWidget);
      await tester.tap(find.text('Học ngay'));
      expect(opened, isTrue);
      // User chua co learning_event nao -> cung chua co first_event_at -> khong hien Lich hoat dong.
      expect(find.text('Lịch hoạt động'), findsNothing);
    });
  });

  group('MasteryProfileTab — có dữ liệu: gom nhóm + giới hạn + CTA', () {
    testWidgets('gom đúng nhóm, hiện đúng thứ tự cố định (Từ vựng trước Đấu Trường Boss)', (tester) async {
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioWith({'topics': [
          _topic('greeting_basic', label: 'Chào hỏi cơ bản', featureType: 'boss_arena',
                referenceId: '1', ctaText: 'Luyện ngay: Chào hỏi cơ bản'),
          _topic('vocab_food', label: 'Từ vựng: Ẩm thực'),
        ]}),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Từ vựng'), findsOneWidget);
      expect(find.text('Đấu Trường Boss'), findsOneWidget);
      // "Từ vựng" phải nằm TRƯỚC "Đấu Trường Boss" theo thứ tự cố định, bất kể thứ tự trong response.
      final tuVungY = tester.getTopLeft(find.text('Từ vựng')).dy;
      final bossY = tester.getTopLeft(find.text('Đấu Trường Boss')).dy;
      expect(tuVungY, lessThan(bossY));
    });

    testWidgets('hơn 5 dòng trong 1 nhóm -> chỉ hiện 5 + "Xem thêm", bấm mở hết', (tester) async {
      final topics = List.generate(7, (i) => _topic('vocab_tag_$i', label: 'Từ $i', score: (i + 1).toDouble()));
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioWith({'topics': topics}),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Từ 0'), findsOneWidget);
      expect(find.text('Từ 4'), findsOneWidget);
      expect(find.text('Từ 5'), findsNothing); // dong thu 6 chua hien
      expect(find.text('Xem thêm (2)'), findsOneWidget);

      await tester.tap(find.text('Xem thêm (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Từ 5'), findsOneWidget);
      expect(find.text('Từ 6'), findsOneWidget);
      expect(find.text('Xem thêm (2)'), findsNothing);
    });

    testWidgets('dòng có cta_text hiện CTA bấm được đúng data; dòng không có cta_text KHÔNG hiện gì',
        (tester) async {
      Map<String, dynamic>? tapped;
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioWith({'topics': [
          _topic('grammar_le_completion', label: 'Trợ động từ 了', featureType: 'grammar_tool',
                referenceId: 'Khi nào dùng 了', ctaText: 'Tìm hiểu: Trợ động từ 了'),
          _topic('vocab_food', label: 'Từ vựng: Ẩm thực'), // khong co feature_type -> khong CTA
        ]}),
        readToken: () async => 'tok',
        onCta: (t) => tapped = t,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Tìm hiểu: Trợ động từ 了'), findsOneWidget);
      await tester.tap(find.text('Tìm hiểu: Trợ động từ 了'));
      expect(tapped?['topic_tag'], 'grammar_le_completion');
      expect(tapped?['reference_id'], 'Khi nào dùng 了');

      // Dong vocab_food khong co dong text CTA nao (chi co label + % + thanh diem).
      expect(find.textContaining('Luyện ngay'), findsNothing);
    });
  });

  group('MasteryProfileTab — lỗi mạng (hành vi cũ, không đổi)', () {
    testWidgets('lỗi -> hiện "Thử lại"', (tester) async {
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioWith(DioException(requestOptions: RequestOptions(path: '/mastery/profile'))),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });

  group('MasteryProfileTab — Lịch hoạt động (mục E, 2026-10-02)', () {
    Object respond(RequestOptions o, {required Object calendar, required Object profile}) =>
        o.path.contains('activity-calendar') ? calendar : profile;

    testWidgets('cửa sổ co giãn theo tuổi dữ liệu: first_event_at hôm qua -> đúng 2 ô', (tester) async {
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioMulti((o) => respond(o,
          calendar: {'first_event_at': yesterday.toIso8601String(), 'days': []},
          profile: {'topics': [_topic('vocab_food', label: 'Từ vựng: Ẩm thực')]},
        )),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Lịch hoạt động'), findsOneWidget);
      expect(find.byType(Tooltip), findsNWidgets(2)); // hom qua + hom nay, KHONG hon
    });

    testWidgets('trần tối đa 30 ô dù dữ liệu cũ hơn (first_event_at 90 ngày trước)', (tester) async {
      final longAgo = DateTime.now().toUtc().subtract(const Duration(days: 90));
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioMulti((o) => respond(o,
          calendar: {'first_event_at': longAgo.toIso8601String(), 'days': []},
          profile: {'topics': [_topic('vocab_food', label: 'Từ vựng: Ẩm thực')]},
        )),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.byType(Tooltip), findsNWidgets(30));
    });

    testWidgets('ô "có dữ liệu" và ô "trong khoảng theo dõi, 0 sự kiện" hiện màu khác nhau', (tester) async {
      final yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final todayKey = DateTime.now().toUtc().toIso8601String().split('T').first;
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioMulti((o) => respond(o,
          calendar: {'first_event_at': yesterday.toIso8601String(), 'days': [
            {'date': todayKey, 'count': 5}, // hom qua KHONG co trong list -> 0 su kien
          ]},
          profile: {'topics': [_topic('vocab_food', label: 'Từ vựng: Ẩm thực')]},
        )),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(Wrap), matching: find.byType(Container)),
      ).toList();
      expect(containers.length, 2);
      final colors = containers.map((c) => (c.decoration as BoxDecoration).color).toList();
      expect(colors[0], isNot(equals(colors[1])));
    });

    testWidgets('user chưa có learning_event nào (first_event_at null) -> không hiện Lịch hoạt động',
        (tester) async {
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioMulti((o) => respond(o,
          calendar: {'first_event_at': null, 'days': []},
          profile: {'topics': [_topic('vocab_food', label: 'Từ vựng: Ẩm thực')]},
        )),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Lịch hoạt động'), findsNothing);
      expect(find.text('Từ vựng: Ẩm thực'), findsOneWidget); // danh sach chinh van hien binh thuong
    });

    testWidgets('lỗi riêng ở /activity-calendar KHÔNG chặn phần còn lại của tab', (tester) async {
      await tester.pumpWidget(_host(MasteryProfileTab(
        dio: _dioMulti((o) => o.path.contains('activity-calendar')
            ? DioException(requestOptions: o)
            : {'topics': [_topic('vocab_food', label: 'Từ vựng: Ẩm thực')]}),
        readToken: () async => 'tok',
      )));
      await tester.pumpAndSettle();

      expect(find.text('Từ vựng: Ẩm thực'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing); // loi chi o widget phu, khong phai loi profile
      expect(find.text('Lịch hoạt động'), findsNothing);
    });
  });
}
