// Chấm nghe chép trên app PHẢI cho đúng kết quả của bản tham chiếu backend (app/services/dictation.py) trên file test vector dùng chung.
import 'dart:convert';
import 'dart:io';

import 'package:chinesemate/features/lesson_v2/dictation/dictation_grader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = jsonDecode(File('test/fixtures/dictation_normalize_cases.json').readAsStringSync()) as Map<String, dynamic>;
  final table = {for (final s in (jsonDecode(File('assets/data/dictation_pinyin_syllables.json').readAsStringSync()) as Map)['syllables'] as List) s as String};
  final items = fixture['items'] as Map<String, dynamic>;

  group('test vector dùng chung với backend', () {
    for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
      test(c['name'] as String, () {
        final chars = charsOf(items[c['item']] as Map);
        final input = c['input'] as String;
        final r = switch (c['mode']) {
          'hanzi' => gradeHanzi(chars, input),
          'pinyin' => gradePinyin(chars, input, table, strictTones: c['strict_tones'] as bool),
          _ => gradeTiles(chars, input.isEmpty ? [] : input.split('|')),
        };
        expect(jsonEncode(r.toJson()), jsonEncode(c['expect']), reason: 'ca ${c['name']}: app lệch bản tham chiếu backend');
      });
    }
  });

  test('bảng âm tiết đủ ü (nv, lv, lve), không có lue', () {
    expect(table.containsAll(['nv', 'lv', 'lve', 'nve', 'zhuang', 'er']), isTrue);
    expect(table.contains('lue'), isFalse);
  });

  test('mark() đặt dấu thanh đúng chỗ', () {
    expect([for (final (b, t) in [('hao', 3), ('lv', 4), ('lve', 4), ('gou', 3), ('liu', 2), ('gui', 4), ('xie', 5), ('er', 2), ('n', 2)]) mark(b, t)],
        ['hǎo', 'lǜ', 'lüè', 'gǒu', 'liú', 'guì', 'xie', 'ér', 'n']);
  });

  test('round3 làm tròn về số chẵn khi đúng nửa, như Python', () {
    expect(round3(1, 16), 0.062);
    expect(round3(3, 16), 0.188);
    expect(round3(5, 16), 0.312);
    expect(round3(2, 3), 0.667);
    expect(round3(0, 0), 0.0);
  });

  test('pinyin dạng dựng sẵn và tổ hợp cho cùng kết quả', () {
    expect(parsePinyin('lǘ', table), parsePinyin('lǘ', table));
    expect(parsePinyin('Nǐ hǎo!', table), [('ni', 3), ('hao', 3)]);
  });
}
