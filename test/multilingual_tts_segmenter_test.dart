import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

void main() {
  const seg = MultilingualTtsSegmenter();

  List<String> langs(List<TtsSegment> s) => s.map((e) => e.lang).toList();
  String joined(List<TtsSegment> s) => s.map((e) => e.text).join(' ');

  group('FIX-TTS-02 test 1-3 — 1 ngon ngu duy nhat', () {
    test('1. Chi tieng Viet', () {
      const input = 'Hôm nay trời đẹp quá, bạn có khỏe không?';
      final result = seg.segment(input);
      expect(result, hasLength(1));
      expect(result.single.lang, 'vi');
      expect(result.single.text, input);
    });

    test('2. Chi tieng Trung Phon the', () {
      const input = '你好嗎大家，今天我們學一個新詞：加油。';
      final result = seg.segment(input);
      expect(result, hasLength(1));
      expect(result.single.lang, 'zh-TW');
      expect(result.single.text, input);
    });

    test('3. Chi tieng Anh', () {
      const input = "Hello everyone, I don't know what to say today.";
      final result = seg.segment(input);
      expect(result, hasLength(1));
      expect(result.single.lang, 'en');
      expect(result.single.text, input);
    });
  });

  group('FIX-TTS-02 test 4-7 — tron 2-3 ngon ngu', () {
    test('4. Viet + Trung', () {
      const input = 'Hôm nay tôi rất mệt, tiếng Trung là 我今天很累。';
      final result = seg.segment(input);
      expect(langs(result), ['vi', 'zh-TW']);
      expect(result[1].text, contains('我今天很累'));
    });

    test('5. Viet + Anh', () {
      const input = 'Cảm ơn bạn rất nhiều. Thank you so much!';
      final result = seg.segment(input);
      expect(langs(result), ['vi', 'en']);
      expect(result[0].text, contains('Cảm ơn'));
      expect(result[1].text, 'Thank you so much!');
    });

    test('6. Trung + Anh', () {
      const input = '我今天很忙, I am very busy today.';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'en']);
    });

    test('7. Viet + Trung + Anh', () {
      const input = "Bạn có thể nói 我不知道 khi muốn nói I don't know.";
      final result = seg.segment(input);
      expect(langs(result), ['vi', 'zh-TW', 'vi', 'en']);
      expect(result[3].text, "I don't know.");
    });
  });

  group('FIX-TTS-02 test 8-9 — Pinyin trong ngoac sau chu Han', () {
    test('8. Trung + Pinyin + Viet (vi du chinh trong spec)', () {
      const input = '你好 (nǐ hǎo) nghĩa là xin chào.';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'zh-TW', 'vi']);
      expect(result[0].text, '你好');
      expect(result[0].isPinyin, isFalse);
      expect(result[1].text, 'nǐ hǎo');
      expect(result[1].isPinyin, isTrue);
      expect(result[2].text, 'nghĩa là xin chào.');
    });

    test('9. Trung + Pinyin + Anh', () {
      const input = '你好 (nǐ hǎo) means hello.';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'zh-TW', 'en']);
      expect(result[1].isPinyin, isTrue);
      expect(result[2].text, 'means hello.');
    });

    test('Pinyin toneless van duoc nhan dien khi nam trong ngoac sau Han', () {
      const input = '加班 (jiaban) là tăng ca.';
      final result = seg.segment(input);
      expect(result[1].lang, 'zh-TW');
      expect(result[1].isPinyin, isTrue);
      expect(result[1].text, 'jiaban');
    });
  });

  test('10. Code-switching nhieu lan trong cung 1 cau', () {
    const input = '我 hi 你好 hello 再見 bye.';
    final result = seg.segment(input);
    expect(langs(result), ['zh-TW', 'en', 'zh-TW', 'en', 'zh-TW', 'en']);
    expect(joined(result).replaceAll(' ', ''), input.replaceAll(' ', ''));
  });

  group('FIX-TTS-02 test 11-12 — dau cau', () {
    test('11. Co 。！？ (full-width) — tach dung tung cau', () {
      const input = '你好嗎大家。今天我們學一個新詞！你今天想學什麼呢？';
      final result = seg.segment(input);
      expect(result, hasLength(3));
      expect(result.every((s) => s.lang == 'zh-TW'), isTrue);
      expect(result[0].text, '你好嗎大家。');
      expect(result[1].text, '今天我們學一個新詞！');
      expect(result[2].text, '你今天想學什麼呢？');
    });

    test('12. Co . ! ? (half-width) — tach dung tung cau', () {
      const input = 'Hello. How are you! Are you ok?';
      final result = seg.segment(input);
      expect(result, hasLength(3));
      expect(result.every((s) => s.lang == 'en'), isTrue);
      expect(result[0].text, 'Hello.');
      expect(result[1].text, 'How are you!');
      expect(result[2].text, 'Are you ok?');
    });
  });

  group('FIX-TTS-02 test 13-14 — ngoac va tu mo coi', () {
    test('13. Ngoac chua ban dich (khong phai pinyin) van duoc giu, khong xoa', () {
      const input = '加班 (nghĩa là tăng ca) rất mệt.';
      final result = seg.segment(input);
      expect(result.any((s) => s.text.contains('nghĩa là tăng ca')), isTrue);
      final parenSeg = result.firstWhere((s) => s.text.contains('nghĩa là tăng ca'));
      expect(parenSeg.lang, 'vi');
      expect(parenSeg.isPinyin, isFalse);
    });

    test('14. Doan tieng Viet mo coi ngoai ngoac van duoc doc, khong bi xoa mat', () {
      const input = '加班 nghĩa là tăng ca, còn 你好 nghĩa là xin chào.';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'vi', 'zh-TW', 'vi']);
      expect(result[1].text, contains('nghĩa là tăng ca'));
      expect(result[3].text, contains('xin chào'));
    });
  });

  group('16. Khong duoc mat cau dau/giua/cuoi', () {
    test('cau dai nhieu doan tron ngon ngu — moi cau deu co mat trong output', () {
      const input =
          'Hôm nay chúng ta học từ mới. 加油 (jiāyóu) nghĩa là cố gắng lên. '
          'Bạn nên dùng câu này khi ai đó buồn hoặc mệt. '
          'For example, you can say "加油" to encourage a friend. '
          'Còn 你今天想學什麼呢？';
      final result = seg.segment(input);
      final all = joined(result);
      // Moi cum tu dac trung o dau/giua/cuoi phai xuat hien trong output.
      expect(all, contains('Hôm nay chúng ta học từ mới'));
      expect(all, contains('加油'));
      expect(all, contains('jiāyóu'));
      expect(all, contains('cố gắng lên'));
      expect(all, contains('Bạn nên dùng câu này'));
      expect(all, contains('you can say'));
      expect(all, contains('你今天想學什麼呢'));
      expect(result, isNotEmpty);
    });
  });

  group('Regression — dau ngoac kep/trich dan (") \' 「」 khong duoc lot vao segment', () {
    // Boi canh: dieu tra bang code that phat hien day KHONG PHAI loi rieng
    // cua cap Han+Viet (nhu nghi ngo ban dau) — cap Anh+Viet cung ngoac
    // NEU CO dau ngoac kep se bi LOI Y HET. Nguyen nhan that: dau ngoac
    // kep/trich dan bi tokenizer coi la "glue" thong thuong, lot vao GIUA
    // segment hoac tach thanh 1 segment rieng chi co 1 ky tu vo nghia.

    test('Viet+Trung TACH 2 ngoac RIENG (khong dau ngoac kep) — da dung tu truoc, giu nguyen', () {
      const input = '你吃飯了嗎 (nǐ chī fàn le ma) (nghĩa là bạn đã ăn cơm chưa)';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'zh-TW', 'vi']);
      expect(result[1].isPinyin, isTrue);
      expect(result[2].text, 'nghĩa là bạn đã ăn cơm chưa');
    });

    test('Anh+Viet CHUNG 1 ngoac, CO dau ngoac kep — van phai dung (khong duoc lam sai them)', () {
      const input = 'How are you (nghĩa là "bạn khỏe không")';
      final result = seg.segment(input);
      expect(result, hasLength(1));
      expect(result.single.lang, 'vi');
      // Dau ngoac kep phai bi xoa het, KHONG lot vao giua text.
      expect(result.single.text, 'How are you nghĩa là bạn khỏe không');
      expect(result.single.text, isNot(contains('"')));
    });

    test('Viet+Trung CHUNG 1 ngoac, CO dau ngoac kep — SUA: Viet phai doc dung, khong con dau ngoac lot vao giua', () {
      const input = '你吃飯了嗎 (Câu 你吃飯了嗎 có nghĩa là "Bạn đã ăn cơm chưa?")';
      final result = seg.segment(input);
      expect(langs(result), ['zh-TW', 'vi', 'zh-TW', 'vi']);
      final viSegment = result[3];
      expect(viSegment.text, 'có nghĩa là Bạn đã ăn cơm chưa?');
      // Khong con dau ngoac kep nao lot vao giua cau — day la nguyen nhan
      // goc lam TTS doc "vo nghia" truoc khi sua.
      expect(viSegment.text, isNot(contains('"')));
      // Khong con segment rac chi co 1 ky tu dau ngoac.
      expect(result.any((s) => s.text.trim() == '"'), isFalse);
    });

    test(
      'Cau dai nhieu ngoac Viet rieng xen ke Trung, dung ca 「」 va dau nhay don lam trich dan '
      '— tat ca segment phai sach, khong segment nao chi co 1 ky tu dau ngoac',
      () {
        const input =
            '「how are you」的翻譯是「你好嗎？」(Câu \'how are you\' có nghĩa là \' Bạn có khỏe không?\')'
            '這句話通常用來問候對方的狀態。(Câu này thường được dùng để hỏi thăm tình trạng của người khác.)'
            '例如：你見到朋友時可以說「你好嗎？」(Ví dụ: Khi bạn gặp bạn bè, bạn có thể nói \' Bạn có khỏe không?\')'
            '你有沒有其他問題？(Bạn có câu hỏi nào khác không?)';
        final result = seg.segment(input);

        // Khong segment nao ma noi dung (sau khi trim) rong hoac chi toan
        // dau cau/ngoac — moi segment phai co noi dung thuc su de doc.
        final meaningless = RegExp(r'^[\s"“”‘’「」『』' r"'.,!?。！？、：；]*$");
        for (final s in result) {
          expect(
            meaningless.hasMatch(s.text),
            isFalse,
            reason: 'Segment rac/vo nghia: "${s.text}" (lang=${s.lang})',
          );
        }
        // Khong con dau ngoac kep nao lot vao giua bat ky segment nao.
        for (final s in result) {
          expect(s.text, isNot(contains('"')));
          expect(s.text, isNot(contains('「')));
          expect(s.text, isNot(contains('」')));
        }
        // 2 cau Viet cuoi (bi bao cao la doc sai) phai con nguyen noi dung.
        final all = joined(result);
        expect(all, contains('Khi bạn gặp bạn bè, bạn có thể nói'));
        expect(all, contains('Bạn có khỏe không'));
        expect(all, contains('Bạn có câu hỏi nào khác không'));
      },
    );
  });

  group('Regression — dau cham lien tiep (...) khong tao segment vo nghia/im lang', () {
    // Boi canh: xac nhan bang code that phat hien dau "..." (3 dau cham
    // ASCII rieng le, khac ky tu "…" co san) sau chu Han bi tach thanh 2
    // "segment" rieng CHI CO 1 dau cham — TTS phat am 1 dau cham don le
    // ra gan nhu im lang, nguoi dung nghe giong "mat 1 doan". Da sua bang
    // cach gop manh khong co chu/Han tu nao vao segment lien truoc.
    test(
      'Cau bao cao moi — Han+Viet chung cau (「」 va " ") + dau "..." sau chu Han '
      '— khong con segment nao chi toan dau cau, khong mat noi dung',
      () {
        const input =
            '明天你要上班嗎的意思是「明天你需要去工作嗎？」(Câu 明天你要上班嗎 có nghĩa là "Ngày mai bạn có phải đi làm không?")'
            '這句話用來詢問對方的工作計劃。(Câu này被用來詢問有關工作計劃的問題...)'
            '你有什麼工作計劃呢？(Bạn có kế hoạch gì cho công việc không?)';
        final result = seg.segment(input);

        // Khong segment nao chi toan dau cau (khong co chu/Han tu nao) —
        // day chinh la nguyen nhan "im lang troi qua, mat 1 doan".
        final letterRe = RegExp(r'\p{L}', unicode: true);
        for (final s in result) {
          expect(
            letterRe.hasMatch(s.text),
            isTrue,
            reason: 'Segment vo nghia (chi co dau cau, TTS phat gan nhu im '
                'lang): "${s.text}" (lang=${s.lang})',
          );
        }

        // Khong con dau ngoac kep/「」 lot vao giua bat ky segment nao —
        // xac nhan symptom 1 va 2 (Han+Viet chung cau, cau Viet cuoi rieng
        // ngoac) da dung tu ban sua truoc, khong regress lai.
        for (final s in result) {
          expect(s.text, isNot(contains('"')));
          expect(s.text, isNot(contains('「')));
          expect(s.text, isNot(contains('」')));
        }

        // Khong mat noi dung — moi cum quan trong phai co mat.
        final all = joined(result);
        expect(all, contains('明天你要上班嗎的意思是'));
        expect(all, contains('明天你需要去工作嗎'));
        expect(all, contains('có nghĩa là Ngày mai bạn có phải đi làm không'));
        expect(all, contains('這句話用來詢問對方的工作計劃'));
        expect(all, contains('Câu này'));
        expect(all, contains('被用來詢問有關工作計劃的問題'));
        expect(all, contains('你有什麼工作計劃呢'));
        expect(all, contains('Bạn có kế hoạch gì cho công việc không'));

        // Dau cham cuoi cau van con duoc giu lai (khong bi mat han khoi
        // van ban), chi khong con tao segment rieng vo nghia.
        expect(all, contains('.'));
      },
    );
  });

  group('Regression — khong con blank/mat noi dung nhu bug TTS cu', () {
    test('sample bug report goc (dau cau full-width, 1 tu Viet mo coi) van giu du 2 cau Trung', () {
      const input =
          '你好嗎大家，今天我們學一個新詞：加油。'
          '加油的意思是nghĩa là cố gắng，常用來鼓勵別人。'
          '你今天想學什麼呢？';
      final result = seg.segment(input);
      final all = joined(result);
      expect(all, contains('你好嗎大家'));
      expect(all, contains('你今天想學什麼呢'));
      expect(all, contains('cố gắng'));
    });
  });
}
