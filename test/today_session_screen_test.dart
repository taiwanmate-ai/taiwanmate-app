// Test cho TodaySessionScreen — "Hôm nay" v1 (2026-10-04). Không gọi mạng thật: Dio dùng
// adapter giả theo path (GET /learn/today, POST /learn/today/event, và CurriculumTab lồng
// trong khi bấm "Học bài này" cũng dùng CHUNG dio/readToken giả này — xem today_session_screen.dart).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/screens/today_session_screen.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/learn/presentation/widgets/quick_review_screen.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Object Function(RequestOptions) responder; // tra JSON (Map) hoac throw Exception
  _FakeAdapter(this.responder);

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

Dio _dio(Object Function(RequestOptions) responder) {
  final d = Dio();
  d.httpClientAdapter = _FakeAdapter(responder);
  return d;
}

Widget _host(Widget child) => MaterialApp(home: child);

Map<String, dynamic> _word(String tag, {bool review = false}) => {
  'id': tag, 'chinese': tag, 'pinyin': tag, 'vietnamese': tag, 'example_zh': '', 'srs_level': 0,
  'is_review': review,
};

String _getWord(Map<String, dynamic> w) => w['chinese'] ?? '';
String _getPinyin(Map<String, dynamic> w) => w['pinyin'] ?? '';
String _getMeaning(Map<String, dynamic> w) => w['vietnamese'] ?? '';
String _getExample(Map<String, dynamic> w) => w['example_zh'] ?? '';
String _getVocabId(Map<String, dynamic> w) => w['id']?.toString() ?? '';
bool _isReview(Map<String, dynamic> w) => w['is_review'] == true;
int _getSrsLevel(Map<String, dynamic> w) => (w['srs_level'] as num?)?.toInt() ?? 0;

TodaySessionScreen _screen({
  required Object Function(RequestOptions) responder,
  List<Map<String, dynamic>>? vocabulary,
}) => TodaySessionScreen(
  vocabulary: vocabulary ?? [_word('a', review: true), _word('b', review: true), _word('c')],
  lang: 'zh',
  getWord: _getWord, getPinyin: _getPinyin, getMeaning: _getMeaning, getExample: _getExample,
  getVocabId: _getVocabId, isReview: _isReview, getSrsLevel: _getSrsLevel,
  onStudied: () {}, onUpdateSRS: (_, __) async {},
  dio: _dio(responder), readToken: () async => 'tok',
);

Object _todayResponse({Object? recall, Object? nextUnit, bool completed = false}) =>
    {'recall': recall, 'next_unit': nextUnit, 'curriculum_completed': completed};

void main() {
  group('card (b) — ôn SRS đến hạn (không gọi API riêng)', () {
    testWidgets('hiện đúng số thẻ đến hạn và nút "Ôn ngay"', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('2 thẻ cần ôn hôm nay'), findsOneWidget); // 2/3 từ co is_review=true
      expect(find.text('Ôn ngay'), findsOneWidget);
    });

    testWidgets('due = 0 -> thông báo rỗng, KHÔNG hiện nút', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'}),
        vocabulary: [_word('a'), _word('b')], // khong co is_review=true nao
      )));
      await tester.pumpAndSettle();

      expect(find.text('Không có thẻ cần ôn hôm nay 🎉'), findsOneWidget);
      expect(find.text('Ôn ngay'), findsNothing);
    });

    testWidgets('bấm "Ôn ngay" mở QuickReviewScreen đúng danh sách đến hạn', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'}),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ôn ngay'));
      await tester.pumpAndSettle();

      expect(find.byType(QuickReviewScreen), findsOneWidget);
      final screen = tester.widget<QuickReviewScreen>(find.byType(QuickReviewScreen));
      expect(screen.vocabulary.length, 2); // chi 2 the is_review=true, khong lan the moi
    });
  });

  group('card (a) — nhớ lại', () {
    testWidgets('type=taught hiện label + content', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(
          recall: {'type': 'taught', 'label': 'Ẩm thực', 'content': 'Sai: 吃飯 chứ không phải 呷飯'},
          nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Nhớ lại: Ẩm thực'), findsOneWidget);
      expect(find.text('Sai: 吃飯 chứ không phải 呷飯'), findsOneWidget);
    });

    testWidgets('type=unit_words hiện chữ Hán trước, chạm để lộ pinyin+nghĩa', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(
          recall: {'type': 'unit_words', 'unit_topic_vi': 'Chào Hỏi', 'words': [
            {'id': 'w1', 'word': '你好', 'pinyin_or_ipa': 'nǐ hǎo', 'meaning': 'xin chào'},
          ]},
          nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('你好'), findsOneWidget);
      expect(find.text('nǐ hǎo'), findsNothing); // chua cham -> chua lo
      expect(find.text('xin chào'), findsNothing);

      await tester.tap(find.text('你好'));
      await tester.pumpAndSettle();

      expect(find.text('nǐ hǎo'), findsOneWidget);
      expect(find.text('xin chào'), findsOneWidget);
    });

    testWidgets('recall null -> không hiện card "Nhớ lại" nào', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'}),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nhớ lại'), findsNothing);
    });
  });

  group('card (c) — tiếp tục lộ trình', () {
    testWidgets('hiện tên unit kế tiếp + nút "Học bài này", bấm mở CurriculumTab đúng unit',
        (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(nextUnit: {'unit_id': 'u1', 'topic_vi': 'Gia Đình', 'level': 'A1'}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Gia Đình'), findsOneWidget);
      await tester.tap(find.text('Học bài này'));
      await tester.pumpAndSettle();

      expect(find.byType(CurriculumTab), findsOneWidget);
      final tab = tester.widget<CurriculumTab>(find.byType(CurriculumTab));
      expect(tab.initialUnitId, 'u1');
      expect(tab.initialLevel, 'A1');
      expect(tab.initialLanguage, 'zh');
    });

    testWidgets('curriculum_completed = true -> thông báo hoàn thành, KHÔNG hiện nút', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => _todayResponse(completed: true),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Bạn đã học hết lộ trình rồi! 🎉'), findsOneWidget);
      expect(find.text('Học bài này'), findsNothing);
    });
  });

  group('lỗi mạng /learn/today — chỉ ảnh hưởng card (a)+(c), KHÔNG chặn card (b)', () {
    testWidgets('hiện "Thử lại" riêng cho (a)+(c), card ôn SRS vẫn hiện bình thường', (tester) async {
      await tester.pumpWidget(_host(_screen(
        responder: (o) => DioException(requestOptions: o),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Không tải được gợi ý hôm nay'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('2 thẻ cần ôn hôm nay'), findsOneWidget); // (b) khong phu thuoc /learn/today
      expect(find.text('Ôn ngay'), findsOneWidget);
    });
  });
}
