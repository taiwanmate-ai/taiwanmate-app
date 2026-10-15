import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_screen.dart';

class FakeApi implements LessonV2Api {
  Map<String, dynamic> session;
  Map<String, dynamic>? submitted;
  final reports = <String>[];
  final audio = <String?>[];
  bool failFirstSubmit = false;
  int submitCalls = 0;
  bool disabled = false;
  FakeApi(this.session);

  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) async {
    if (disabled) throw LessonV2Disabled();
    return session;
  }

  @override
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body) async {
    submitCalls++;
    if (failFirstSubmit && submitCalls == 1) throw Exception('net');
    submitted = body;
    return {
      'duplicate': false,
      'score': {'correct': 3, 'total': 4, 'percent': 75},
      'can_do': ['Gọi được món ăn'],
      'wrong_word_ids': ['w1'],
      'due_tomorrow': 5,
      'xp_gained': 30,
      'total_xp': 30,
      'streak_days': 2,
      'progress': {'completed_units': 4, 'total_units': 12, 'level': 'A1'},
      'next_unit_id': 'next',
      'level_completed': false,
    };
  }

  @override
  Future<void> reportQuestion(String questionId, {String? reason}) async => reports.add('$questionId|$reason');

  @override
  Future<Map<String, dynamic>> submitGame(int matched, int misses) async => {'ok': true, 'score': matched * 10, 'best': matched * 10, 'is_new_best': true, 'xp_gained': 3};

  @override
  Future<void> playAudio(Map<String, dynamic>? a) async => audio.add(a?['text'] as String?);
}

Map<String, dynamic> choiceQ(String id, String kind, String wordId, {String answer = 'a', String stemType = 'text'}) => {
      'id': id,
      'kind': kind,
      'word_id': wordId,
      'difficulty': 1,
      'payload': {
        'prompt': 'Chọn từ đúng',
        'stem': stemType == 'audio' ? {'type': 'audio', 'text': '吃', 'lang': 'zh-TW'} : {'type': 'text', 'text': 'ăn'},
        'options': [
          {'id': 'a', 'text': '吃'},
          {'id': 'b', 'text': '喝'},
          {'id': 'c', 'text': '水'},
          {'id': 'd', 'text': '茶'},
        ],
        'answer': answer,
        'explain': '吃 chī = ăn',
        'word': {'id': wordId, 'text': '吃', 'pron': 'chī', 'meaning': 'ăn'},
      },
    };

Map<String, dynamic> buildSession() => {
      'session_id': 'S1',
      'unit': {'id': 'u1', 'order': 4, 'total_units': 12, 'topic_vi': 'Ẩm thực', 'topic_zh': '飲食', 'level': 'A1', 'language': 'zh'},
      'steps': [
        {'type': 'intro', 'title': 'Ẩm thực', 'title_target': '飲食', 'goals': ['Gọi được món ăn'], 'scene': 'Quán ăn nhỏ', 'estimated_minutes': 8},
        {'type': 'review', 'questions': []},
        {
          'type': 'new_words',
          'pairs': [
            {
              'words': [
                {'id': 'w1', 'text': '吃', 'pron': 'chī', 'meaning': 'ăn', 'example': '我吃麵。', 'example_vi': 'Tôi ăn mì.', 'audio': {'text': '吃', 'lang': 'zh-TW'}, 'example_audio': {'text': '我吃麵。', 'lang': 'zh-TW'}},
                {'id': 'w2', 'text': '喝', 'pron': 'hē', 'meaning': 'uống', 'example': '', 'example_vi': '', 'audio': {'text': '喝', 'lang': 'zh-TW'}, 'example_audio': null},
              ],
              'micro': choiceQ('m1', 'micro_pick', 'w1'),
              'word_ids': ['w1', 'w2'],
            }
          ]
        },
        {
          'type': 'practice',
          'questions': [choiceQ('p1', 'listen_meaning', 'w1', stemType: 'audio'), choiceQ('p2', 'meaning_word', 'w2')]
        },
        {
          'type': 'minigame',
          'game': 'match60',
          'duration': 60,
          'skippable': true,
          'pairs': [
            for (var i = 0; i < 6; i++) {'word_id': 'g$i', 'left': 'L$i', 'right': 'R$i'}
          ]
        },
      ],
      'retry': {
        'alts': {
          'w1': [choiceQ('a1', 'meaning_word', 'w1')],
        }
      },
    };

Future<void> pump(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: LessonV2Screen(unitId: 'u1', api: api))));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('intro hien muc tieu, khong co nut gi ngoai Bat dau', (tester) async {
    final api = FakeApi(buildSession());
    await pump(tester, api);
    expect(find.text('Ẩm thực'), findsWidgets);
    expect(find.text('✦ Gọi được món ăn'), findsOneWidget);
    expect(find.byKey(const Key('lesson_start_btn')), findsOneWidget);
  });

  testWidgets('luong day du: tu moi theo cap -> hoi nhanh -> luyen tap (sai thi hoi lai) -> mini-game bo qua -> ket thuc + gui dap an', (tester) async {
    final api = FakeApi(buildSession());
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    // the tu 1, the tu 2
    expect(find.byKey(const Key('word_text')), findsOneWidget);
    expect(find.text('吃'), findsOneWidget);
    await tapKey(tester, 'word_next');
    expect(find.text('喝'), findsOneWidget);
    await tapKey(tester, 'word_next');
    // cau hoi nhanh NGAY (m1), chon dung 'a'
    expect(find.text('Kiểm tra nhanh · cặp 1/1'), findsOneWidget);
    await tapKey(tester, 'lesson_opt_a');
    expect(find.text('✔ Chính xác!'), findsOneWidget);
    await tapKey(tester, 'lesson_next_btn');
    // luyen tap: p1 nghe -> chon SAI ('b') -> se quay lai bang dang khac
    expect(find.byKey(const Key('lesson_audio_btn')), findsOneWidget);
    expect(api.audio, contains('吃')); // tu dong phat audio
    expect(find.text('1/2'), findsOneWidget); // 2 cau; cau lam lai se duoc chen khi sai
    await tapKey(tester, 'lesson_opt_b');
    expect(find.text('✗ Chưa đúng'), findsOneWidget);
    expect(find.textContaining('quay lại sau'), findsOneWidget);
    await tapKey(tester, 'lesson_next_btn');
    // p2 dung
    await tapKey(tester, 'lesson_opt_a');
    await tapKey(tester, 'lesson_next_btn');
    // cau lam lai (a1, dang khac), dung
    expect(find.text('Làm lại câu đã sai — thử cách khác nhé'), findsOneWidget);
    await tapKey(tester, 'lesson_opt_a');
    await tapKey(tester, 'lesson_next_btn');
    // mini-game: bo qua
    expect(find.byKey(const Key('match60_start')), findsOneWidget);
    await tapKey(tester, 'match60_skip');
    // man ket thuc
    expect(find.byKey(const Key('summary_title')), findsOneWidget);
    expect(find.text('Đúng 3/4 câu (75%)'), findsOneWidget);
    expect(find.textContaining('Mai ôn lại 5 từ'), findsOneWidget);
    expect(find.textContaining('+30 XP'), findsOneWidget);
    expect(find.textContaining('Chặng A1: 4/12'), findsOneWidget);
    // gui dung ket qua: m1 dung(1), p1 sai(1), p2 dung(1), a1 dung(2)
    final res = (api.submitted!['results'] as List).cast<Map<String, dynamic>>();
    expect(api.submitted!['session_id'], 'S1');
    expect(res.map((r) => '${r['question_id']}:${r['correct']}:${r['attempt']}').toList(), ['m1:true:1', 'p1:false:1', 'p2:true:1', 'a1:true:2']);
  });

  testWidgets('bao loi cau hoi goi API voi ly do', (tester) async {
    final api = FakeApi(buildSession());
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    await tapKey(tester, 'word_next');
    await tapKey(tester, 'word_next');
    await tapKey(tester, 'lesson_opt_a');
    await tapKey(tester, 'lesson_report_btn');
    await tester.tap(find.byKey(const Key('report_reason_Đáp án sai')));
    await tester.pumpAndSettle();
    expect(api.reports, ['m1|Đáp án sai']);
    expect(find.textContaining('Cảm ơn bạn'), findsOneWidget);
  });

  testWidgets('mini-game: bat dau, ghep dung, ket thuc som -> gui diem va hien ket qua', (tester) async {
    final api = FakeApi(buildSession());
    final s = buildSession();
    s['steps'] = [s['steps'].last]; // chi mini-game
    api.session = s;
    await pump(tester, api);
    await tapKey(tester, 'match60_start');
    final id = ['g0', 'g1', 'g2', 'g3', 'g4', 'g5'].firstWhere((i) => find.byKey(Key('g_l_$i')).evaluate().isNotEmpty);
    await tapKey(tester, 'g_l_$id');
    await tapKey(tester, 'g_r_$id');
    expect(find.text('Điểm 10'), findsOneWidget);
    await tapKey(tester, 'match60_end');
    expect(find.byKey(const Key('match60_result')), findsOneWidget);
    expect(find.textContaining('Kỷ lục mới'), findsOneWidget);
  });

  testWidgets('loi luu ket qua: hien nut Thu lai, khong mat dap an', (tester) async {
    final api = FakeApi(buildSession())..failFirstSubmit = true;
    final s = buildSession();
    s['steps'] = [s['steps'].first];
    api.session = s;
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    expect(find.text('Chưa lưu được kết quả. Thử lại nhé.'), findsOneWidget);
    await tapKey(tester, 'lesson_retry_submit');
    expect(find.byKey(const Key('summary_title')), findsOneWidget);
  });

  testWidgets('server tra LESSON_V2_DISABLED -> thong bao, khong crash', (tester) async {
    final api = FakeApi(buildSession())..disabled = true;
    await pump(tester, api);
    expect(find.text('Bài học mới chưa mở cho tài khoản của bạn.'), findsOneWidget);
  });
}
