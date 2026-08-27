import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/sentence_accumulator.dart';

void main() {
  group('SentenceAccumulator — gia lap chuoi delta text (khong can AI/WebSocket that)', () {
    test('1 delta chua dung 1 cau hoan chinh -> tra ve dung cau do', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Xin chào bạn.'), ['Xin chào bạn.']);
    });

    test('Cau bi cat thanh NHIEU delta nho (giong token-by-token that) -> chi tra ve khi delta CUOI hoan tat dau cau', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Xin '), isEmpty);
      expect(acc.addDelta('chào '), isEmpty);
      expect(acc.addDelta('bạn'), isEmpty);
      expect(acc.addDelta('.'), ['Xin chào bạn.']);
    });

    test('1 delta chua san 2 cau hoan chinh -> tra ve CA 2, dung thu tu', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Câu một. Câu hai!'), ['Câu một.', 'Câu hai!']);
    });

    test('Nhieu cau lien tiep qua nhieu delta -> moi cau tra ve DUNG 1 LAN, khong lap/mat', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Câu một.'), ['Câu một.']);
      expect(acc.addDelta(' Câu '), isEmpty);
      expect(acc.addDelta('hai đang '), isEmpty);
      expect(acc.addDelta('tiếp tục?'), ['Câu hai đang tiếp tục?']);
      expect(acc.addDelta(' Câu ba.'), ['Câu ba.']);
    });

    test('Dau cau Trung/Anh/Viet deu duoc nhan dien (。！？.!?)', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('你好。'), ['你好。']);
      expect(acc.addDelta('How are you?'), ['How are you?']);
      expect(acc.addDelta('Tuyệt vời!'), ['Tuyệt vời!']);
    });

    test('Khong bao gio co dau cau -> addDelta luon rong, flush() tra ve phan con lai', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Đây là câu'), isEmpty);
      expect(acc.addDelta(' không có dấu chấm'), isEmpty);
      expect(acc.flush(), 'Đây là câu không có dấu chấm');
    });

    test('flush() sau khi da lay het cau hoan chinh -> tra ve rong (khong con gi sot lai)', () {
      final acc = SentenceAccumulator();
      acc.addDelta('Câu trọn vẹn.');
      expect(acc.flush(), isEmpty);
    });

    test('flush() roi addDelta() tiep -> hoat dong sach nhu 1 phien moi (khong lan du lieu cu)', () {
      final acc = SentenceAccumulator();
      acc.addDelta('Còn dang dở');
      expect(acc.flush(), 'Còn dang dở');
      expect(acc.addDelta('Câu mới.'), ['Câu mới.']);
    });

    test('Delta rong khong lam gi, khong crash', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta(''), isEmpty);
      expect(acc.addDelta('Câu.'), ['Câu.']);
    });

    test('Regression 2026-08-27 (Speech Naturalizer benchmark) — "..." KHONG bi tach thanh cac "cau" rac chi co dau cham', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Ừm... mình hiểu mà.'), ['Ừm...', 'mình hiểu mà.']);
    });

    test('Regression — "..." o giua cau (khong phai dau cau) van gop dung vao 1 cau, khong sinh cau rac giua chung', () {
      final acc = SentenceAccumulator();
      expect(
        acc.addDelta('Ừm... mình hiểu mà, học nhiều khi thật sự mệt mỏi... bạn đừng quá áp lực nha. Cứ từ từ thôi.'),
        [
          'Ừm...',
          'mình hiểu mà, học nhiều khi thật sự mệt mỏi...',
          'bạn đừng quá áp lực nha.',
          'Cứ từ từ thôi.',
        ],
      );
    });

    test('Regression — "..." rai qua nhieu delta rieng (token-by-token) — dau cham du thua BI BO QUA (khong tao cau rac), khong the noi lai cau da tra ve truoc do', () {
      final acc = SentenceAccumulator();
      expect(acc.addDelta('Ừm'), isEmpty);
      expect(acc.addDelta('.'), ['Ừm.']);
      expect(acc.addDelta('.'), isEmpty);
      expect(acc.addDelta('.'), isEmpty);
      expect(acc.addDelta(' mình hiểu.'), ['mình hiểu.']);
    });

    test('Mo phong 1 cau tra loi AI streaming thuc te (nhieu token nho, nhieu cau)', () {
      final acc = SentenceAccumulator();
      final deltas = ['Xin ', 'chào', '! ', 'Hôm ', 'nay ', 'tôi ', 'rất ', 'vui', '. ', 'Bạn ', 'khỏe ', 'không', '?'];
      final allSentences = <String>[];
      for (final d in deltas) {
        allSentences.addAll(acc.addDelta(d));
      }
      allSentences.addAll(acc.flush().isEmpty ? [] : [acc.flush()]);
      expect(allSentences, ['Xin chào!', 'Hôm nay tôi rất vui.', 'Bạn khỏe không?']);
    });
  });
}
