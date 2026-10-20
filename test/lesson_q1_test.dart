import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lesson_v2_screen_test.dart' show FakeApi, buildSession, choiceQ, pump, tapKey;

Map<String, dynamic> arrangeQ(String id, {String wordId = 'w1'}) => {
      'id': id,
      'kind': 'arrange_sentence',
      'word_id': wordId,
      'difficulty': 3,
      'payload': {
        'prompt': 'Sắp xếp các từ thành câu',
        'stem': {'type': 'text', 'text': 'Hôm nay tôi bận.'},
        'pieces': [
          {'id': 'p3', 'text': '很', 'sub': 'hěn'},
          {'id': 'p1', 'text': '我', 'sub': 'wǒ'},
          {'id': 'p4', 'text': '忙', 'sub': 'máng'},
          {'id': 'p2', 'text': '今天', 'sub': 'jīntiān'},
        ],
        'answer': ['p1', 'p2', 'p3', 'p4'],
        'answer_text': '我今天很忙',
        'accepts': ['我今天很忙'],
        'sep': '',
        'suffix': '。',
        'explain': 'Câu đúng: 我今天很忙。 (wǒ jīntiān hěn máng) = Hôm nay tôi bận.',
        'word': {'id': wordId, 'text': '忙', 'pron': 'máng', 'meaning': 'bận'},
      },
    };

Map<String, dynamic> sessionWith(List<Map<String, dynamic>> practice, {Map<String, dynamic>? wordExtra}) {
  final s = buildSession();
  final steps = (s['steps'] as List);
  final practiceStep = steps.firstWhere((x) => x['type'] == 'practice') as Map<String, dynamic>;
  practiceStep['questions'] = practice;
  if (wordExtra != null) {
    final nw = steps.firstWhere((x) => x['type'] == 'new_words') as Map<String, dynamic>;
    final word = ((nw['pairs'] as List).first['words'] as List).first as Map<String, Object>;
    wordExtra.forEach((k, v) => word[k] = v as Object);
  }
  return s;
}

Future<void> toPractice(WidgetTester tester) async {
  await tapKey(tester, 'lesson_start_btn');
  await tapKey(tester, 'word_next');
  await tapKey(tester, 'word_next');
  await tapKey(tester, 'lesson_opt_a');
  await tapKey(tester, 'lesson_next_btn');
}

void main() {
  testWidgets('chon SAI: hien giai thich theo dap an da chon (explain_wrong), chon DUNG: giai thich chung', (tester) async {
    final q = choiceQ('p2', 'meaning_word', 'w2');
    (q['payload'] as Map<String, dynamic>)['explain_wrong'] = {
      'b': 'Bạn chọn «喝» hē = uống. Đáp án đúng: «吃» chī = ăn.',
      'c': 'Bạn chọn «水» shuǐ = nước. Đáp án đúng: «吃» chī = ăn.',
    };
    await pump(tester, FakeApi(sessionWith([q])));
    await toPractice(tester);
    await tapKey(tester, 'lesson_opt_c');
    expect(find.text('✗ Chưa đúng'), findsOneWidget);
    expect(find.text('Bạn chọn «水» shuǐ = nước. Đáp án đúng: «吃» chī = ăn.'), findsOneWidget);
    expect(find.text('吃 chī = ăn'), findsNothing);
  });

  testWidgets('chon SAI nhung khong co explain_wrong (server cu): dung giai thich chung; chon dung: giai thich chung', (tester) async {
    await pump(tester, FakeApi(sessionWith([choiceQ('p2', 'meaning_word', 'w2')])));
    await toPractice(tester);
    await tapKey(tester, 'lesson_opt_b');
    expect(find.text('✗ Chưa đúng'), findsOneWidget);
    expect(find.text('吃 chī = ăn'), findsOneWidget);
  });

  testWidgets('sap xep tu thanh cau: nut Kiem tra chi bat khi da dat het; dat dung thu tu -> dung', (tester) async {
    final api = FakeApi(sessionWith([arrangeQ('a1')]));
    await pump(tester, api);
    await toPractice(tester);
    expect(find.byKey(const Key('arrange_stem')), findsOneWidget);
    expect(find.text('Hôm nay tôi bận.'), findsOneWidget);
    var check = tester.widget<ElevatedButton>(find.byKey(const Key('arrange_check_btn')));
    expect(check.onPressed, isNull);
    for (final id in ['p1', 'p2', 'p3']) {
      await tapKey(tester, 'arrange_piece_$id');
    }
    check = tester.widget<ElevatedButton>(find.byKey(const Key('arrange_check_btn')));
    expect(check.onPressed, isNull); // con thieu 1 manh
    await tapKey(tester, 'arrange_piece_p4');
    await tapKey(tester, 'arrange_check_btn');
    expect(find.text('✔ Chính xác!'), findsOneWidget);
    expect(find.textContaining('Câu đúng: 我今天很忙。'), findsOneWidget);
    await tapKey(tester, 'lesson_next_btn');
  });

  testWidgets('sap xep sai thu tu -> sai + giai thich dap an dung; cham manh da dat de bo ra', (tester) async {
    final api = FakeApi(sessionWith([arrangeQ('a1')]));
    await pump(tester, api);
    await toPractice(tester);
    await tapKey(tester, 'arrange_piece_p2');
    await tapKey(tester, 'arrange_placed_p2'); // tra ve khay
    expect(find.byKey(const Key('arrange_piece_p2')), findsOneWidget);
    for (final id in ['p2', 'p1', 'p3', 'p4']) {
      await tapKey(tester, 'arrange_piece_$id');
    }
    await tapKey(tester, 'arrange_check_btn');
    expect(find.text('✗ Chưa đúng'), findsOneWidget);
    expect(find.textContaining('Câu đúng: 我今天很忙。'), findsOneWidget);
    expect(find.textContaining('quay lại sau'), findsOneWidget);
    await tapKey(tester, 'lesson_next_btn');
    // cau sai duoc ghi nhan la sai
  });

  testWidgets('the tu hien ghi chu khi co, khong hien khi khong co', (tester) async {
    await pump(tester, FakeApi(sessionWith([choiceQ('p2', 'meaning_word', 'w2')], wordExtra: {'note': 'Ở Đài Loan thường nói 吃飯.'})));
    await tapKey(tester, 'lesson_start_btn');
    expect(find.byKey(const Key('word_note')), findsOneWidget);
    expect(find.text('Ở Đài Loan thường nói 吃飯.'), findsOneWidget);
    await tapKey(tester, 'word_next');
    expect(find.byKey(const Key('word_note')), findsNothing); // tu thu 2 khong co ghi chu
  });
}
