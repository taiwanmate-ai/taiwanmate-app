import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/mood_tag_parser.dart';

void main() {
  group('extractMoodTag — boc [MOOD:xxx] o dau cau (chi dung cho Voice, xem docstring)', () {
    test('Cau co tag mood hop le o dau -> tra ve dung mood, text da bo tag', () {
      final r = extractMoodTag('[MOOD:happy] Giỏi quá!');
      expect(r.mood, 'happy');
      expect(r.text, 'Giỏi quá!');
    });

    test('Khong dau ca 4 mood hop le deu duoc nhan dien dung', () {
      for (final mood in kValidMoods) {
        final r = extractMoodTag('[MOOD:$mood] Noi dung.');
        expect(r.mood, mood);
        expect(r.text, 'Noi dung.');
      }
    });

    test('Khong phan biet hoa/thuong trong ten mood', () {
      final r = extractMoodTag('[MOOD:COMFORTING] Đừng lo.');
      expect(r.mood, 'comforting');
      expect(r.text, 'Đừng lo.');
    });

    test('Cau KHONG co tag -> fallback mood neutral, text giu nguyen', () {
      final r = extractMoodTag('Câu bình thường không có tag.');
      expect(r.mood, kDefaultMood);
      expect(r.text, 'Câu bình thường không có tag.');
    });

    test('Tag voi gia tri LA (khong nam trong kValidMoods) -> fallback neutral, KHONG duoc lot xuong TTS', () {
      final r = extractMoodTag('[MOOD:excited_super] Wow!');
      expect(r.mood, kDefaultMood);
      // Tag la van bi bóc khoi text du gia tri khong hop le (khong doc thanh tieng).
      expect(r.text, 'Wow!');
    });

    test('Tag KHONG o dau cau (o giua/cuoi) -> KHONG duoc coi la tag, giu nguyen ca chuoi', () {
      final r = extractMoodTag('Giỏi quá! [MOOD:happy]');
      expect(r.mood, kDefaultMood);
      expect(r.text, 'Giỏi quá! [MOOD:happy]');
    });

    test('Co khoang trang thua truoc/sau tag van duoc xu ly dung', () {
      final r = extractMoodTag('   [MOOD:playful]   Đùa chút nha!');
      expect(r.mood, 'playful');
      expect(r.text, 'Đùa chút nha!');
    });
  });

  group('stripMoodTagsForDisplay — boc SACH moi tag [MOOD:...] o BAT KY dau (dung cho UI _aiText tich luy tu delta tho)', () {
    test('Boc tag o dau chuoi', () {
      expect(stripMoodTagsForDisplay('[MOOD:happy] Xin chào'), 'Xin chào');
    });

    test('Boc tag o giua/cuoi chuoi (truong hop UI tich luy delta tho)', () {
      expect(stripMoodTagsForDisplay('Xin chào [MOOD:happy] hôm nay'), 'Xin chào hôm nay');
      expect(stripMoodTagsForDisplay('Xin chào hôm nay [MOOD:happy]'), 'Xin chào hôm nay ');
    });

    test('Boc NHIEU tag trong cung 1 chuoi (nhieu cau da ghep)', () {
      expect(
        stripMoodTagsForDisplay('[MOOD:neutral] Câu 1. [MOOD:happy] Câu 2!'),
        'Câu 1. Câu 2!',
      );
    });

    test('Idempotent — goi lai nhieu lan khong doi ket qua, khong crash voi tag dang bi cat do (streaming)', () {
      const partial = 'Xin chào [MOO';
      final once = stripMoodTagsForDisplay(partial);
      final twice = stripMoodTagsForDisplay(once);
      expect(once, twice);
      expect(once, partial); // tag chua hoan chinh -> khong khop regex -> giu nguyen
    });

    test('Chuoi khong co tag nao -> giu nguyen', () {
      expect(stripMoodTagsForDisplay('Không có tag gì cả.'), 'Không có tag gì cả.');
    });
  });

  group('An toan — lien ket mood comforting voi Safety Override (backend voice_ws.py ep [MOOD:comforting])', () {
    test('extractMoodTag nhan dien dung [MOOD:comforting] ma backend safety se ep dung', () {
      final r = extractMoodTag('[MOOD:comforting] Mình hiểu mà, đừng lo nha.');
      expect(r.mood, 'comforting');
      expect(kValidMoods.contains('comforting'), isTrue);
    });

    test('kVoiceNaturalizerInstruction PHAI neu ro comforting la mood bat buoc khi user can an ui, KHONG duoc lan voi playful/happy', () {
      expect(kVoiceNaturalizerInstruction.contains('comforting'), isTrue);
      expect(kVoiceNaturalizerInstruction.contains('KHÔNG bao giờ dùng playful/happy'), isTrue);
    });
  });
}
