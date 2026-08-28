// Regression test (2026-08-28) — bao cao that: TTS doc dau CHAM CUOI CAU
// thanh tieng ("dot"), khong phai AI chen tieng Anh. Nguyen nhan XAC NHAN
// (xem multilingual_tts_segmenter.dart::_splitAtSentenceBoundaries): khi gop
// 1 manh CHI-CO-DAU-CAU (vd tung dau "." rieng cua "...") vao segment truoc
// do, code CU chen THEM 1 khoang trang ('${prev.text} $trimmed') — voi
// "..." (3 dau rieng le), moi lan gop lai THEM 1 space, bien "tu..." thanh
// "tu. . ." (dau cham bi co lap boi khoang trang ca 2 phia — dang TTS de
// doc thanh "dot" nhat). Da sua: noi truc tiep, khong chen space.
//
// Dung du lieu THAT tu gpt-4.1 (xem voice_irf_simulation.log kich ban A/B/C
// + scratch_irf_replies.json, backend/scripts/gen_irf_short_replies_for_repro.py)
// chay qua TOAN BO pipeline that (SentenceAccumulator -> extractMoodTag ->
// MultilingualTtsSegmenter) giong het VoiceChatScreen._onAiTextResponseChunk()
// lam, kiem tra KHONG co segment nao chi toan dau cau lot qua — giu lai
// VINH VIEN trong bo regression (khac voi fuzz test cua rieng Segmenter,
// bo nay kiem tra CA pipeline end-to-end voi van ban AI THAT sinh ra).
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/sentence_accumulator.dart';
import 'package:chinesemate/features/chat/engines/mood_tag_parser.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

void main() {
  const segmenter = MultilingualTtsSegmenter();
  final hasLetter = RegExp(r'\p{L}', unicode: true);

  List<TtsSegment> runFullPipelineWholeText(String fullReplyText) {
    final acc = SentenceAccumulator();
    final allSegments = <TtsSegment>[];
    final sentences = acc.addDelta(fullReplyText);
    for (final s in sentences) {
      final extracted = extractMoodTag(s);
      allSegments.addAll(segmenter.segment(extracted.text));
    }
    final remainder = acc.flush();
    if (remainder.isNotEmpty) {
      final extracted = extractMoodTag(remainder);
      allSegments.addAll(segmenter.segment(extracted.text));
    }
    return allSegments;
  }

  List<TtsSegment> runFullPipelineCharByChar(String fullReplyText) {
    final acc = SentenceAccumulator();
    final allSegments = <TtsSegment>[];
    for (final ch in fullReplyText.split('')) {
      final sentences = acc.addDelta(ch);
      for (final s in sentences) {
        final extracted = extractMoodTag(s);
        allSegments.addAll(segmenter.segment(extracted.text));
      }
    }
    final remainder = acc.flush();
    if (remainder.isNotEmpty) {
      final extracted = extractMoodTag(remainder);
      allSegments.addAll(segmenter.segment(extracted.text));
    }
    return allSegments;
  }

  // 3 output THAT tu gpt-4.1 (kich ban A/B/C, voice_irf_simulation.log,
  // 2026-08-27) — dieu chung: co dau "." BEN TRONG 1 doan ngoac dich Viet
  // (vd "(你好 nghĩa là "xin chào".)"），nghi ngo la nguyen nhan chinh vi
  // SentenceAccumulator tach RIENG theo TUNG dau "." (khong biet ve ngoac),
  // co the lam roi dau ")" ra khoi cau, tao segment le.
  const scenarioA =
      '[MOOD:neutral] 你好 nghĩa là "xin chào". (你好 nghĩa là "xin chào".)  \nBạn thử nói lại xem.';
  const scenarioB =
      '[MOOD:happy] Tuyệt lắm! Bạn ghép được luôn thành câu hỏi "Bạn khỏe không" rồi đó. '
      '(Tuyệt lắm! Bạn ghép được luôn thành câu hỏi "Bạn khỏe không" rồi đó.)\n\n'
      'Bạn muốn học thêm 1 từ chào hỏi khác không?';
  const scenarioC =
      '[MOOD:neutral] Gần đúng rồi, nhưng "好" trong 你好 phải đọc là "hǎo" — thanh 3, '
      'phải xuống rồi lên, không phải "hào". (Gần đúng rồi, nhưng "好" trong 你好 phải đọc '
      'là "hǎo" — thanh 3, phải xuống rồi lên, không phải "hào".)  \nBạn thử đọc lại "你好" xem nhé.';

  // Kich ban IRF NGAN DON GIAN (khong ngoac/quote) — dung y het vi du trong
  // voice_teaching_instruction.dart, truong hop DON GIAN NHAT co the gay loi.
  const irfShort1 = '[MOOD:neutral] 你好嗎 nghĩa là "bạn khỏe không". Bạn thử nói lại xem.';
  const irfShort2 = 'Chuẩn rồi đó! Giờ thử từ tiếp theo: 謝謝 nghĩa là cảm ơn. Bạn thử nói lại xem.';

  // 10 cau THAT MOI sinh tu gpt-4.1 (2026-08-28, script
  // backend/scripts/gen_irf_short_replies_for_repro.py, cung system_prompt
  // IRF+i+1 da commit) — da dang chu de/tinh huong de tang co hoi bat
  // duoc pattern gay loi (xem scratch_irf_replies.json ban goc).
  const realReply1 = '[MOOD:neutral] 你好是最常見的打招呼方式，意思 là "xin chào". 你 thử nói lại xem nào. (Bạn thử nói lại xem nào.)';
  const realReply2 = '[MOOD:neutral] 謝謝 nghĩa là cảm ơn. Bạn thử nói lại xem.';
  const realReply3 = '[MOOD:neutral] 你好嗎？(Bạn khỏe không?) Bạn thử nói lại xem.';
  const realReply4 = '[MOOD:neutral] Gần đúng rồi, nhưng chữ đầu phải là "再" với bộ "trùng"... không phải "在" nha. Cố gắng lại lần nữa nhé: 再見.';
  const realReply5 = "[MOOD:happy] Ừm, chuẩn rồi đó! Giỏi quá! Giờ mình thử thêm một từ mới nữa nha: 謝謝 nghĩa là 'cảm ơn'. Bạn thử nói lại xem.";
  const realReply6 = '[MOOD:neutral] 主語加動詞 là cấu trúc cơ bản nhất trong tiếng Trung, giống như "Chủ ngữ + Động từ" trong tiếng Việt. (Chủ ngữ + động từ là cấu trúc cơ bản nhất trong tiếng Trung, giống như "Chủ ngữ + Động từ" trong tiếng Việt.)\n\nBạn thử đặt 1 câu đơn giản với "tôi ăn" theo cấu trúc này xem?';
  const realReply7 = '[MOOD:neutral] 這個句子有 một lỗi nhỏ nha. (Câu này có một lỗi nhỏ nhé.)  \n應該 là「我很好」hoặc「你好嗎？」(Nên là "我很好" hoặc "你好嗎?")  \n「我很好」nghĩa là "Tôi khoẻ", còn「你好嗎？」mới là "Bạn khoẻ không?".  \nBạn thử nói lại xem.';
  const realReply8 = '[MOOD:neutral]現在我們 học cách hỏi giờ nha. (Bây giờ chúng ta học cách hỏi giờ nhé.)\n\n"現在幾點？" nghĩa là "Bây giờ mấy giờ?" (xiànzài jǐ diǎn)\n\nBạn thử nói lại câu này xem.';
  const realReply9 = '[MOOD:happy] Chuẩn rồi đó! 早安 nói rất tốt! (Bạn nói đúng rồi! "Chào buổi sáng" phát âm rất ổn!)\n\nGiờ thử tiếp nhé: 晚安 nghĩa là \'chúc ngủ ngon\'. Bạn thử nói lại xem.';
  const realReply10 = '[MOOD:neutral] 我們先 học cách nói "Tôi tên là...". (Chúng ta hãy học cách nói "Tôi tên là...")  \n你可以說：「我叫...」(Bạn có thể nói: "Wǒ jiào...")\n\nBạn thử nói lại câu này với tên của bạn nha.';

  for (final entry in {
    'Scenario A (gpt-4.1 that)': scenarioA,
    'Scenario B (gpt-4.1 that)': scenarioB,
    'Scenario C (gpt-4.1 that)': scenarioC,
    'IRF ngan 1': irfShort1,
    'IRF ngan 2': irfShort2,
    'Real reply 1': realReply1,
    'Real reply 2': realReply2,
    'Real reply 3': realReply3,
    'Real reply 4 (co "..." trong ngoac kep)': realReply4,
    'Real reply 5': realReply5,
    'Real reply 6': realReply6,
    'Real reply 7': realReply7,
    'Real reply 8': realReply8,
    'Real reply 9': realReply9,
    'Real reply 10 (co "..." + dau ngoac kep + dau cham lien tiep)': realReply10,
  }.entries) {
    test('${entry.key} — WHOLE TEXT (delta lon) — khong segment nao chi toan dau cau', () {
      final result = runFullPipelineWholeText(entry.value);
      // ignore: avoid_print
      print('${entry.key} [whole] -> $result');
      for (final s in result) {
        expect(hasLetter.hasMatch(s.text), isTrue,
            reason: 'Segment vo nghia (chi dau cau, lang=${s.lang}): "${s.text}" — se bi TTS doc thanh am vo nghia/dot');
      }
    });

    test('${entry.key} — CHAR BY CHAR (giong token streaming that) — khong segment nao chi toan dau cau', () {
      final result = runFullPipelineCharByChar(entry.value);
      // ignore: avoid_print
      print('${entry.key} [char-by-char] -> $result');
      for (final s in result) {
        expect(hasLetter.hasMatch(s.text), isTrue,
            reason: 'Segment vo nghia (chi dau cau, lang=${s.lang}): "${s.text}" — se bi TTS doc thanh am vo nghia/dot');
      }
    });
  }
}
