import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/language_order_guard.dart';

void main() {
  const guard = LanguageOrderGuard();

  group('stripOrphanVietnameseForTts — full-width Chinese punctuation', () {
    test(
      'giu nguyen toan bo cau tieng Trung, chi xoa dung cau co tu Viet mo coi '
      '(bug report sample: dau cau full-width 。！？)',
      () {
        const input =
            '你好嗎大家，今天我們學一個新詞：加油。'
            '加油的意思是nghĩa là cố gắng，常用來鼓勵別人。'
            '你今天想學什麼呢？';

        final result = guard.stripOrphanVietnameseForTts(input);

        expect(result, '你好嗎大家，今天我們學一個新詞：加油。你今天想學什麼呢？');
        // Cau dau va cau cuoi (thuan Trung) phai con nguyen.
        expect(result, contains('你好嗎大家，今天我們學一個新詞：加油。'));
        expect(result, contains('你今天想學什麼呢？'));
        // Cau chua tu Viet mo coi phai bi xoa het, khong con sot lai.
        expect(result, isNot(contains('nghĩa là cố gắng')));
      },
    );

    test('nhieu cau full-width khong co tu Viet mo coi thi khong mat gi', () {
      const input =
          '你好嗎大家，今天我們學一個新詞：加油。'
          '加油的意思是努力堅持下去，常用來鼓勵別人。'
          '你今天想學什麼呢？';

      final result = guard.stripOrphanVietnameseForTts(input);

      expect(result, input);
    });
  });

  group('stripOrphanVietnameseForTts — half-width punctuation (regression)', () {
    test('hanh vi cu voi dau cau half-width (. ! ?) khong bi thay doi', () {
      const input =
          '你好嗎大家, 今天我們學一個新詞: 加油. '
          '加油的意思是nghĩa là cố gắng, 常用來鼓勵別人. '
          '你今天想學什麼呢?';

      final result = guard.stripOrphanVietnameseForTts(input);

      expect(
        result,
        '你好嗎大家, 今天我們學一個新詞: 加油. 你今天想學什麼呢?',
      );
      expect(result, isNot(contains('nghĩa là cố gắng')));
    });

    test('xuong dong (\\n) van la diem tach cau nhu cu', () {
      const input = '你好嗎。\nĐây là câu tiếng Việt mồ côi.\n今天天氣很好。';

      final result = guard.stripOrphanVietnameseForTts(input);

      expect(result, contains('你好嗎。'));
      expect(result, contains('今天天氣很好。'));
      expect(result, isNot(contains('mồ côi')));
    });
  });
}
