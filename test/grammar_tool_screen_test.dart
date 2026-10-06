// Bug production (2026-10-06) — "Học → Năng lực → bấm chọn 1 điểm ngữ pháp → màn hình TRẮNG
// HOÀN TOÀN, không nút quay lại". Tái hiện THẬT (không đoán) bằng widget test: AI
// (response_format=json_object) chỉ đảm bảo JSON hợp lệ cú pháp, KHÔNG đảm bảo đúng schema đã
// mô tả trong GRAMMAR_TOOL_PROMPT (app/services/openai_service.py::explain_grammar_tool —
// json.loads() trả thẳng, không validate) — "examples" có thể là List<String> thay vì đúng
// List<Map{text,meaning}>, gây type-cast exception NGAY TRONG build() (Dart đánh giá hết tham
// số trước khi gọi Scaffold(...), nên AppBar/nút back cũng KHÔNG BAO GIỜ được tạo).
//
// KHÔNG phải regression của commit F (mastery CTA) hay "Hôm nay" — file này chưa từng bị 2
// thay đổi đó đụng tới (xem git log), và live_chat_screen.dart đã mở màn này với initialQuery
// y hệt từ trước. Lỗi tiềm ẩn có sẵn, chỉ lần này mới bị trúng (xem báo cáo điều tra).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/tools/presentation/screens/grammar_tool_screen.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Object response;
  _FakeAdapter(this.response);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    return ResponseBody.fromString(jsonEncode(response), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

Dio _dio(Object response) {
  final d = Dio();
  d.httpClientAdapter = _FakeAdapter(response);
  return d;
}

/// Mở GrammarToolScreen QUA Navigator.push THẬT (giống production — mastery_profile_tab.dart/
/// live_chat_screen.dart đều push, không bao giờ dùng làm route gốc) để có 1 route PHÍA DƯỚI
/// trong stack — chỉ khi đó AppBar mới tự thêm nút back thật (Navigator.canPop == true).
Future<void> _pushGrammarTool(WidgetTester tester, {String? initialQuery, required Object response}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) => TextButton(
    onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => GrammarToolScreen(
      initialQuery: initialQuery, dio: _dio(response), readToken: () async => 'tok',
    ))),
    child: const Text('open'),
  )))));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('examples là List<String> lệch schema -> KHÔNG crash, vẫn hiện nội dung, vẫn có nút back',
      (tester) async {
    await _pushGrammarTool(tester, initialQuery: 'Giải thích cấu trúc 把 trong tiếng Trung', response: {
      'definition': 'Cấu trúc 把 dùng để...', 'formula': 'S + 把 + O + V',
      'examples': ['我把書放在桌子上。', '他把門關上了。'], // LECH schema — day la nguyen nhan that da tai hien
      'comparison': '', 'common_mistakes': '', 'exceptions': '',
    });

    expect(tester.takeException(), isNull); // KHONG con crash nhu truoc khi sua
    expect(find.text('Cấu trúc 把 dùng để...'), findsOneWidget);
    expect(find.text('我把書放在桌子上。'), findsOneWidget); // van HIEN noi dung AI tra ve, khong am tham bo
    expect(find.byTooltip('Back'), findsOneWidget); // nut back THAT, tu AppBar
  });

  testWidgets('dữ liệu hoàn toàn sai kiểu (definition là số, examples là String trần) -> KHÔNG crash, vẫn có back',
      (tester) async {
    // _parseResult() du suc tu suy bien an toan (.toString()/kiem tra is List) cho ca truong
    // hop nay — khong roi vao nhanh "card loi rieng" (do danh cho truong hop vuot qua CA
    // _parseResult(), xem test duoi) nhung VAN PHAI khong crash va van co nut back.
    await _pushGrammarTool(tester, initialQuery: 'test', response: {
      'definition': 123, 'formula': null, 'examples': 'không phải list',
      'comparison': '', 'common_mistakes': '', 'exceptions': '',
    });

    expect(tester.takeException(), isNull);
    expect(find.text('123'), findsOneWidget); // suy bien an toan: .toString() thay vi crash
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('AI trả JSON object hoàn toàn rỗng {} -> không crash, vẫn có back', (tester) async {
    // Khong co field nao ca — truong hop bien, xac nhan _parseResult()/_buildResultCard() KHONG
    // gia dinh bat ky key nao PHAI ton tai.
    await _pushGrammarTool(tester, initialQuery: 'test', response: <String, dynamic>{});

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('đúng schema như prompt mô tả -> hiện đầy đủ, hành vi cũ không đổi', (tester) async {
    await _pushGrammarTool(tester, initialQuery: 'test', response: {
      'definition': 'Định nghĩa đúng chuẩn', 'formula': 'S + 把 + O + V',
      'examples': [
        {'text': '我把書放在桌子上。', 'meaning': 'Tôi để sách lên bàn.'},
      ],
      'comparison': 'So sánh ABC', 'common_mistakes': 'Lỗi hay gặp XYZ', 'exceptions': 'Ngoại lệ DEF',
    });

    expect(tester.takeException(), isNull);
    expect(find.text('Định nghĩa đúng chuẩn'), findsOneWidget);
    expect(find.text('我把書放在桌子上。'), findsOneWidget);
    expect(find.text('Tôi để sách lên bàn.'), findsOneWidget);
    expect(find.text('So sánh ABC'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('bấm quick prompt thủ công (không qua initialQuery) với dữ liệu lệch -> cũng không crash',
      (tester) async {
    // Xac nhan loi KHONG rieng cho initialQuery — luong thu cong (vd tu man Cong cu) di CHUNG
    // 1 ham _ask()/_buildResultCard() nen cung bi/cung duoc sua nhu nhau.
    await _pushGrammarTool(tester, response: {
      'definition': 'OK', 'formula': '', 'examples': ['chỉ 1 chuỗi, không phải map'],
      'comparison': '', 'common_mistakes': '', 'exceptions': '',
    });
    await tester.tap(find.text('Giải thích cấu trúc "把" sentence'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
