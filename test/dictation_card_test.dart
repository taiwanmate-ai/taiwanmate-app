// Thẻ NGHE CHÉP (kind = dictation) + bước "Luyện viết": 3 chế độ nhập, chấm trên máy, chỉ chỗ sai, giải thích biến điệu, nghe chậm 0,75×,
// nhớ chế độ / cài đặt thanh điệu; bước rỗng bị bỏ; app báo caps 'dictation'.
import 'dart:convert';
import 'dart:io';

import 'package:chinesemate/features/lesson_v2/dictation/dictation_card.dart';
import 'package:chinesemate/features/lesson_v2/lesson_runner.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lesson_v2_screen_test.dart' as base;

class AudioApi implements LessonV2Api {
  final played = <Map<String, dynamic>>[];
  @override
  Future<void> playAudio(Map<String, dynamic>? a) async => played.add(Map<String, dynamic>.from(a ?? const {}));
  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body) => throw UnimplementedError();
  @override
  Future<void> reportQuestion(String questionId, {String? reason}) async {}
  @override
  Future<Map<String, dynamic>> submitGame(int matched, int misses) => throw UnimplementedError();
}

final _items = (jsonDecode(File('test/fixtures/dictation_normalize_cases.json').readAsStringSync()) as Map)['items'] as Map;

/// Câu nghe chép như server gửi (payload = item của test vector + thẻ chữ + âm thanh tĩnh).
Map<String, dynamic> dictQ(String id, String item, {List<String>? extraTiles}) {
  final it = Map<String, dynamic>.from(_items[item] as Map);
  final chars = [for (final c in it['chars'] as List) (c as Map)['h'] as String];
  return {
    'id': id,
    'kind': 'dictation',
    'word_id': null,
    'difficulty': 3,
    'payload': {
      ...it,
      'prompt': 'Nghe và chép lại câu',
      'audio': {'type': 'audio', 'text': it['answer_text'], 'lang': 'zh-TW', 'voice': 'B', 'url': '/static/audio/lesson/zh/x.mp3'},
      'vi': 'Mai tôi đi khám bệnh.',
      'tiles': [...chars.reversed, ...(extraTiles ?? const ['名', '以'])],
      'modes': ['tiles', 'pinyin', 'hanzi'],
    },
  };
}

Future<(AudioApi, List<(bool, int)>)> pumpCard(WidgetTester tester, Map<String, dynamic> q, {String? level = 'A2'}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = AudioApi();
  final done = <(bool, int)>[];
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DictationCard(question: q, api: api, level: level, onDone: (c, ms) => done.add((c, ms)))))));
  await tester.pumpAndSettle();
  return (api, done);
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Chạm thẻ chữ theo thứ tự [chars] (thẻ đã chạm biến khỏi hàng dưới).
Future<void> tapTiles(WidgetTester tester, List<String> chars) async {
  for (final c in chars) {
    final f = find.descendant(of: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('dictation_tile_')), matching: find.text(c));
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }
}

/// Các ô so sánh có op [op] (key 'dictation_op_<vị trí>_<op>').
Finder opChips(String op) => find.byWidgetPredicate((w) => w.key is ValueKey<String> && RegExp('^dictation_op_\\d+_$op\$').hasMatch((w.key as ValueKey<String>).value));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('A2: mặc định "Chọn chữ", tự phát 1 lần ở tốc độ thường; chọn đúng thứ tự -> Chính xác', (tester) async {
    final (api, done) = await pumpCard(tester, dictQ('d1', 'yisheng'));
    expect(api.played.single['text'], '我明天要去看醫生。');
    expect(api.played.single.containsKey('rate'), isFalse);
    expect(find.byKey(const Key('dictation_answer_area')), findsOneWidget);
    expect(find.byKey(const Key('dictation_input')), findsNothing);
    await tapTiles(tester, '我明天要去看醫生'.split(''));
    await tap(tester, 'dictation_check_btn');
    expect(find.text('✔ Chính xác!'), findsOneWidget);
    expect(find.text('Mai tôi đi khám bệnh.'), findsOneWidget);
    await tap(tester, 'lesson_next_btn');
    expect(done.single.$1, isTrue);
  });

  testWidgets('nghe chậm gửi rate 0.75 (cùng file âm thanh tĩnh)', (tester) async {
    final (api, _) = await pumpCard(tester, dictQ('d1', 'yisheng'));
    await tap(tester, 'dictation_play_slow');
    expect(api.played.last['rate'], 0.75);
    expect(api.played.last['url'], '/static/audio/lesson/zh/x.mp3');
  });

  testWidgets('chọn chữ đồng âm sai -> Chưa đúng + chỉ đúng chỗ sai (名→明)', (tester) async {
    final (_, done) = await pumpCard(tester, dictQ('d1', 'yisheng'));
    await tapTiles(tester, '我名天要去看醫生'.split(''));
    await tap(tester, 'dictation_check_btn');
    expect(find.textContaining('✗ Chưa đúng (88%)'), findsOneWidget);
    expect(opChips('sub'), findsOneWidget);
    expect(find.text('名→明'), findsOneWidget);
    await tap(tester, 'lesson_next_btn');
    expect(done.single.$1, isFalse);
  });

  testWidgets('gõ pinyin không dấu: đúng kèm nhắc thanh; app nhớ chế độ', (tester) async {
    await pumpCard(tester, dictQ('d1', 'yisheng'));
    await tap(tester, 'dictation_mode_pinyin');
    await tester.enterText(find.byKey(const Key('dictation_input')), 'wo mingtian yao qu kan yisheng');
    await tester.pumpAndSettle();
    await tap(tester, 'dictation_check_btn');
    expect(find.text('✔ Đúng — để ý thanh điệu nhé'), findsWidgets);
    expect(opChips('tone_warn'), findsWidgets);
    expect((await SharedPreferences.getInstance()).getString(kDictationModePref), 'pinyin');
  });

  testWidgets('bắt buộc đúng thanh + gõ theo cách đọc ni2 hao3 -> sai, giải thích 3+3', (tester) async {
    SharedPreferences.setMockInitialValues({kDictationModePref: 'pinyin', kDictationStrictTonesPref: true});
    await pumpCard(tester, dictQ('d2', 'nihao'));
    expect(tester.widget<Switch>(find.byKey(const Key('dictation_strict_switch'))).value, isTrue);
    await tester.enterText(find.byKey(const Key('dictation_input')), 'ni2 hao3 wo3 jiao4 xiao3 an1');
    await tester.pumpAndSettle();
    await tap(tester, 'dictation_check_btn');
    expect(find.textContaining('✗ Chưa đúng'), findsOneWidget);
    expect(find.text('💡 Đọc là ní hǎo, nhưng viết vẫn là nǐ hǎo (3+3).'), findsOneWidget);
  });

  testWidgets('B1: mặc định gõ chữ Hán (có hướng dẫn bàn phím); gõ giản thể -> đúng kèm nhắc phồn thể', (tester) async {
    await pumpCard(tester, dictQ('d1', 'yisheng'), level: 'B1');
    expect(find.byKey(const Key('dictation_keyboard_hint')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dictation_input')), '我明天要去看医生');
    await tester.pumpAndSettle();
    await tap(tester, 'dictation_check_btn');
    expect(find.text('✔ Chính xác!'), findsOneWidget);
    expect(find.byKey(const Key('dictation_simplified_note')), findsOneWidget);
  });

  testWidgets('chưa nhập gì -> nút Kiểm tra bị khóa', (tester) async {
    await pumpCard(tester, dictQ('d1', 'yisheng'));
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('dictation_check_btn'))).onPressed, isNull);
  });

  test('bước Luyện viết rỗng bị bỏ; app báo caps dictation', () {
    final s = {
      'steps': [
        {'type': 'practice', 'questions': [{}]},
        {'type': 'writing', 'questions': []},
        {'type': 'summary'},
      ]
    };
    expect(visibleSteps(s).map((x) => x['type']), ['practice', 'summary']);
    expect(kSessionCaps.split(','), containsAll(['arrange_sentence', 'situation_v1', 'dictation']));
  });

  testWidgets('phiên có bước Luyện viết sau luyện tập: làm xong, kết quả câu nghe chép được gửi lên', (tester) async {
    final session = base.buildSession();
    final steps = [for (final s in session['steps'] as List) Map<String, dynamic>.from(s as Map)];
    final i = steps.indexWhere((s) => s['type'] == 'practice');
    steps.insert(i + 1, {'type': 'writing', 'title': 'Luyện viết', 'questions': [dictQ('d1', 'yisheng')]});
    session['steps'] = steps;
    (session['unit'] as Map)['level'] = 'A2';
    final api = base.FakeApi(session);
    await base.pump(tester, api);
    await base.tapKey(tester, 'lesson_start_btn');
    await base.tapKey(tester, 'word_next');
    await base.tapKey(tester, 'word_next');
    await base.tapKey(tester, 'lesson_opt_a');
    await base.tapKey(tester, 'lesson_next_btn');
    for (var k = 0; k < 2; k++) {
      await base.tapKey(tester, 'lesson_opt_a');
      await base.tapKey(tester, 'lesson_next_btn');
    }
    expect(find.text('Luyện viết'), findsOneWidget);
    expect(api.audio, contains('我明天要去看醫生。'));
    await tapTiles(tester, '我明天要去看醫生'.split(''));
    await base.tapKey(tester, 'dictation_check_btn');
    await base.tapKey(tester, 'lesson_next_btn');
    await base.tapKey(tester, 'match60_skip');
    final res = (api.submitted!['results'] as List).cast<Map<String, dynamic>>();
    expect(res.map((r) => '${r['question_id']}:${r['correct']}:${r['attempt']}'), contains('d1:true:1'));
  });
}
