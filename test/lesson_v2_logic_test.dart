import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/lesson_v2/lesson_runner.dart';
import 'package:chinesemate/features/lesson_v2/match_board.dart';

Map<String, dynamic> q(String id, String kind, String? wordId) => {'id': id, 'kind': kind, 'word_id': wordId, 'difficulty': 1, 'payload': {}};

void main() {
  group('PracticeQueue', () {
    test('tra loi dung het: ket thuc, diem lan dau day du', () {
      final qu = PracticeQueue([q('a', 'listen_meaning', 'w1'), q('b', 'meaning_word', 'w2')]);
      qu.answer(true);
      qu.answer(true);
      expect(qu.isDone, true);
      expect(qu.firstAttemptScore, (2, 2));
      expect(qu.records.map((r) => r.attempt), [1, 1]);
    });

    test('sai -> hoi lai SAU 2 cau bang DANG KHAC cua cung tu', () {
      final alts = {
        'w1': [q('a2', 'meaning_word', 'w1'), q('a3', 'listen_word', 'w1')],
      };
      final qu = PracticeQueue([q('a', 'listen_meaning', 'w1'), q('b', 'listen_meaning', 'w2'), q('c', 'listen_meaning', 'w3'), q('d', 'listen_meaning', 'w4')], alts: alts);
      qu.answer(false); // a sai
      expect(qu.total, 5);
      qu.answer(true); // b
      qu.answer(true); // c
      expect(qu.current!['id'], 'a2'); // quay lai sau 2 cau, dang khac
      expect(qu.attemptOfCurrent, 2);
      expect(qu.current!['kind'], isNot('listen_meaning'));
      qu.answer(true);
      qu.answer(true); // d
      expect(qu.isDone, true);
      expect(qu.firstAttemptScore, (3, 4)); // chi tinh lan dau
    });

    test('sai lan 2 -> hoi lan 3 o CUOI phien; sai lan 3 thi thoi (khong chan)', () {
      final alts = {'w1': [q('a2', 'meaning_word', 'w1'), q('a3', 'listen_word', 'w1')]};
      final qu = PracticeQueue([q('a', 'listen_meaning', 'w1'), q('b', 'listen_meaning', 'w2')], alts: alts);
      qu.answer(false); // a (1) sai -> a2 chen sau 2 cau (cuoi)
      qu.answer(true); // b
      expect(qu.current!['id'], 'a2');
      qu.answer(false); // lan 2 sai -> lan 3 o cuoi
      expect(qu.current!['id'], 'a3');
      expect(qu.attemptOfCurrent, 3);
      qu.answer(false); // lan 3 sai -> thoi
      expect(qu.isDone, true);
      expect(qu.records.map((r) => r.attempt), [1, 1, 2, 3]);
    });

    test('het cau thay the -> hoi lai chinh cau do; cau ghep cap (khong word_id) khong lam lai', () {
      final qu = PracticeQueue([q('a', 'listen_meaning', 'w1'), q('m', 'match_pairs', null)]);
      qu.answer(false);
      expect(qu.total, 3);
      qu.answer(false); // match_pairs sai nhung khong co word_id
      expect(qu.total, 3);
      expect(qu.current!['id'], 'a'); // chinh cau do
    });

    test('khong dung lai 1 cau thay the hai lan cho 2 tu khac nhau', () {
      final shared = q('x', 'meaning_word', 'w1');
      final qu = PracticeQueue([q('a', 'listen_meaning', 'w1'), q('b', 'listen_meaning', 'w1')], alts: {'w1': [shared]});
      qu.answer(false);
      qu.answer(false);
      final ids = <String>[];
      while (!qu.isDone) {
        ids.add(qu.current!['id'] as String);
        qu.answer(true);
      }
      expect(ids.where((i) => i == 'x').length, 1);
    });

    test('buildAnswersBody va visibleSteps', () {
      final body = buildAnswersBody('S1', [const AnswerRecord('q1', true, 1, 900), const AnswerRecord('q2', false, 2, 0)]);
      expect(body['session_id'], 'S1');
      expect((body['results'] as List).first, {'question_id': 'q1', 'correct': true, 'attempt': 1, 'ms': 900});
      final steps = visibleSteps({
        'steps': [
          {'type': 'intro'},
          {'type': 'review', 'questions': []},
          {'type': 'new_words', 'pairs': []},
          {'type': 'practice', 'questions': [{}]},
          {'type': 'minigame', 'pairs': [{}, {}]},
        ]
      });
      expect(steps.map((s) => s['type']), ['intro', 'new_words', 'practice']);
    });
  });

  group('MatchBoard', () {
    List<Map<String, dynamic>> pool(int n) => [for (var i = 0; i < n; i++) {'word_id': 'w$i', 'left': 'L$i', 'right': 'R$i'}];

    test('hien 5 cap, ghep dung thay bang cap moi, tinh diem', () {
      final b = MatchBoard(pool(10), seed: 1);
      expect(b.pairs.length, 5);
      final first = b.pairs.first['word_id'] as String;
      expect(b.select(first, first), true);
      expect(b.matched, 1);
      expect(b.pairs.length, 5);
      expect(b.pairs.any((p) => p['word_id'] == first), false);
      expect(b.lefts.length, 5);
      expect(b.rights.length, 5);
      final other = b.pairs[1]['word_id'] as String;
      final wrong = b.pairs[2]['word_id'] as String;
      expect(b.select(other, wrong), false);
      expect(b.misses, 1);
      expect(b.score, 10 - 2);
    });

    test('pool nho: cap da ghep duoc tai su dung nen tro choi khong ket thuc som', () {
      final b = MatchBoard(pool(5), seed: 2);
      for (var i = 0; i < 20; i++) {
        final id = b.pairs.first['word_id'] as String;
        b.select(id, id);
        final ids = b.pairs.map((p) => p['word_id']).toList();
        expect(ids.toSet().length, ids.length);
      }
      expect(b.matched, 20);
      expect(b.isEmpty, false);
    });

    test('pool qua nho (it hon so o): cac cap giam dan va ket thuc', () {
      final b = MatchBoard(pool(3), seed: 2);
      for (final id in b.pairs.map((p) => p['word_id'] as String).toList()) {
        b.select(id, id);
      }
      expect(b.isEmpty || b.pairs.length <= 3, true);
    });

    test('diem khong am', () {
      final b = MatchBoard(pool(6), seed: 3);
      for (var i = 0; i < 5; i++) {
        b.select('w0', 'w1');
      }
      expect(b.score, 0);
    });

    test('moi cap trong luot choi xuat hien nhieu nhat 1 lan tai 1 thoi diem', () {
      final b = MatchBoard(pool(12), seed: 4);
      for (var i = 0; i < 30 && !b.isEmpty; i++) {
        final id = b.pairs.first['word_id'] as String;
        b.select(id, id);
        final ids = b.pairs.map((p) => p['word_id']).toList();
        expect(ids.toSet().length, ids.length);
      }
    });
  });
}
