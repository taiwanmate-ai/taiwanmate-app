import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

/// FIX-TTS-02 — Kiem tra TINH DAY DU TONG QUAT cua Segmenter, khong phai
/// tim 1 bug cu the. Thay vi cho nguoi dung tinh co gap phai roi moi bao
/// (nhu 3 vong bao cao bug lien tiep truoc do — dau ngoac kep, dau ngoac
/// Trung, dau "..." lien tiep), test nay chu dong sinh ra HANG LOAT cau
/// mau ket hop Viet + Trung + Anh + DU CAC LOAI dau cau/ky tu bao quanh
/// AI thuc su hay dung, roi kiem tra 1 QUY TAC BAT BIEN DUY NHAT:
///
///   MOI segment output ra tu segment() PHAI co it nhat 1 ky tu \p{L}
///   (chu cai/Han tu) — khong duoc co segment "chi toan dau cau" nao lot
///   qua, vi day chinh la nguyen nhan goc gay ra ca 3 bug da sua (dau
///   ngoac kep lot vao giua cau, dau ngoac Trung tu dung thanh 1 "chu",
///   dau "..." lien tiep tao segment rong-vo-nghia).
///
/// Sinh cau mau BANG 2 CACH ket hop (khong dung random thuan — dung
/// Random CO SEED CO DINH de test luon deterministic, khong flaky):
/// 1. Duyet CO HE THONG qua moi hoan vi thu tu Viet/Trung/Anh, ghep voi
///    moi loai dau noi/bao quanh trong danh sach _connectors.
/// 2. Random co seed co dinh, tron them cac to hop dau cau/emoji/so it
///    gap hon de tang do da dang.
///
/// Giu lai VINH VIEN trong bo regression — bat ky thay doi nao sau nay o
/// Segmenter deu tu dong duoc kiem tra lai qua toan bo bo cau mau nay.
void main() {
  const seg = MultilingualTtsSegmenter();
  final hasLetter = RegExp(r'\p{L}', unicode: true);

  const viPhrases = [
    'xin chào',
    'cảm ơn bạn rất nhiều',
    'nghĩa là',
    'tôi rất vui được gặp bạn',
    'bạn có khỏe không',
    'chúc bạn một ngày tốt lành',
    'hôm nay trời đẹp quá',
  ];
  const zhPhrases = [
    '你好',
    '謝謝你',
    '我很高興',
    '你好嗎',
    '加油',
    '再見',
    '這句話很常用',
  ];
  const enPhrases = [
    'hello',
    'thank you so much',
    'how are you',
    'good luck',
    'see you later',
    "I don't know",
  ];

  // Cac loai dau noi/bao quanh AI thuc su hay dung — day du theo yeu cau:
  // ngoac don/kep/Trung, ellipsis (2 kieu), phay 3 kieu, hai cham 2 kieu,
  // gach ngang 3 kieu, dau cham cau, emoji, so.
  const connectors = <String>[
    ' (', // mo ngoac don
    ') ',
    ' （', // mo ngoac Trung
    '） ',
    ' "', // ngoac kep thang
    '" ',
    " '", // ngoac nhay don
    "' ",
    ' 「', // ngoac Trung don
    '」 ',
    ' 『', // ngoac Trung kep
    '』 ',
    '... ', // 3 dau cham ASCII
    '… ', // ellipsis 1 ky tu
    '， ', // phay Trung
    ', ', // phay Anh/Viet
    '、 ', // dau cach cau Trung
    '： ', // hai cham Trung
    ': ', // hai cham Anh/Viet
    ' - ', // gach ngang ASCII
    ' － ', // gach ngang full-width
    ' — ', // em-dash
    '？ ', // hoi Trung
    '? ', // hoi Anh/Viet
    '！ ', // than Trung
    '! ', // than Anh/Viet
    '。 ', // cham Trung
    '. ', // cham Anh/Viet
    ' 😀 ', // emoji
    ' 👍 ',
    ' 123 ', // so
    ' 2024 ',
    '?! ', // dau cau kep
    '!? ',
    '?... ',
    '.、 ', // dau cau Trung+Anh lien tiep, khac loai
  ];

  final samples = <String>[];

  // ── 1. Sinh CO HE THONG: moi hoan vi 3 ngon ngu x moi connector ──
  final orders = [
    [viPhrases, zhPhrases, enPhrases],
    [zhPhrases, viPhrases, enPhrases],
    [enPhrases, viPhrases, zhPhrases],
    [zhPhrases, enPhrases, viPhrases],
    [viPhrases, enPhrases, zhPhrases],
    [enPhrases, zhPhrases, viPhrases],
  ];
  var idx = 0;
  for (final order in orders) {
    for (final c in connectors) {
      final a = order[0][idx % order[0].length];
      final b = order[1][idx % order[1].length];
      final d = order[2][idx % order[2].length];
      samples.add('$a$c$b$c$d.');
      idx++;
    }
  }

  // ── 2. Random co seed co dinh — tron them to hop it gap hon ──
  final rng = Random(42);
  final allPhrases = [...viPhrases, ...zhPhrases, ...enPhrases];
  for (int i = 0; i < 40; i++) {
    final nParts = 2 + rng.nextInt(3); // 2-4 phan
    final buffer = StringBuffer();
    for (int p = 0; p < nParts; p++) {
      buffer.write(allPhrases[rng.nextInt(allPhrases.length)]);
      buffer.write(connectors[rng.nextInt(connectors.length)]);
    }
    samples.add(buffer.toString());
  }

  // ── 3. Vai truong hop bien co the tao ra "manh dau cau don doc" ──
  samples.addAll([
    '你好...',
    '你好。。。',
    '你好？！',
    'xin chào...!',
    '(...)',
    '「」',
    'hello?!...',
    '你好嗎？(nǐ hǎo ma?)...',
    '加油！！！',
    'cảm ơn...,...bạn',
  ]);

  // ── 4. Audit "Giao vien tuong tac that"/IRF (2026-08-28) — bao cao that:
  // TTS doc dau cham cuoi cau thanh tieng "dot". Nguyen nhan xac nhan:
  // _splitAtSentenceBoundaries gop manh CHI-CO-DAU-CAU vao segment truoc
  // do BANG CACH CHEN 1 KHOANG TRANG ('${prev.text} $trimmed') — voi "..."
  // (3 dau cham ASCII rieng le, tach thanh 3 manh lien tiep), moi lan gop
  // THEM 1 space, bien "tu..." thanh "tu. . ." (dau cham bi co lap boi
  // khoang trang ca 2 phia — chinh la dang TTS de doc thanh "dot" nhat).
  // Da sua: noi TRUC TIEP khong chen space. Cau mau duoi day + invariant
  // moi (xem "khong duoc co dau cau CO LAP boi khoang trang") dam bao
  // khong tai phat, dac biet cho cau NGAN kieu IRF (kVoiceInteractiveTeachingInstruction)
  // ket thuc bang 1 dau cham don hoac "..." NGAY SAU 1 tu/dau ngoac kep.
  samples.addAll([
    'Bạn thử nói lại xem.',
    '你好嗎 nghĩa là "bạn khỏe không". Bạn thử nói lại xem.',
    'Chuẩn rồi đó! Giờ thử từ tiếp theo: 謝謝 nghĩa là cảm ơn. Bạn thử nói lại xem.',
    'với bộ "trùng"... không phải "在" nha.',
    'Cố gắng lại lần nữa nhé: 再見.',
    '我們先 học cách nói "Tôi tên là...". (Chúng ta hãy học cách nói "Tôi tên là...")',
    'à...',
    'trùng...',
    '"trùng"...',
    'Thử lại xem nhé...',
    '你好...再見...謝謝...',
  ]);

  // Audit khan "TTS doc dau cham cuoi cau dich Viet bang giong tieng Anh"
  // (2026-08-30) — bao cao that trong che do song ngu (zh_vi/en_vi): AI
  // thinh thoang viet ban dich Viet trong ngoac bang dau cau full-width
  // KIEU TRUNG (。！？，、) thay vi Latin (.!?,) — mang phong cach dau cau
  // cua cau tieng Trung ngay truoc sang ban dich. XAC NHAN qua doc code +
  // chay that: segment van duoc gan DUNG lang='vi', nhung ky tu Trung do
  // VAN CON trong segment.text, khien TTS phat am sai giong tai vi tri do.
  final chinesePunctInViEnSamples = <String>[
    '你好嗎？(Xin chào bạn khỏe không。)',
    '我很好。(Tôi khỏe lắm。)',
    '謝謝你。(Cảm ơn bạn nhiều nha。)',
    '你確定嗎？(Bạn chắc chắn chứ！)',
    '這樣可以嗎？(Như vậy được không，đúng không？)',
    'How are you？(Bạn khỏe không。)',
  ];
  samples.addAll(chinesePunctInViEnSamples);

  final strayChinesePunct = RegExp('[。！？，、：；]');
  test(
    'Fuzz — khong segment nao (lang != zh-TW) con sot dau cau full-width Trung (bug "TTS doc dau cham bang giong Anh")',
    () {
      final violations = <String>[];
      for (final input in chinesePunctInViEnSamples) {
        for (final s in seg.segment(input)) {
          if (s.lang != 'zh-TW' && strayChinesePunct.hasMatch(s.text)) {
            violations.add('Input "$input" -> segment lang=${s.lang} van con dau cau Trung: "${s.text}"');
          }
        }
      }
      if (violations.isNotEmpty) {
        fail('Phat hien ${violations.length} segment vi/en con sot dau cau Trung:\n${violations.join('\n')}');
      }
    },
  );

  test(
    'Fuzz — ${samples.length} cau mau tron Viet+Trung+Anh+moi loai dau cau/bao quanh: '
    'MOI segment deu phai co it nhat 1 ky tu \\p{L}, khong segment nao chi toan dau cau',
    () {
      final violations = <String>[];
      for (final input in samples) {
        List<TtsSegment> result;
        try {
          result = seg.segment(input);
        } catch (e) {
          violations.add('CRASH voi input "$input": $e');
          continue;
        }
        for (final s in result) {
          if (!hasLetter.hasMatch(s.text)) {
            violations.add(
              'Input "$input" -> segment vo nghia (lang=${s.lang}): "${s.text}"',
            );
          }
        }
      }

      if (violations.isNotEmpty) {
        fail(
          'Phat hien ${violations.length} segment vi pham (chi toan dau cau, '
          'se bi TTS phat gan nhu im lang) trong ${samples.length} cau mau:\n'
          '${violations.take(20).join('\n')}'
          '${violations.length > 20 ? '\n... va ${violations.length - 20} vi pham khac' : ''}',
        );
      }
    },
  );

  test('Fuzz — khong co segment nao rong hoan toan (empty string) sau khi trim', () {
    for (final input in samples) {
      for (final s in seg.segment(input)) {
        expect(s.text.trim(), isNotEmpty, reason: 'Input "$input" tao segment rong');
      }
    }
  });

  // Regression-guard rieng (2026-08-28) — xem giai thich day du o nhom mau
  // "4." o tren: bat ky dau cau nao (.!?。！？) bi CO LAP boi khoang trang
  // o CA 2 phia (hoac dau/cuoi chuoi) trong 1 segment.text la dau hieu
  // TRUC TIEP cua bug "TTS doc thanh dot" — du van co \p{L} o cho khac
  // trong CUNG segment (nen khong bi bat boi test invariant o tren).
  final isolatedPunct = RegExp(r'(?:^|\s)[.!?。！？](?:\s|$)');
  test(
    'Fuzz — khong segment nao co dau cau bi CO LAP boi khoang trang (dau hieu bug "doc thanh dot")',
    () {
      final violations = <String>[];
      for (final input in samples) {
        for (final s in seg.segment(input)) {
          if (isolatedPunct.hasMatch(s.text)) {
            violations.add('Input "$input" -> segment co dau cau co lap (lang=${s.lang}): "${s.text}"');
          }
        }
      }
      if (violations.isNotEmpty) {
        fail(
          'Phat hien ${violations.length} segment co dau cau bi co lap boi khoang trang '
          '(se bi TTS doc thanh tieng, vd "dot") trong ${samples.length} cau mau:\n'
          '${violations.take(20).join('\n')}',
        );
      }
    },
  );
}
