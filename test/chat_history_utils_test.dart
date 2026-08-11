import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/chat_history_utils.dart';

void main() {
  group('Bug nghiem trong da sua (2026-08-12) — buildCleanChatHistory lay dung 8 tin GAN NHAT', () {
    test('hoi thoai <= 8 tin: giu nguyen toan bo, dung thu tu', () {
      final messages = [
        {'role': 'user', 'content': 'Chào bạn'},
        {'role': 'assistant', 'content': 'Chào! Hôm nay học gì nào?'},
        {'role': 'user', 'content': 'Dạy mình từ mới đi'},
      ];
      final result = buildCleanChatHistory(messages);
      expect(result.length, 3);
      expect(result.first['content'], 'Chào bạn');
      expect(result.last['content'], 'Dạy mình từ mới đi');
    });

    test('hoi thoai > 8 tin: tra ve DUNG 8 tin GAN NHAT (KHONG phai 8 tin cu nhat)', () {
      // Mo phong dung kich ban bug that: 5 luot cu (10 tin) + luot giai
      // thich 好了/了解 (tin 11) + cau hoi tiep theo (tin 12).
      final messages = [
        {'role': 'user', 'content': 'Chào bạn'},
        {'role': 'assistant', 'content': 'Chào! Hôm nay học gì nào?'},
        {'role': 'user', 'content': 'Dạy mình từ mới đi'},
        {'role': 'assistant', 'content': 'Được, hôm nay học từ [NEW:辛苦] nghĩa là vất vả.'},
        {'role': 'user', 'content': 'cảm ơn, còn từ gì nữa không'},
        {'role': 'assistant', 'content': 'Học thêm [NEW:加油] nghĩa là cố lên nhé.'},
        {'role': 'user', 'content': 'ok hiểu rồi'},
        {'role': 'assistant', 'content': 'Tốt lắm! Giờ thử đặt câu với 加油 xem.'},
        {'role': 'user', 'content': '為了考試,我要加油'},
        {'role': 'assistant', 'content': 'Chuẩn rồi đó! Giỏi ghê.'},
        {'role': 'user', 'content': '好了 với 了解 khác nhau thế nào vậy'},
        {'role': 'assistant', 'content': '好了 nghĩa là "xong rồi", còn 了解 nghĩa là "hiểu".'},
      ];
      final result = buildCleanChatHistory(messages);

      expect(result.length, 8);
      // PHAI chua doan giai thich 好了/了解 (tin gan nhat) — day chinh la
      // noi dung bi mat tich trong bug goc do .take(8) lay nham dau danh sach.
      expect(
        result.any((m) => (m['content'] as String).contains('好了') && (m['content'] as String).contains('了解')),
        isTrue,
        reason: 'History phai chua doan AI vua giai thich 好了/了解 o luot ngay truoc do',
      );
      // KHONG duoc chua 2 tin dau tien (da bi cat vi qua cu, ngoai pham vi 8 tin gan nhat)
      expect(result.any((m) => m['content'] == 'Chào bạn'), isFalse);
      expect(result.any((m) => m['content'] == 'Chào! Hôm nay học gì nào?'), isFalse);
      // Tin gan nhat trong danh sach goc phai la tin CUOI CUNG trong ket qua
      expect(result.last['content'], '好了 nghĩa là "xong rồi", còn 了解 nghĩa là "hiểu".');
    });

    test('loc bo tin rong va tin canh bao (⚠️), khong tinh vao gioi han 8', () {
      final messages = [
        {'role': 'user', 'content': 'Câu 1'},
        {'role': 'assistant', 'content': ''}, // placeholder streaming rong — phai bi loai
        {'role': 'assistant', 'content': '⚠️ Lỗi kết nối'}, // canh bao — phai bi loai
        {'role': 'assistant', 'content': 'Câu trả lời thật'},
      ];
      final result = buildCleanChatHistory(messages);
      expect(result.length, 2);
      expect(result.map((m) => m['content']), ['Câu 1', 'Câu trả lời thật']);
    });

    test('tin nhan user HIEN TAI khong bi lap trong history khi goi dung thu tu (truoc khi them vao danh sach)', () {
      // Mo phong dung thu tu that trong _send(): lay history TRUOC khi
      // them tin nhan user hien tai vao _messages.
      final messagesBeforeCurrentTurn = [
        {'role': 'user', 'content': 'Chào bạn'},
        {'role': 'assistant', 'content': 'Chào! Hôm nay học gì nào?'},
      ];
      final historyForRequest = buildCleanChatHistory(messagesBeforeCurrentTurn);
      const currentUserText = 'vậy làm sao để phân biệt 2 từ này';

      expect(
        historyForRequest.any((m) => m['content'] == currentUserText),
        isFalse,
        reason: 'history gui len backend KHONG duoc chua tin nhan hien tai — no da duoc gui rieng qua field message',
      );
      expect(historyForRequest.length, 2);
    });
  });
}
