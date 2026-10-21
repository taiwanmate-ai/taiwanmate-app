import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/stage_unit_list.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';
import 'package:chinesemate/features/lesson_v2/situation/pinyin_chart_screen.dart';
import 'package:chinesemate/features/lesson_v2/situation/pron_test_screen.dart';
import 'package:chinesemate/features/lesson_v2/situation/situation_steps.dart';
import 'package:chinesemate/features/lesson_v2/situation/tone_text.dart';

import 'lesson_v2_screen_test.dart' show FakeApi, pump, tapKey;

class SitApi extends FakeApi implements SituationApi {
  final grades = <String>[];
  final reported = <String>[];
  Map<String, dynamic>? chart;
  List<Map<String, dynamic>> pronQs = [];
  Map<String, dynamic> pronResult = {'passed': true, 'skipped_units': 5};
  (int, int)? pronSent;
  GradeError? gradeFail;
  bool unavailable = false;
  SitApi(super.session);

  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) async {
    if (unavailable) throw SituationUnavailable('Bài này chưa sẵn sàng');
    return super.fetchSession(unitId);
  }

  @override
  Future<Map<String, dynamic>> fetchPinyinChart() async => chart!;
  @override
  Future<Map<String, dynamic>> fetchPronTest() async => {'questions': pronQs, 'pass_ratio': 0.8};
  @override
  Future<Map<String, dynamic>> submitPronTest(int correct, int total) async {
    pronSent = (correct, total);
    return pronResult;
  }

  @override
  Future<void> reportGrade(String attemptId) async => reported.add(attemptId);

  @override
  Future<Map<String, dynamic>> gradeTranslation(String exerciseId, int segmentIdx, String text) async {
    grades.add('$exerciseId|$segmentIdx|$text');
    if (gradeFail != null) throw gradeFail!;
    return {
      'attempt_id': 'att1',
      'scores': {'meaning': 92, 'natural': 80, 'grammar': 95},
      'literal_spots': [{'user_part': 'đi tới công ty', 'issue': 'sát chữ', 'better': 'đi làm'}],
      'natural_version': 'Hôm nay An đi làm.',
      'comment': 'Tốt lắm!',
      'cached': false,
      'quota': {'used': 1, 'limit': 2},
    };
  }
}

Map<String, dynamic> q(String id, String kind, {Map<String, dynamic>? payload}) => {
      'id': id,
      'kind': kind,
      'word_id': null,
      'difficulty': 3,
      'payload': payload ??
          {
            'prompt': 'Hoàn thành hội thoại',
            'stem': {'type': 'text', 'text': 'A：可以用悠遊卡嗎？\nB：＿＿＿'},
            'options': [
              {'id': 'a', 'text': '可以，請刷卡。'},
              {'id': 'b', 'text': '可以嗎，請刷卡。'},
              {'id': 'c', 'text': '用悠遊卡可以不。'},
            ],
            'answer': 'a',
            'explain': 'Đúng: 可以，請刷卡。',
            'explain_wrong': {'b': 'Không lặp 嗎 trong câu trả lời.', 'c': 'Không đặt 不 cuối câu.'},
            'subtype': 'complete_dialogue',
          },
    };

Map<String, dynamic> ex(String zh, String vi, {String py = ''}) => {'zh': zh, 'vi': vi, 'pinyin': py};

Map<String, dynamic> situationSession() => {
      'session_id': 'S9',
      'version': 'situation_v1',
      'unit': {'id': 'u1', 'order': -7, 'total_units': 10, 'topic_vi': 'Mua trà sữa', 'topic_zh': '買珍珠奶茶', 'level': 'A1', 'language': 'zh', 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'kind': 'situation'},
      'steps': [
        {'type': 'intro', 'title': 'Mua trà sữa', 'title_target': '買珍珠奶茶', 'goals': ['Sau bài này bạn gọi được một ly trà sữa.'], 'scene': 'Ở quán trà sữa.', 'estimated_minutes': 11, 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan',
         'characters': [{'zh': '店員', 'vi': 'Nhân viên', 'voice': 'C'}, {'zh': '小安', 'vi': 'An', 'voice': 'B'}]},
        {'type': 'review', 'questions': []},
        {
          'type': 'listen_first',
          'hint': 'Nghe cả đoạn hội thoại trước, chưa cần hiểu hết.',
          'lines': [
            {'i': 0, 'speaker': '店員', 'speaker_vi': 'Nhân viên', 'audio': {'type': 'audio', 'text': '你好，要喝什麼？', 'lang': 'zh-TW', 'voice': 'C'}},
            {'i': 1, 'speaker': '小安', 'speaker_vi': 'An', 'audio': {'type': 'audio', 'text': '我要兩杯珍珠奶茶。', 'lang': 'zh-TW', 'voice': 'B'}},
          ],
        },
        {
          'type': 'new_words',
          'pairs': [
            {
              'words': [
                {'id': 'w1', 'text': '珍珠奶茶', 'pron': 'zhēn zhū nǎi chá', 'meaning': 'trà sữa trân châu', 'han_viet': 'TRÂN CHÂU NÃI TRÀ', 'pos': 'danh từ', 'classifier': '杯', 'note': 'Món nổi tiếng của Đài Loan.',
                 'chunks': [{'zh': '一杯珍珠奶茶', 'vi': 'một ly trà sữa'}], 'entry': 'word', 'separable': false, 'example': '', 'example_vi': '', 'audio': {'text': '珍珠奶茶', 'lang': 'zh-TW'}, 'example_audio': null},
                {'id': 'w2', 'text': '吃飯', 'pron': 'chī fàn', 'meaning': 'ăn cơm', 'han_viet': 'CẬT', 'pos': 'động từ', 'classifier': null, 'note': '', 'chunks': [], 'entry': 'word', 'separable': true,
                 'split_example': {'zh': '我吃了飯', 'vi': 'Mình ăn cơm rồi'}, 'example': '', 'example_vi': '', 'audio': {'text': '吃飯', 'lang': 'zh-TW'}, 'example_audio': null},
                {'id': 'w3', 'text': '悠遊卡', 'pron': 'yōu yóu kǎ', 'meaning': 'thẻ EasyCard', 'han_viet': '', 'pos': 'danh từ', 'entry': 'proper_noun', 'example': '', 'example_vi': '', 'audio': {'text': '悠遊卡', 'lang': 'zh-TW'}},
                {'id': 'w4', 'text': '多少錢', 'pron': 'duō shǎo qián', 'meaning': 'bao nhiêu tiền', 'han_viet': 'ĐA THIỂU TIỀN', 'pos': 'cụm', 'entry': 'fixed_phrase', 'example': '', 'example_vi': '', 'audio': {'text': '多少錢', 'lang': 'zh-TW'}},
              ],
              'micro': null,
              'word_ids': ['w1', 'w2', 'w3', 'w4'],
            }
          ]
        },
        {
          'type': 'dialogue',
          'title': 'Mua trà sữa',
          'lines': [
            {'i': 0, 'speaker': '店員', 'speaker_vi': 'Nhân viên', 'text': '你好，要喝什麼？', 'pinyin': 'nǐ hǎo, yào hē shén me?', 'vi': 'Chào anh, anh uống gì?', 'audio': {'type': 'audio', 'text': '你好，要喝什麼？', 'lang': 'zh-TW', 'voice': 'C'}, 'tokens': [{'t': '你好，要喝什麼？'}]},
            {'i': 1, 'speaker': '小安', 'speaker_vi': 'An', 'text': '我不是越南人。', 'pinyin': 'wǒ bú shì Yuè nán rén.', 'vi': 'Mình không phải người Việt.', 'audio': {'type': 'audio', 'text': '我不是越南人。', 'lang': 'zh-TW', 'voice': 'B'},
             'tokens': [{'t': '我'}, {'t': '不是', 'gloss': {'pinyin': 'bú shì', 'vi': 'không phải là'}}, {'t': '越南人。'}]},
          ],
          'questions': [],
        },
        {
          'type': 'grammar',
          'points': [
            {
              'role': 'main', 'title': 'Số + lượng từ + danh từ', 'function': 'Nói số lượng khi gọi món.',
              'structures': {'formula': 'Số + lượng từ + danh từ', 'examples': [ex('我要兩杯奶茶', 'Cho mình hai ly trà sữa', py: 'wǒ yào liǎng bēi nǎi chá'), ex('你要大杯還是中杯？', 'Anh lấy ly lớn hay vừa?')]},
              'negation': {'rule': 'Phủ định bằng 不 trước động từ.', 'examples': [ex('我不要冰', 'Mình không lấy đá')]},
              'questions': {'rule': 'Hỏi lựa chọn bằng 還是.', 'examples': [ex('你要大杯還是中杯？', 'Anh lấy ly lớn hay vừa?')]},
              'usage_contrasts': [{'a': {'zh': '樓下有咖啡店', 'vi': 'Dưới lầu có quán cà phê', 'label': '有 (tồn tại)'}, 'b': {'zh': '咖啡店在樓下', 'vi': 'Quán cà phê ở dưới lầu', 'label': '在 (vị trí)'}, 'note': 'Khác nhau ở trọng tâm.'}],
              'mistakes': [{'wrong': '我要二杯', 'right': '我要兩杯', 'why': 'Trước lượng từ dùng 兩.'}],
              'examples_audio': [
                {'zh': '我要兩杯奶茶', 'audio': {'type': 'audio', 'text': '我要兩杯奶茶', 'lang': 'zh-TW', 'url': '/static/audio/lesson/zh/abc.mp3'}}
              ],
            }
          ],
          'questions': [q('g1', 'complete_dialogue')],
        },
        {
          'type': 'practice',
          'questions': [q('p1', 'transform', payload: {
            'prompt': 'Đổi thành câu phủ định',
            'stem': {'type': 'text', 'text': '我要冰'},
            'options': [{'id': 'a', 'text': '我不要冰'}, {'id': 'b', 'text': '我要不冰'}, {'id': 'c', 'text': '我沒要冰'}],
            'answer': 'a',
            'explain': 'Đúng: 我不要冰. 不 đứng trước động từ.',
            'explain_wrong': {'b': 'Không đặt 不 sau động từ.', 'c': '沒 phủ định quá khứ.'},
          })]
        },
        {
          'type': 'speaking',
          'privacy': 'Không chấm điểm; bản ghi chỉ ở trên thiết bị của bạn, không tải lên.',
          'skippable': true,
          'lines': [{'zh': '我要一杯珍珠奶茶。', 'pinyin': 'wǒ yào yì bēi zhēn zhū nǎi chá.', 'vi': 'Cho mình một ly trà sữa trân châu.', 'audio': {'type': 'audio', 'text': '我要一杯珍珠奶茶。', 'lang': 'zh-TW'}}],
        },
        {'type': 'minigame', 'game': 'match60', 'duration': 60, 'skippable': true, 'pairs': []},
        {'type': 'summary', 'can_do': ['我要一杯珍珠奶茶。 — Cho mình một ly trà sữa trân châu.'], 'lines': [{'zh': '我要一杯珍珠奶茶。', 'pinyin': 'wǒ yào yì bēi zhēn zhū nǎi chá.', 'vi': 'Cho mình một ly trà sữa trân châu.'}]},
      ],
      'retry': {'alts': {}},
    };

void main() {
  group('logic thuần', () {
    test('pinyin màu theo thanh', () {
      expect(toneOfSyllable('mā'), 1);
      expect(toneOfSyllable('má'), 2);
      expect(toneOfSyllable('mǎ'), 3);
      expect(toneOfSyllable('mà'), 4);
      expect(toneOfSyllable('ma'), 0);
      expect(toneOfSyllable('lǜ'), 4);
      final segs = toneSegments('wǒ bú shì, Yuè nán');
      expect(segs.where((s) => s.$2 != null).map((s) => s.$2).toList(), [3, 2, 4, 4, 2]);
      expect(segs.firstWhere((s) => s.$1 == ', ').$2, isNull);
      expect(kToneColors.length, 5);
    });

    test('Hán Việt chỉ hiện khi đủ âm cho mọi chữ Hán, viết hoa', () {
      expect(displayHanViet('電話', 'dien thoai'), 'DIEN THOAI');
      expect(displayHanViet('電話', 'điện thoại'), 'ĐIỆN THOẠI');
      expect(displayHanViet('電話', 'điện'), isNull); // thiếu 1 âm -> ẩn
      expect(displayHanViet('電話', ''), isNull);
      expect(displayHanViet('電話', null), isNull);
      expect(displayHanViet('電話', 'a b c'), isNull);
      expect(displayHanViet('LINE', 'x'), isNull);
    });

    test('chặng theo stage/stage_title của SERVER, không theo công thức tự tính', () {
      final units = [
        {'unit_id': 'a', 'unit_order': -14, 'stage': 0, 'stage_title': 'Phát âm', 'status': 'unlocked'},
        {'unit_id': 'b', 'unit_order': -9, 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'status': 'locked'},
        {'unit_id': 'c', 'unit_order': 0, 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'status': 'locked'},
        {'unit_id': 'd', 'unit_order': 1, 'stage': 2, 'stage_title': '', 'status': 'locked'},
        {'unit_id': 'e', 'unit_order': 11, 'stage': 3, 'stage_title': '', 'status': 'locked'},
      ];
      final st = groupIntoStages(units);
      expect(st.map((s) => s.index).toList(), [0, 1, 2, 3]);
      expect(st.map((s) => s.title).toList(), ['Phát âm', 'Những ngày đầu ở Đài Loan', '', '']);
      expect(st[1].units.length, 2);
      // ban server cu (khong co stage): cong thuc cu
      final legacy = groupIntoStages([
        {'unit_id': 'x', 'unit_order': 1, 'status': 'unlocked'},
        {'unit_id': 'y', 'unit_order': 11, 'status': 'locked'},
      ]);
      expect(legacy.map((s) => s.index).toList(), [1, 2]);
      expect(unitNumberLabel(-14), 'P1');
      expect(unitNumberLabel(-10), 'P5');
      expect(unitNumberLabel(-9), 'bài 1');
      expect(unitNumberLabel(0), 'bài 10');
      expect(unitNumberLabel(7), 'bài 7');
    });

    test('bảng pinyin: ô không có audio.url hoặc playable=false thì mờ/không phát', () {
      expect(cellPlayable({'audio': {'url': '/x.mp3'}}), isTrue);
      expect(cellPlayable({'audio': {'text': '媽'}}), isFalse);
      expect(cellPlayable({'audio': null}), isFalse);
      expect(cellPlayable({'playable': false, 'audio': {'url': '/x.mp3'}}), isFalse);
      final idx = indexCells([
        {'row': 'm', 'final': 'a', 'key': 'ma1'},
        {'row': '', 'final': 'a', 'key': 'a1'},
      ]);
      expect(idx['m']!['a']!['key'], 'ma1');
      expect(idx['']!['a']!['key'], 'a1');
    });

    test('đạt kiểm tra bỏ qua khi >= 8/10; nhãn lượt chấm dịch còn lại', () {
      expect(pronTestPassed(8, 10), isTrue);
      expect(pronTestPassed(7, 10), isFalse);
      expect(pronTestPassed(4, 5), isFalse);
      expect(quotaLabel({'used': 1, 'limit': 2}), 'Còn 1/2 lượt chấm dịch hôm nay');
      expect(quotaLabel({'used': 2, 'limit': 2}), 'Còn 0/2 lượt chấm dịch hôm nay');
      expect(quotaLabel({'used': 25, 'limit': 20}), 'Còn 0/20 lượt chấm dịch hôm nay');
      expect(quotaLabel(null), '');
    });
  });

  group('luồng bài tình huống (8 bước)', () {
    testWidgets('mục tiêu → nghe trước → từ mới → hội thoại → ngữ pháp → luyện tập → nói theo → tổng kết', (tester) async {
      final api = SitApi(situationSession());
      await pump(tester, api);
      // 1. mục tiêu + chặng + nhân vật
      expect(find.text('Chặng 1 · Những ngày đầu ở Đài Loan · Bài 3 / 10'), findsOneWidget);
      expect(find.byKey(const Key('character_店員')), findsOneWidget);
      expect(find.text('✦ Sau bài này bạn gọi được một ly trà sữa.'), findsOneWidget);
      await tapKey(tester, 'lesson_start_btn');
      // 2. nghe trước: chưa hiện chữ/dịch, có nút nghe cả đoạn
      expect(find.byKey(const Key('listen_all')), findsOneWidget);
      expect(find.text('你好，要喝什麼？'), findsNothing);
      await tapKey(tester, 'listen_all');
      expect(api.audio, containsAllInOrder(['你好，要喝什麼？', '我要兩杯珍珠奶茶。']));
      await tapKey(tester, 'listen_first_next');
      // 3. thẻ từ: Hán Việt, loại từ, lượng từ, ghi chú
      expect(find.text('珍珠奶茶'), findsOneWidget);
      expect(find.byKey(const Key('word_han_viet')), findsOneWidget);
      expect(find.text('TRÂN CHÂU NÃI TRÀ'), findsOneWidget);
      expect(find.byKey(const Key('word_classifier')), findsOneWidget);
      expect(find.text('Lượng từ: 杯'), findsOneWidget);
      expect(find.byKey(const Key('word_note')), findsOneWidget);
      await tapKey(tester, 'word_next');
      // động từ ly hợp: nhãn + ví dụ tách; Hán Việt thiếu âm (1 âm / 2 chữ) bị ẩn
      expect(find.text('吃飯'), findsOneWidget);
      expect(find.byKey(const Key('word_separable')), findsOneWidget);
      expect(find.text('我吃了飯'), findsOneWidget);
      expect(find.byKey(const Key('word_han_viet')), findsNothing);
      await tapKey(tester, 'word_next');
      // tên riêng + cụm cố định TÁCH RIÊNG
      expect(find.byKey(const Key('special_names')), findsOneWidget);
      expect(find.byKey(const Key('special_fixed')), findsOneWidget);
      expect(find.text('悠遊卡'), findsOneWidget);
      expect(find.text('多少錢'), findsOneWidget);
      await tapKey(tester, 'special_next');
      // 4. hội thoại: bấm từ xem nghĩa, bật/tắt pinyin và dịch
      expect(find.text('Nhân viên'), findsOneWidget);
      expect(find.text('bú shì', findRichText: true, skipOffstage: false), findsNothing); // gloss chỉ hiện khi bấm
      await tapKey(tester, 'gloss_不是');
      expect(find.byKey(const Key('gloss_sheet')), findsOneWidget);
      expect(find.text('không phải là'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('line_vi')), findsNothing);
      await tapKey(tester, 'toggle_vi');
      expect(find.text('Mình không phải người Việt.'), findsOneWidget);
      await tapKey(tester, 'toggle_pinyin');
      await tapKey(tester, 'dialogue_next');
      // 5. ngữ pháp: đủ 6 phần
      for (final k in ['gp0_function', 'gp0_structure', 'gp0_negation', 'gp0_questions', 'gp0_contrast', 'gp0_mistakes']) {
        expect(find.byKey(Key(k)), findsOneWidget, reason: k);
      }
      expect(find.text('Số + lượng từ + danh từ'), findsWidgets); // công thức tiếng Việt
      expect(find.text('✗ 我要二杯'), findsOneWidget);
      expect(find.text('✓ 我要兩杯'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsWidgets); // mọi câu ví dụ có nút nghe
      await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
      await tester.pump();
      await tapKey(tester, 'grammar_next'); // Làm thử
      // câu complete_dialogue: giải thích theo đáp án ĐÃ CHỌN
      expect(find.text('Hoàn thành hội thoại'), findsOneWidget);
      await tapKey(tester, 'lesson_opt_b');
      expect(find.text('Không lặp 嗎 trong câu trả lời.'), findsOneWidget);
      await tapKey(tester, 'lesson_next_btn');
      // 6. luyện tập (transform)
      expect(find.text('Đổi thành câu phủ định'), findsOneWidget);
      await tapKey(tester, 'lesson_opt_c');
      expect(find.text('沒 phủ định quá khứ.'), findsOneWidget);
      await tapKey(tester, 'lesson_next_btn');
      // 7. nói theo: riêng tư, ghi âm, nghe lại, bỏ qua
      expect(find.byKey(const Key('speaking_privacy')), findsOneWidget);
      expect(find.byKey(const Key('speaking_record')), findsOneWidget);
      expect(find.byKey(const Key('speaking_replay')), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('speaking_replay'))).onPressed, isNull); // chưa ghi -> chưa nghe lại được
      await tapKey(tester, 'speaking_next');
      // 8. tổng kết
      expect(find.text('Giờ bạn nói được:'), findsOneWidget);
      await tapKey(tester, 'situation_summary_next');
      expect(find.byKey(const Key('summary_title')), findsOneWidget);
    });
  });

  group('Chặng 0', () {
    testWidgets('bảng pinyin: ô có audio phát, ô không có audio mờ và không phát', (tester) async {
      final api = SitApi(situationSession())
        ..chart = {
          'rows': ['b', 'm'],
          'finals': ['a', 'o'],
          'cells': [
            {'row': 'm', 'final': 'a', 'key': 'ma1', 'spelling': 'mā', 'hanzi': '媽', 'playable': true, 'audio': {'type': 'audio', 'text': '媽', 'lang': 'zh-TW', 'url': '/static/audio/lesson/zh/x.mp3'}},
            {'row': 'b', 'final': 'o', 'key': 'bo1', 'spelling': 'bō', 'hanzi': '波', 'playable': true, 'audio': {'type': 'audio', 'text': '波', 'lang': 'zh-TW'}},
          ],
        };
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: PinyinChartScreen(api: api)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pinyin_table')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cell_ma1')));
      await tester.pumpAndSettle();
      expect(api.audio, ['媽']);
      await tester.tap(find.byKey(const Key('cell_bo1')));
      await tester.pumpAndSettle();
      expect(api.audio, ['媽']); // ô không có url: không phát
      expect(tester.widget<Opacity>(find.descendant(of: find.byKey(const Key('cell_bo1')), matching: find.byType(Opacity))).opacity, lessThan(0.5));
    });

    testWidgets('kiểm tra bỏ qua: 10 câu, đạt >= 8 thì báo server và về danh sách', (tester) async {
      final api = SitApi(situationSession())
        ..pronQs = [for (var i = 0; i < 10; i++) q('t$i', 'pronunciation')];
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      bool? popped;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(body: ElevatedButton(onPressed: () async => popped = await Navigator.push<bool>(ctx, MaterialPageRoute(builder: (_) => PronTestScreen(api: api))), child: const Text('go'))))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        expect(find.text('Câu ${i + 1}/10'), findsOneWidget);
        await tapKey(tester, i < 8 ? 'lesson_opt_a' : 'lesson_opt_b'); // 8 đúng, 2 sai
        await tapKey(tester, 'lesson_next_btn');
      }
      expect(api.pronSent, (8, 10));
      expect(find.text('🎉 Đạt!'), findsOneWidget);
      await tapKey(tester, 'pron_test_done');
      expect(popped, isTrue);
    });

    testWidgets('bước giải thích + nghe âm của bài phát âm', (tester) async {
      final s = {
        'session_id': 'P1',
        'version': 'situation_v1',
        'unit': {'id': 'p1', 'order': -14, 'total_units': 5, 'topic_vi': 'Bốn thanh điệu', 'topic_zh': '聲調', 'level': 'A1', 'language': 'zh', 'stage': 0, 'stage_title': 'Phát âm', 'kind': 'pronunciation'},
        'steps': [
          {'type': 'intro', 'title': 'Bốn thanh điệu', 'goals': ['Nghe 4 thanh'], 'estimated_minutes': 6, 'stage': 0, 'stage_title': 'Phát âm'},
          {'type': 'pron_explain', 'sections': [{'title': 'Một âm — bốn thanh', 'viet': 'Cùng âm ma nhưng khác nghĩa.', 'compare': 'Thanh 1 cao và phẳng.', 'pitfall': 'Thanh 3 ở Đài Loan thường chỉ xuống thấp.'}]},
          {'type': 'pron_listen', 'hint': 'Nghe và nhắc lại', 'items': [{'spelling': 'mā', 'hanzi': '媽', 'group': 0, 'audio': {'text': '媽', 'lang': 'zh-TW'}}], 'words': [{'zh': '你好', 'written': 'nǐ hǎo', 'spoken': 'ní hǎo', 'audio': {'text': '你好', 'lang': 'zh-TW'}}]},
          {'type': 'practice', 'questions': [q('pq1', 'pronunciation')]},
          {'type': 'summary', 'can_do': ['Nghe 4 thanh'], 'lines': []},
        ],
        'retry': {'alts': {}},
      };
      final api = SitApi(s);
      await pump(tester, api);
      expect(find.text('Chặng 0 · Phát âm · P1 / 5'), findsOneWidget);
      await tapKey(tester, 'lesson_start_btn');
      expect(find.byKey(const Key('pron_viet')), findsOneWidget);
      expect(find.text('So với tiếng Việt'), findsOneWidget);
      expect(find.text('Người Việt hay sai'), findsOneWidget);
      await tapKey(tester, 'pron_explain_next');
      expect(find.byKey(const Key('pron_item_mā')), findsOneWidget);
      expect(find.textContaining('viết: nǐ hǎo  →  đọc: ní hǎo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pron_item_mā')));
      await tester.pump();
      expect(api.audio, contains('媽'));
      await tapKey(tester, 'pron_listen_next');
      expect(find.text('Hoàn thành hội thoại'), findsOneWidget);
    });
  });

  group('Bài 10', () {
    Map<String, dynamic> session10() => {
          'session_id': 'S10',
          'version': 'situation_v1',
          'unit': {'id': 'u10', 'order': 0, 'total_units': 10, 'topic_vi': 'Ôn tập', 'topic_zh': '複習', 'level': 'A1', 'language': 'zh', 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan', 'kind': 'review'},
          'steps': [
            {'type': 'intro', 'title': 'Ôn tập: Một ngày của 小安', 'goals': ['Đọc hiểu một đoạn kể'], 'estimated_minutes': 11, 'stage': 1, 'stage_title': 'Những ngày đầu ở Đài Loan'},
            {
              'type': 'narrative',
              'title': 'Một ngày của 小安',
              'hint': 'Nghe và đọc từng câu.',
              'segments': [
                {'i': 0, 'text': '今天小安去上班。', 'pinyin': 'jīn tiān Xiǎo Ān qù shàng bān.', 'vi': 'Hôm nay An đi làm.', 'audio': {'type': 'audio', 'text': '今天小安去上班。', 'lang': 'zh-TW'}, 'tokens': [{'t': '今天小安去'}, {'t': '上班', 'gloss': {'pinyin': 'shàng bān', 'vi': 'đi làm'}}, {'t': '。'}]},
              ],
            },
            {'type': 'mistakes', 'title': '5 lỗi người Việt hay mắc nhất của chặng', 'items': [{'wrong': '我是叫小安', 'right': '我叫小安', 'why': 'Đã dùng 叫 thì không dùng thêm 是.', 'unit': 1}]},
            {
              'type': 'challenge',
              'kind': 'translation',
              'exercise_id': 'ex1',
              'title': 'Một ngày của 小安',
              'hint': 'Dịch từng câu sang tiếng Việt — AI chấm theo bản mẫu.',
              'quota': {'used': 0, 'limit': 2},
              'segments': [
                {'idx': 0, 'source': '今天小安去上班。'},
                {'idx': 1, 'source': '他和美玲一起上班。'},
              ],
            },
            {'type': 'summary', 'can_do': ['Bạn đọc hiểu một đoạn kể ngắn'], 'lines': []},
          ],
          'retry': {'alts': {}},
        };

    testWidgets('đoạn kể + ôn lỗi + luyện dịch có chấm, hiện số lượt còn lại', (tester) async {
      final api = SitApi(session10());
      await pump(tester, api);
      await tapKey(tester, 'lesson_start_btn');
      expect(find.textContaining('Đoạn kể'), findsOneWidget);
      await tapKey(tester, 'gloss_上班');
      expect(find.text('đi làm'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tapKey(tester, 'dialogue_next');
      expect(find.byKey(const Key('mistake_card')), findsOneWidget);
      await tapKey(tester, 'mistakes_next');
      // thử thách dịch
      expect(find.text('Còn 2/2 lượt chấm dịch hôm nay'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('challenge_input')), 'Hôm nay An đi làm.');
      await tapKey(tester, 'challenge_grade');
      expect(api.grades, ['ex1|0|Hôm nay An đi làm.']);
      expect(find.byKey(const Key('challenge_result')), findsOneWidget);
      expect(find.text('Gợi ý: Hôm nay An đi làm.'), findsOneWidget);
      expect(find.text('Còn 1/2 lượt chấm dịch hôm nay'), findsOneWidget);
      await tapKey(tester, 'challenge_report');
      expect(api.reported, ['att1']);
      await tapKey(tester, 'challenge_next');
      expect(find.text('2/2'), findsOneWidget);
      await tapKey(tester, 'challenge_skip');
      expect(find.text('Giờ bạn nói được:'), findsOneWidget);
      expect(find.byKey(const Key('situation_summary_next')), findsOneWidget);
    });

    testWidgets('hết lượt chấm: báo thân thiện + cập nhật số lượt, không văng lỗi', (tester) async {
      final api = SitApi(session10())..gradeFail = GradeError('TRANSLATION_QUOTA', 'Hôm nay bạn đã dùng hết 2 lượt chấm dịch. Mai quay lại nhé!', quota: {'used': 2, 'limit': 2});
      await pump(tester, api);
      await tapKey(tester, 'lesson_start_btn');
      await tapKey(tester, 'dialogue_next');
      await tapKey(tester, 'mistakes_next');
      await tester.enterText(find.byKey(const Key('challenge_input')), 'abc');
      await tapKey(tester, 'challenge_grade');
      expect(find.text('Hôm nay bạn đã dùng hết 2 lượt chấm dịch. Mai quay lại nhé!'), findsOneWidget);
      expect(find.text('Còn 0/2 lượt chấm dịch hôm nay'), findsOneWidget);
      await tapKey(tester, 'challenge_skip');
      expect(find.byKey(const Key('situation_summary_next')), findsOneWidget);
    });
  });

  testWidgets('bài tình huống chưa sẵn sàng: báo rõ, KHÔNG rơi về bài cũ', (tester) async {
    final api = SitApi(situationSession())..unavailable = true;
    await pump(tester, api);
    expect(find.text('Bài này chưa sẵn sàng'), findsOneWidget);
    expect(find.byKey(const Key('lesson_retry_load')), findsOneWidget);
  });
}
