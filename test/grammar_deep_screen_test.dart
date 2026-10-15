// Bai giang NGU PHAP CHUYEN SAU (version 2, 2026-10-10): hien TOM TAT truoc, cac phan con lai thu gon; dap an luyen tap an;
// du lieu cu (khong co version) van hien; du lieu sai kieu khong lam man hinh trang; man cho co thong diep moi.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/tools/presentation/screens/grammar_tool_screen.dart';

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function() handler;
  _Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) => handler();
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

Dio _dio(Future<ResponseBody> Function() h) => Dio()..httpClientAdapter = _Adapter(h);

Future<void> _open(WidgetTester tester, Dio dio, {String? q = 'Giải thích 把'}) async {
  tester.view.physicalSize = const Size(900, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: GrammarToolScreen(initialQuery: q, dio: dio, readToken: () async => 'tok')));
}

Map<String, dynamic> _deep() => {
      'version': 2, 'cached': false, 'language': 'zh', 'key': '把字句', 'title': '把字句',
      'summary': 'TOM TAT NGAN GON',
      'nuance': {'meaning': 'Y NGHIA COT LOI', 'when_to_use': 'KHI DUNG', 'tone': 'SAC THAI', 'spoken_vs_written': 'NOI VIET', 'regional': 'DAI LOAN'},
      'formula_detail': {'affirmative': 'S + 把 + O + V + 其他', 'negative': 'S + 沒 + 把 + O', 'interrogative': 'S + 把 + O + V 嗎', 'variants': ['BIEN THE 1'], 'position': 'VI TRI'},
      'attention_points': [
        {'title': 'CHU Y MOT', 'explanation': 'GIAI THICH MOT', 'example': {'text': '我把門關上了。', 'pinyin': 'Wǒ bǎ mén guān shàng le.', 'meaning': 'Toi dong cua roi.'}},
      ],
      'learner_mistakes': [{'wrong': '我把錢給。', 'correct': '我把錢給你了。', 'why': 'VI SAO SAI'}],
      'comparison_table': {'structures': ['把字句', '被字句'], 'rows': [{'aspect': 'Y NGHIA', 'values': ['NGHIA A', 'NGHIA B']}], 'note': 'KET LUAN SO SANH'},
      'examples': [
        {'level': 'easy', 'context': 'CHO DEM', 'text': '我把麵吃完了。', 'pinyin': 'Wǒ bǎ miàn chī wán le.', 'meaning': 'Toi an het mi.'},
        {'level': 'hard', 'context': 'HOI THOAI', 'text': 'A: 你傳了嗎？\nB: 傳了。', 'pinyin': 'A: Nǐ chuán le ma?\nB: Chuán le.', 'meaning': 'A: ...\nB: ...'},
      ],
      'practice': [
        {'question': 'CAU HOI LUYEN TAP 1', 'options': ['A. LUA CHON AA', 'B. LUA CHON BB', 'C. LUA CHON CC'], 'answer': 'B. DAP AN 1', 'explanation': 'GIAI THICH DAP AN 1'},
        {'question': 'CAU HOI LUYEN TAP 2', 'options': ['A. x', 'B. y', 'C. z'], 'answer': 'C. DAP AN 2', 'explanation': ''},
      ],
      // truong tuong thich client cu
      'definition': 'TOM TAT NGAN GON', 'formula': 'S + 把 + O + V + 其他', 'comparison': '', 'common_mistakes': '', 'exceptions': '',
    };

void main() {
  testWidgets('v2: hien TOM TAT ngay, cac phan khac thu gon, bam mo ra moi thay', (tester) async {
    await _open(tester, _dio(() async => _json(_deep())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('TOM TAT NGAN GON'), findsOneWidget);
    expect(find.text('TÓM TẮT'), findsOneWidget);
    // Cac phan con lai co tieu de nhung NOI DUNG chua hien (thu gon)
    expect(find.text('Công thức đầy đủ'), findsOneWidget);
    expect(find.text('S + 把 + O + V + 其他'), findsNothing);
    expect(find.text('GIAI THICH MOT'), findsNothing);
    await tester.tap(find.text('Công thức đầy đủ'));
    await tester.pumpAndSettle();
    expect(find.text('S + 把 + O + V + 其他'), findsOneWidget);
    await tester.tap(find.textContaining('Điểm cần chú ý'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GIAI THICH MOT'), findsOneWidget);
    expect(find.text('Wǒ bǎ mén guān shàng le.'), findsOneWidget); // pinyin hien duoi cau
  });

  testWidgets('v2: bang so sanh, vi du (nhan Dễ/Khó), loi hay mac hien khi mo', (tester) async {
    await _open(tester, _dio(() async => _json(_deep())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('So sánh cấu trúc dễ nhầm'));
    await tester.pumpAndSettle();
    expect(find.text('NGHIA A'), findsOneWidget);
    expect(find.text('被字句'), findsOneWidget);
    expect(find.textContaining('KET LUAN SO SANH'), findsOneWidget);
    await tester.tap(find.textContaining('Ví dụ từ dễ đến khó'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dễ · CHO DEM'), findsOneWidget);
    expect(find.textContaining('Khó · HOI THOAI'), findsOneWidget);
    await tester.tap(find.textContaining('Lỗi người Việt hay mắc'));
    await tester.pumpAndSettle();
    expect(find.text('✗ 我把錢給。'), findsOneWidget);
    expect(find.text('✓ 我把錢給你了。'), findsOneWidget);
  });

  testWidgets('v2: dap an luyen tap AN den khi bam "Xem dap an"', (tester) async {
    await _open(tester, _dio(() async => _json(_deep())));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Luyện tập nhanh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CAU HOI LUYEN TAP 1'), findsOneWidget);
    expect(find.text('A. LUA CHON AA'), findsOneWidget); // 3 lua chon trac nghiem hien san
    expect(find.text('C. LUA CHON CC'), findsOneWidget);
    expect(find.textContaining('DAP AN 1'), findsNothing);
    await tester.tap(find.byKey(const Key('practice_show_0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đáp án: B. DAP AN 1'), findsOneWidget);
    expect(find.text('GIAI THICH DAP AN 1'), findsOneWidget);
    expect(find.textContaining('DAP AN 2'), findsNothing); // cau 2 van an
  });

  testWidgets('man cho hien thong diep "Dang soan bai giang chi tiet... (lan dau khoang 30 giay)"', (tester) async {
    final c = Completer<ResponseBody>();
    await _open(tester, _dio(() => c.future));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Đang soạn bài giảng chi tiết… (lần đầu khoảng 30 giây)'), findsOneWidget);
    c.complete(_json(_deep()));
    await tester.pumpAndSettle();
    expect(find.text('Đang soạn bài giảng chi tiết… (lần đầu khoảng 30 giây)'), findsNothing);
    expect(find.text('TOM TAT NGAN GON'), findsOneWidget);
  });

  testWidgets('du lieu CU (khong co version) van hien dung nhu truoc', (tester) async {
    await _open(tester, _dio(() async => _json({
          'definition': 'DINH NGHIA CU', 'formula': 'S+V', 'examples': [{'text': '我吃飯。', 'meaning': 'Toi an com.'}],
          'comparison': '', 'common_mistakes': '', 'exceptions': '',
        })));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('DINH NGHIA CU'), findsOneWidget);
    expect(find.text('ĐỊNH NGHĨA'), findsOneWidget);
    expect(find.text('TÓM TẮT'), findsNothing);
  });

  testWidgets('v2 sai kieu (diem chu y la chuoi, loi la so, practice null) -> KHONG crash, van co tom tat', (tester) async {
    await _open(tester, _dio(() async => _json({
          'version': 2, 'summary': 'TOM TAT SONG SOT', 'nuance': 'chuoi', 'formula_detail': [1, 2],
          'attention_points': ['chuoi tho', 5, null, {'title': 'T', 'explanation': 'E', 'example': 'cau vi du'}],
          'learner_mistakes': [1, 'x', {'wrong': 'a'}], 'comparison_table': 7,
          'examples': ['cau tho', 9, {'text': ''}], 'practice': null,
        })));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('TOM TAT SONG SOT'), findsOneWidget);
    await tester.tap(find.textContaining('Điểm cần chú ý'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('E'), findsWidgets);
  });

  testWidgets('het luot TAO MOI bai giang (403 feature=grammar_deep) -> hien thong diep rieng cua backend', (tester) async {
    await _open(tester, _dio(() async => _json({
          'detail': {'code': 'QUOTA_EXCEEDED', 'feature': 'grammar_deep', 'limit': 5, 'message': 'Ban da tao 5 bai giang moi hom nay.'}
        }, 403)));
    await tester.pumpAndSettle();
    expect(find.text('Ban da tao 5 bai giang moi hom nay.'), findsOneWidget);
  });

  testWidgets('403 quota chung van hien thong diep cu', (tester) async {
    await _open(tester, _dio(() async => _json({'detail': {'code': 'QUOTA_EXCEEDED', 'feature': 'tool'}}, 403)));
    await tester.pumpAndSettle();
    expect(find.textContaining('hết lượt miễn phí'), findsOneWidget);
  });

  group('Báo lỗi bài giảng + cảnh báo AI', () {
    final calls = <RequestOptions>[];
    Dio recDio({int reportStatus = 200}) => Dio()
      ..httpClientAdapter = _Adapter(() async => _json(_deep())) // dummy, bi thay boi interceptor ben duoi
      ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
        calls.add(o);
        if (o.path.endsWith('/report')) {
          reportStatus == 200
              ? h.resolve(Response(requestOptions: o, statusCode: 200, data: {'ok': true}))
              : h.reject(DioException(requestOptions: o, type: DioExceptionType.badResponse,
                  response: Response(requestOptions: o, statusCode: reportStatus)));
        } else {
          h.resolve(Response(requestOptions: o, statusCode: 200, data: _deep()));
        }
      }));

    setUp(calls.clear);

    testWidgets('cuoi bai co dong canh bao AI va nut Bao loi', (tester) async {
      await _open(tester, recDio());
      await tester.pumpAndSettle();
      expect(find.text('Bài giảng do AI soạn, có thể có sai sót'), findsOneWidget);
      expect(find.byKey(const Key('report_button')), findsOneWidget);
      expect(find.text('Báo lỗi bài giảng'), findsOneWidget);
    });

    testWidgets('bam Bao loi -> nhap mo ta -> gui dung endpoint + noi dung, hien thong bao cam on', (tester) async {
      await _open(tester, recDio());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report_note')), 'Câu 我吃了飯了 thực ra đúng');
      await tester.tap(find.byKey(const Key('report_send')));
      await tester.pumpAndSettle();
      final rep = calls.where((c) => c.path.endsWith('/translate/tools/grammar/report')).toList();
      expect(rep, hasLength(1));
      expect(rep.first.data, {'structure_key': '把字句', 'prompt_version': null, 'note': 'Câu 我吃了飯了 thực ra đúng'});
      expect(rep.first.headers['Authorization'], 'Bearer tok');
      expect(find.text('Đã gửi báo lỗi. Cảm ơn bạn!'), findsOneWidget);
    });

    testWidgets('mo ta qua ngan -> bao loi nhap, KHONG gui', (tester) async {
      await _open(tester, recDio());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report_note')), 'a');
      await tester.tap(find.byKey(const Key('report_send')));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng mô tả ngắn chỗ bị sai'), findsOneWidget);
      expect(calls.where((c) => c.path.endsWith('/report')), isEmpty);
    });

    testWidgets('huy -> khong gui; gui loi mang -> thong bao that bai, khong crash', (tester) async {
      await _open(tester, recDio(reportStatus: 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.path.endsWith('/report')), isEmpty);
      await tester.tap(find.byKey(const Key('report_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('report_note')), 'abc xyz');
      await tester.tap(find.byKey(const Key('report_send')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Chưa gửi được báo lỗi, thử lại nhé!'), findsOneWidget);
    });
  });

  test('parseDeepGrammar: payload rong/sai kieu khong nem loi', () {
    final r = parseDeepGrammar({});
    expect(r['summary'], '');
    expect((r['points'] as List), isEmpty);
    expect((r['practice'] as List), isEmpty);
    final r2 = parseDeepGrammar({'definition': 'D', 'examples': 'khong phai list', 'attention_points': {'a': 1}});
    expect(r2['summary'], 'D');
    expect((r2['examples'] as List), isEmpty);
  });
}
