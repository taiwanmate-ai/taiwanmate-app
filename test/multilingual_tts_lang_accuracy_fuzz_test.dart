// Bo test fuzz toan dien (2026-08-15) — dut diem van de phan loai
// Anh/Viet cho CAU DAI (khong chi 1 tu), truoc khi bat dau Phase 2 Voice.
//
// Boi canh: fix "single-word sentence" (2026-08-15, vong truoc) chi giai
// quyet truong hop 1 tu tu mang dau ket cau. User bao cao van con cau
// tieng Anh DAI hon 1 tu thinh thoang bi doc nham giong Viet, vi tieng
// Anh khong dau va tieng Viet khong dau dung CHUNG bang chu cai La-tinh —
// khi cau khong co dau thanh Viet/Han neo nao, sticky context (ngu canh
// cau lien ke) khong du manh/nhat quan.
//
// Giai phap: tu dien tu khoa dac trung (_englishDictionary/
// _vietnameseNoDiacriticDictionary trong multilingual_tts_segmenter.dart)
// lam tin hieu QUYET DINH cho cau "mo ho" (dem so tu khop tu dien, 1 ben
// ap dao >=2-vs-0 thi quyet ca cau), CHI roi ve sticky context khi tu dien
// khong du tin hieu.
//
// Bo test nay sinh >= 60 mau THAT (khong gia dinh) theo dung cau truc AI
// Companion thuc te hay sinh (cau vi du + dich trong ngoac, cau hoi cuoi,
// chao ngan, cau dai nhieu menh de), UU TIEN nhieu cau tieng Anh KHONG co
// ky tu dac trung de nhan (khong q/w/j/z, khong cum phu am hiem) de ep
// dung vao vung mo ho nhat. Tieu chi hoan thanh: >=98% SEGMENT (khong
// phai % CAU TEST) duoc gan dung ngon ngu.
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

void main() {
  const seg = MultilingualTtsSegmenter();

  // Moi mau: (input, expectedLangsTheoDungThuTuSegment).
  // 'en' = tieng Anh, 'vi' = tieng Viet. Nhan da biet TRUOC khi viet cau
  // (khong suy dien nguoc tu ket qua chay).
  final samples = <(String, List<String>)>[
    // ─────────────────────────────────────────────────────────
    // Nhom A (15) — chao hoi/cam than NGAN (1-2 tu, tu mang dau ket cau
    // cua chinh no) — hoi quy fix vong truoc, giu de dam bao khong phá.
    // ─────────────────────────────────────────────────────────
    ('Hello! (Xin chào!)', ['en', 'vi']),
    ('Great! (Tuyệt vời!)', ['en', 'vi']),
    ('Yes! (Đúng vậy!)', ['en', 'vi']),
    ('No! (Không phải!)', ['en', 'vi']),
    ('Sure! (Chắc chắn rồi!)', ['en', 'vi']),
    ('Really? (Thật không?)', ['en', 'vi']),
    ('Nice! (Hay đấy!)', ['en', 'vi']),
    ('Right! (Đúng rồi!)', ['en', 'vi']),
    ('Thanks! (Cảm ơn nhé!)', ['en', 'vi']),
    ('Sorry! (Xin lỗi nhé!)', ['en', 'vi']),
    ('Welcome! (Chào mừng!)', ['en', 'vi']),
    ('Of course! (Tất nhiên rồi!)', ['en', 'vi']),
    ('Good job! (Làm tốt lắm!)', ['en', 'vi']),
    ('See you! (Hẹn gặp lại!)', ['en', 'vi']),
    ('Not bad! (Không tệ đâu!)', ['en', 'vi']),

    // ─────────────────────────────────────────────────────────
    // Nhom B (20) — cau tieng Anh TRUNG BINH (5-10 tu), CO CHU DICH tranh
    // q/w/j/z va cum phu am hiem — day la VUNG MO HO nhat can ep toi.
    // ─────────────────────────────────────────────────────────
    ('This is a good example. (Đây là một ví dụ tốt.)', ['en', 'vi']),
    ('You should try it again. (Bạn nên thử lại lần nữa.)', ['en', 'vi']),
    ('That is what I meant. (Đó là điều tôi muốn nói.)', ['en', 'vi']),
    ('We can talk about this later. (Chúng ta có thể nói về điều này sau.)', ['en', 'vi']),
    ('I think you did it right. (Tôi nghĩ bạn đã làm đúng.)', ['en', 'vi']),
    ('She said it was easy. (Cô ấy nói nó dễ mà.)', ['en', 'vi']),
    ('They will come here soon. (Họ sẽ đến đây sớm thôi.)', ['en', 'vi']),
    ('He has done this before. (Anh ấy đã làm điều này trước đây.)', ['en', 'vi']),
    ('It is time to go now. (Đến lúc phải đi rồi.)', ['en', 'vi']),
    ('Let me explain this to you. (Để tôi giải thích điều này cho bạn.)', ['en', 'vi']),
    ('You need to practice more. (Bạn cần luyện tập nhiều hơn.)', ['en', 'vi']),
    ('I want to learn this word. (Tôi muốn học từ này.)', ['en', 'vi']),
    ('This sentence is very simple. (Câu này rất đơn giản.)', ['en', 'vi']),
    ('I feel great today. (Hôm nay tôi cảm thấy tuyệt vời.)', ['en', 'vi']),
    ('That was a nice try. (Đó là một lần thử hay đấy.)', ['en', 'vi']),
    ('He likes to study at night. (Anh ấy thích học vào buổi tối.)', ['en', 'vi']),
    ('I have never seen this before. (Tôi chưa từng thấy cái này trước đây.)', ['en', 'vi']),
    ('This is not easy at all. (Cái này không dễ chút nào.)', ['en', 'vi']),
    ('You can say it like this. (Bạn có thể nói như thế này.)', ['en', 'vi']),
    ('I really like this idea. (Tôi thực sự thích ý tưởng này.)', ['en', 'vi']),

    // ─────────────────────────────────────────────────────────
    // Nhom C (10) — cau DAI nhieu menh de (10+ tu) — cau truc that AI hay
    // dung khi giai thich tu vung/thanh ngu.
    // ─────────────────────────────────────────────────────────
    (
      'The word grateful means feeling thankful for something someone did for you. '
          '(Từ grateful nghĩa là cảm thấy biết ơn về điều gì đó ai đó đã làm cho bạn.)',
      ['en', 'vi']
    ),
    (
      'You can use this phrase when you want to thank someone in a formal way. '
          '(Bạn có thể dùng cụm từ này khi muốn cảm ơn ai đó một cách trang trọng.)',
      ['en', 'vi']
    ),
    (
      'In daily life you can use this word when you talk to your friends or family. '
          '(Trong cuộc sống hàng ngày bạn có thể dùng từ này khi nói chuyện với bạn bè hoặc gia đình.)',
      ['en', 'vi']
    ),
    (
      'This is a common mistake that many people make when they first start learning. '
          '(Đây là một lỗi phổ biến mà nhiều người mắc phải khi mới bắt đầu học.)',
      ['en', 'vi']
    ),
    (
      'It means to spend time thinking carefully about something before you decide. '
          '(Nó có nghĩa là dành thời gian suy nghĩ kỹ về điều gì đó trước khi quyết định.)',
      ['en', 'vi']
    ),
    (
      'You should remember this rule because it will help you a lot later. '
          '(Bạn nên nhớ quy tắc này vì nó sẽ giúp ích cho bạn rất nhiều sau này.)',
      ['en', 'vi']
    ),
    (
      'I want to tell you a story about something that happened to me yesterday. '
          '(Tôi muốn kể cho bạn nghe một câu chuyện về điều đã xảy ra với tôi hôm qua.)',
      ['en', 'vi']
    ),
    (
      'This idiom is used when someone wants to say they feel very tired after work. '
          '(Thành ngữ này được dùng khi ai đó muốn nói họ cảm thấy rất mệt sau khi làm việc.)',
      ['en', 'vi']
    ),
    (
      'The teacher said this lesson is important for the test next week. '
          '(Giáo viên nói bài học này quan trọng cho bài kiểm tra tuần sau.)',
      ['en', 'vi']
    ),
    (
      'I think this is the best way to remember new vocabulary every day. '
          '(Tôi nghĩ đây là cách tốt nhất để nhớ từ vựng mới mỗi ngày.)',
      ['en', 'vi']
    ),

    // ─────────────────────────────────────────────────────────
    // Nhom D (10) — cau hoi KET THUC (rule 4 bat buoc AI luon hoi cuoi).
    // ─────────────────────────────────────────────────────────
    ('Can you try to use this word in your own sentence? (Bạn có thể thử dùng từ này trong câu của mình không?)', ['en', 'vi']),
    ('Do you want to learn another word today? (Bạn có muốn học thêm một từ nữa hôm nay không?)', ['en', 'vi']),
    ('Would you like more examples? (Bạn có muốn thêm ví dụ không?)', ['en', 'vi']),
    ('How do you feel about this? (Bạn cảm thấy thế nào về điều này?)', ['en', 'vi']),
    ('What does this word mean to you? (Từ này có ý nghĩa gì với bạn?)', ['en', 'vi']),
    ('Where did you learn that from? (Bạn học điều đó từ đâu vậy?)', ['en', 'vi']),
    ('Why do you think that happened? (Tại sao bạn nghĩ điều đó đã xảy ra?)', ['en', 'vi']),
    ('When will you have time to practice? (Khi nào bạn có thời gian để luyện tập?)', ['en', 'vi']),
    ('Who told you about this word? (Ai đã nói cho bạn biết về từ này?)', ['en', 'vi']),
    ('Can we talk about this more? (Chúng ta có thể nói thêm về điều này không?)', ['en', 'vi']),

    // ─────────────────────────────────────────────────────────
    // Nhom E (10) — nhieu cap Anh/Viet lien tiep trong 1 doan (mo phong
    // 1 phan hoi day du nhieu cau).
    // ─────────────────────────────────────────────────────────
    ('Hello! (Xin chào!) How are you today? (Hôm nay bạn thế nào?)', ['en', 'vi', 'en', 'vi']),
    ("Great job! (Làm tốt lắm!) Let's try another one. (Hãy thử một câu khác nhé.)", ['en', 'vi', 'en', 'vi']),
    ('This is important. (Điều này quan trọng.) You should remember it well. (Bạn nên nhớ kỹ điều này.)', ['en', 'vi', 'en', 'vi']),
    ('I understand now. (Bây giờ tôi hiểu rồi.) Thank you for explaining. (Cảm ơn bạn đã giải thích.)', ['en', 'vi', 'en', 'vi']),
    ('Sure! (Chắc chắn rồi!) Here is another example. (Đây là một ví dụ khác.) Try it yourself. (Hãy tự thử xem.)', ['en', 'vi', 'en', 'vi', 'en', 'vi']),
    ('That makes sense. (Điều đó hợp lý đấy.) I will remember that. (Tôi sẽ nhớ điều đó.)', ['en', 'vi', 'en', 'vi']),
    ('Nice! (Hay đấy!) You are learning fast. (Bạn học nhanh thật đấy.)', ['en', 'vi', 'en', 'vi']),
    ('This word is useful. (Từ này hữu ích đấy.) Try to use it every day. (Hãy cố gắng dùng nó mỗi ngày.)', ['en', 'vi', 'en', 'vi']),
    ('I am proud of you. (Tôi tự hào về bạn.) Keep going. (Hãy tiếp tục phát huy nhé.)', ['en', 'vi', 'en', 'vi']),
    ('This is the last example. (Đây là ví dụ cuối cùng.) Do you have any questions? (Bạn có câu hỏi gì không?)', ['en', 'vi', 'en', 'vi']),

    // ─────────────────────────────────────────────────────────
    // Nhom F (5) — co apostrophe/contraction tieng Anh — kiem tra tu dien
    // dang rut gon van hoat dong dung trong cau dai.
    // ─────────────────────────────────────────────────────────
    ("I don't understand this part. (Tôi không hiểu phần này.)", ['en', 'vi']),
    ("It's easy once you practice. (Nó dễ khi bạn luyện tập.)", ['en', 'vi']),
    ("That's a good question. (Đó là một câu hỏi hay.)", ['en', 'vi']),
    ("I'm proud of you. (Tôi tự hào về bạn.)", ['en', 'vi']),
    ("We're almost done here. (Chúng ta gần xong rồi.)", ['en', 'vi']),

    // ─────────────────────────────────────────────────────────
    // Nhom G (5) — tu vung NGOAI tu dien (khong khop ca 2 danh sach) — kiem
    // tra fallback sticky-context/mac dinh Anh van hoat dong dung khi tu
    // dien khong du tin hieu quyet dinh (dung >= 2 tu dien de tranh).
    // ─────────────────────────────────────────────────────────
    ('She whispered something strange. (Cô ấy thì thầm điều gì đó kỳ lạ.)', ['en', 'vi']),
    ('Zebras jump quickly over fences. (Ngựa vằn nhảy nhanh qua hàng rào.)', ['en', 'vi']),
    ('The mountain looked beautiful at sunset. (Ngọn núi trông đẹp lúc hoàng hôn.)', ['en', 'vi']),
    ('A butterfly landed on the flower. (Một con bướm đậu trên bông hoa.)', ['en', 'vi']),
    ('The children played happily outside. (Bọn trẻ chơi vui vẻ ở bên ngoài.)', ['en', 'vi']),
  ];

  test('Fuzz test: >= 98% segment duoc gan DUNG ngon ngu tren >= 60 mau that', () {
    int totalSegments = 0;
    int correctSegments = 0;
    final failures = <String>[];

    for (final (input, expected) in samples) {
      final result = seg.segment(input);
      final actual = result.map((s) => s.lang == 'zh-TW' ? 'zh' : s.lang).toList();
      // Chi so sanh so luong segment KHOP voi nhan (neu lech so luong,
      // tinh toan bo segment cua mau do la SAI de khong lam sai lech %
      // theo huong co loi — dong thoi ghi lai de debug).
      if (actual.length != expected.length) {
        totalSegments += expected.length;
        failures.add('LECH SO SEGMENT: "$input"\n    expected=$expected\n    actual=$actual');
        continue;
      }
      for (int i = 0; i < expected.length; i++) {
        totalSegments++;
        if (actual[i] == expected[i]) {
          correctSegments++;
        } else {
          failures.add('SAI: "$input"\n    segment[$i] expected=${expected[i]} actual=${actual[i]}\n    full actual=$actual');
        }
      }
    }

    final accuracy = totalSegments == 0 ? 0.0 : correctSegments / totalSegments * 100;
    // ignore: avoid_print
    print('Fuzz test: $correctSegments/$totalSegments segments dung ($accuracy%), ${samples.length} mau.');
    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('--- CHI TIET LOI (${failures.length}) ---');
      for (final f in failures) {
        // ignore: avoid_print
        print(f);
      }
    }

    expect(accuracy, greaterThanOrEqualTo(98.0),
        reason: 'Do chinh xac phan loai ngon ngu phai >= 98% tren bo fuzz test — hien tai $accuracy% ($correctSegments/$totalSegments)');
  });
}
