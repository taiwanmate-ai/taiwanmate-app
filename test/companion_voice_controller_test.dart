import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

/// Gia lap 1 backend TTS "that" cho muc dich do luong/kiem thu — KHONG
/// goi mang that (khong co API key/tien that trong moi truong test tu
/// dong). Do la GIA DINH duoc ghi ro trong bao cao, khong phai so lieu
/// production thuc te.
class _FakeTtsBackend {
  _FakeTtsBackend({
    this.perCallLatency = const Duration(milliseconds: 250),
    this.msPerChar = 60,
    this.failIndexes = const {},
    this.failForever = false,
  });

  final Duration perCallLatency;
  final int msPerChar;
  final Set<int> failIndexes;
  final bool failForever;

  final List<String> fetchLog = [];
  final List<String> playLog = [];
  final List<DateTime> playStartTimes = [];
  final List<DateTime> playEndTimes = [];
  int _callIndexCounter = 0;
  final Map<String, int> _textToCallIndex = {};

  Future<List<int>?> Function(String, String, String, String) get fetcher =>
      (text, lang, gender, token) async {
        final idx = _textToCallIndex.putIfAbsent(text, () => _callIndexCounter++);
        fetchLog.add('$lang:$text');
        await Future<void>.delayed(perCallLatency);
        if (failIndexes.contains(idx) && (failForever || _failedOnce.add(idx))) {
          return null;
        }
        return utf8.encode('AUDIO[$text]');
      };

  final Set<int> _failedOnce = {};

  Future<bool> Function(List<int>) get player => (bytes) async {
        final text = utf8.decode(bytes).replaceFirst('AUDIO[', '').replaceFirst(']', '');
        final start = DateTime.now();
        playStartTimes.add(start);
        playLog.add(text);
        await Future<void>.delayed(Duration(milliseconds: text.length * msPerChar));
        playEndTimes.add(DateTime.now());
        return true;
      };
}

void main() {
  group('15/16 — 1 segment loi khong lam mat cac segment khac', () {
    test('segment giua bi loi (ca 2 lan) van bo qua, cac segment khac van phat du', () async {
      final backend = _FakeTtsBackend(
        perCallLatency: const Duration(milliseconds: 5),
        failIndexes: {1},
        failForever: true,
      );
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      const input = 'Câu một tiếng Việt. 加油 (jiāyóu). This is English.';
      // Segmenter tach thanh 4 segment: [vi]"Câu một tiếng Việt.",
      // [zh-TW]"加油。", [zh-TW/pinyin]"jiāyóu", [en]"This is English." —
      // gia lap segment #1 (加油) loi.
      final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

      expect(result.expectedSegments, 4);
      expect(result.failedSegments, 1);
      expect(result.playedSegments, 3);
      // 3 segment con lai (khac segment loi) van duoc phat.
      expect(backend.playLog, hasLength(3));
      expect(backend.playLog.any((t) => t.contains('Câu một')), isTrue);
      expect(backend.playLog.any((t) => t.contains('English')), isTrue);
      controller.dispose();
    });

    test('segment loi lan 1 nhung thanh cong khi retry lan 2 -> van duoc phat, khong tinh la failed', () async {
      final backend = _FakeTtsBackend(
        perCallLatency: const Duration(milliseconds: 5),
        failIndexes: {0},
        failForever: false, // chi loi 1 lan dau, retry lan 2 thanh cong
      );
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      const input = 'Xin chào.';
      final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

      expect(result.expectedSegments, 1);
      expect(result.failedSegments, 0);
      expect(result.playedSegments, 1);
      controller.dispose();
    });
  });

  group('17/18/19 — thu tu, khong trung lap, khong chong tieng', () {
    test('17. Audio phat dung thu tu segment (khong bi dao)', () async {
      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 5));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      const input = '我 hi 你好 hello 再見 bye.';
      await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

      const seg = MultilingualTtsSegmenter();
      final expectedOrder = seg.segment(input).map((s) => s.text).toList();
      expect(backend.playLog, expectedOrder);
      controller.dispose();
    });

    test('18. Khong tao duplicate audio cho cung 1 segment trong 1 lan speak', () async {
      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 5));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      const input = 'Câu một. Câu hai. Câu ba.';
      final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

      expect(backend.playLog.toSet().length, backend.playLog.length,
          reason: 'Moi segment chi duoc phat DUNG 1 lan, khong lap');
      expect(backend.playLog.length, result.expectedSegments);
      controller.dispose();
    });

    test('19. Khong co 2 segment nao phat chong len nhau ve thoi gian', () async {
      final backend = _FakeTtsBackend(
        perCallLatency: const Duration(milliseconds: 10),
        msPerChar: 20,
      );
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      const input = 'Câu một khá dài để đo thời gian. 這是中文句子也不短. Another decently long English sentence here.';
      await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

      for (int i = 1; i < backend.playStartTimes.length; i++) {
        expect(
          backend.playStartTimes[i].isAfter(backend.playEndTimes[i - 1]) ||
              backend.playStartTimes[i].isAtSameMomentAs(backend.playEndTimes[i - 1]),
          isTrue,
          reason: 'Segment $i bat dau truoc khi segment ${i - 1} phat xong -> chong tieng',
        );
      }
      controller.dispose();
    });

    test(
      'Nghi van doc sai do race condition khi do tre SIEU THAP (100ms, gan giong '
      'bao cao thuc te ~1s qua Network tab) — Han xen ke Viet lien tuc nhieu lan',
      () async {
        // Dieu tra rieng theo yeu cau: nghi ngo audio player chuyen nguon
        // qua nhanh cat mat dau segment ke tiep khi TTS phan hoi rat nhanh.
        // Kien truc _speakSegments la 1 chuoi await TUAN TU (fetch -> await
        // -> play -> await -> segment ke tiep) — VE MAT CODE khong co
        // duong nao goi webPlayAudio/audioPlayer cho segment N+1 truoc khi
        // segment N da hoan tat (awaited xong). Test nay xac nhan THUC TE
        // bang cach do tre cuc thap (100ms, thap hon ca 1s quan sat duoc).
        final backend = _FakeTtsBackend(
          perCallLatency: const Duration(milliseconds: 100),
          msPerChar: 5, // phat rat nhanh, de lo race condition neu co
        );
        final controller = CompanionVoiceController(
          tokenProvider: () async => 'fake-token',
          ttsFetcher: backend.fetcher,
          audioPlayer: backend.player,
        );
        const input =
            '你好嗎？(Bạn khỏe không?)我很好。(Tôi khỏe.)你呢？(Còn bạn thì sao?)'
            '謝謝關心。(Cảm ơn đã quan tâm.)再見。(Tạm biệt.)';

        final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');

        // Khong mat segment nao du toc do cuc nhanh.
        expect(result.playedSegments, result.expectedSegments);
        expect(result.failedSegments, 0);
        expect(backend.playLog.length, result.expectedSegments);

        // Khong co segment nao bat dau truoc khi segment truoc phat xong —
        // xac nhan bang dong ho THAT (DateTime), khong doan.
        for (int i = 1; i < backend.playStartTimes.length; i++) {
          expect(
            !backend.playStartTimes[i].isBefore(backend.playEndTimes[i - 1]),
            isTrue,
            reason: 'Segment $i bat dau truoc khi segment ${i - 1} phat xong '
                'o do tre 100ms -> co race condition that su',
          );
        }

        // Kiem tra mau hinh "Han truoc, Viet sau" (yeu cau 2c): xac nhan
        // dung segment Viet ngay sau segment Trung van co noi dung DAY DU,
        // khong bi cat dau do chuyen giong qua nhanh.
        const seg = MultilingualTtsSegmenter();
        final expectedSegments = seg.segment(input);
        for (int i = 1; i < expectedSegments.length; i++) {
          if (expectedSegments[i - 1].lang == 'zh-TW' && expectedSegments[i].lang == 'vi') {
            expect(backend.playLog, contains(expectedSegments[i].text),
                reason: 'Segment Viet ngay sau segment Trung ("${expectedSegments[i].text}") '
                    'phai duoc phat DAY DU, khong bi cat mat');
          }
        }
        controller.dispose();
      },
    );
  });

  group('20 — Cancel/interruption dung toan bo hang doi con lai', () {
    test('stopSpeaking() giua chung ngan cac segment con lai, khong phat tiep', () async {
      final backend = _FakeTtsBackend(
        perCallLatency: const Duration(milliseconds: 5),
        msPerChar: 300, // phat cham de co thoi gian goi stopSpeaking() giua chung
      );
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      const input = 'Câu một. Câu hai. Câu ba. Câu bốn. Câu năm.';

      final future = controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.stopSpeaking();
      final result = await future;

      expect(result.interrupted, isTrue);
      expect(backend.playLog.length, lessThan(5),
          reason: 'Bi ngat giua chung, khong duoc phat het toan bo 5 segment');
      expect(controller.isSpeaking, isFalse);
      controller.dispose();
    });
  });

  group('21-24 — do do tre va tinh day du (backend gia lap, so lieu MO PHONG)', () {
    Future<Map<String, Object?>> measure(String label, String input) async {
      final backend = _FakeTtsBackend(
        perCallLatency: const Duration(milliseconds: 300), // gia dinh ~300ms/segment (mang + sinh am thanh)
        msPerChar: 60, // gia dinh toc do doc ~60ms/ky tu
      );
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');
      controller.dispose();
      return {
        'label': label,
        'expected': result.expectedSegments,
        'played': result.playedSegments,
        'failed': result.failedSegments,
        'timeToFirstAudioMs': result.timeToFirstAudio?.inMilliseconds,
        'totalPlaybackMs': result.totalPlaybackTime.inMilliseconds,
      };
    }

    test('cau ngan (~1 cau) — do time-to-first-audio va total playback time', () async {
      final r = await measure('ngan', 'Hôm nay trời đẹp quá.');
      expect(r['expected'], r['played']);
      expect(r['failed'], 0);
      // in ra so lieu de dua vao bao cao — KHONG assert nguong cung, chi
      // ghi nhan.
      // ignore: avoid_print
      print('[LATENCY] $r');
    });

    test('cau trung binh (~3-4 cau tron ngon ngu) — do time-to-first-audio va total playback time', () async {
      final r = await measure(
        'trung binh',
        'Hôm nay chúng ta học từ mới. 加油 (jiāyóu) nghĩa là cố gắng lên. '
        'Bạn nên dùng câu này khi ai đó buồn hoặc mệt. '
        'For example, you can say "加油" to encourage a friend.',
      );
      expect(r['expected'], r['played']);
      expect(r['failed'], 0);
      // ignore: avoid_print
      print('[LATENCY] $r');
    });

    test('cau dai (~7-8 cau tron ngon ngu nhieu lan) — do time-to-first-audio va total playback time', () async {
      final r = await measure(
        'dai',
        'Hôm nay chúng ta học từ mới. 加油 (jiāyóu) nghĩa là cố gắng lên. '
        'Bạn nên dùng câu này khi ai đó buồn hoặc mệt. '
        'For example, you can say "加油" to encourage a friend. '
        '這句話很常用, people use it every day. '
        'Còn 你好嗎 (nǐ hǎo ma) nghĩa là bạn khỏe không. '
        'Hãy luyện tập nói câu này mỗi ngày nhé. '
        'Practice makes perfect, cố lên nào!',
      );
      expect(r['expected'], r['played']);
      expect(r['failed'], 0);
      // ignore: avoid_print
      print('[LATENCY] $r');
    });

    test('24. Doi chieu so segment mong doi (tu segmenter) vs so segment thuc phat', () async {
      const input =
          'Hôm nay chúng ta học từ mới. 加油 (jiāyóu) nghĩa là cố gắng lên. '
          'Bạn nên dùng câu này khi ai đó buồn hoặc mệt. '
          'For example, you can say "加油" to encourage a friend.';
      const seg = MultilingualTtsSegmenter();
      final expectedSegments = seg.segment(input);

      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 5));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');
      controller.dispose();

      expect(result.expectedSegments, expectedSegments.length,
          reason: 'X segment mong doi tu segmenter phai khop voi expectedSegments cua ket qua speak()');
      expect(result.playedSegments, expectedSegments.length,
          reason: 'Y segment thuc phat phai bang X, khong segment nao bi rot');
      expect(backend.playLog.length, expectedSegments.length);
    });
  });

  group('Regression — cau dai bao cao doc sai (nghi van rieng, xac nhan la loi dau ngoac kep)', () {
    test(
      'Cau dai nhieu ngoac Viet rieng xen ke Trung, dung ca 「」 va dau nhay don — '
      'toan bo audio phai phat DAY DU, dung thu tu, khong segment nao bi cat/rac',
      () async {
        const input =
            '「how are you」的翻譯是「你好嗎？」(Câu \'how are you\' có nghĩa là \' Bạn có khỏe không?\')'
            '這句話通常用來問候對方的狀態。(Câu này thường được dùng để hỏi thăm tình trạng của người khác.)'
            '例如：你見到朋友時可以說「你好嗎？」(Ví dụ: Khi bạn gặp bạn bè, bạn có thể nói \' Bạn có khỏe không?\')'
            '你有沒有其他問題？(Bạn có câu hỏi nào khác không?)';

        const seg = MultilingualTtsSegmenter();
        final expectedSegments = seg.segment(input);

        // Do that voi do tre thap (100ms) — dung mau hinh giong bao cao
        // thuc te (~1s qua Network tab), de vua xac nhan Segmenter vua
        // xac nhan khong co race condition o toc do nhanh.
        final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 100), msPerChar: 5);
        final controller = CompanionVoiceController(
          tokenProvider: () async => 'fake-token',
          ttsFetcher: backend.fetcher,
          audioPlayer: backend.player,
        );
        final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');
        controller.dispose();

        expect(result.expectedSegments, expectedSegments.length);
        expect(result.playedSegments, expectedSegments.length,
            reason: 'Khong segment nao bi rot/mat');
        expect(result.failedSegments, 0);

        // Dung thu tu, dung noi dung — khong lan/cat/sai giong.
        expect(backend.playLog, expectedSegments.map((s) => s.text).toList());

        // 2 cau Viet cuoi (bi bao cao nghe sai truoc khi sua) phai co mat
        // DAY DU, nguyen ven trong danh sach da phat.
        expect(
          backend.playLog.any((t) => t.contains('bạn có thể nói') && t.contains('Bạn có khỏe không')),
          isTrue,
        );
        expect(backend.playLog, contains('Bạn có câu hỏi nào khác không?'));

        // Khong segment nao con dau ngoac kep lot vao giua.
        for (final t in backend.playLog) {
          expect(t, isNot(contains('"')));
          expect(t, isNot(contains('「')));
          expect(t, isNot(contains('」')));
        }
      },
    );
  });

  group('Regression — dau cham lien tiep (...) khong con tao 1 segment im lang', () {
    test(
      'Cau bao cao moi (Han+Viet chung cau + dau "...") — audio phat du, khong segment nao chi 1 dau cham',
      () async {
        const input =
            '明天你要上班嗎的意思是「明天你需要去工作嗎？」(Câu 明天你要上班嗎 có nghĩa là "Ngày mai bạn có phải đi làm không?")'
            '這句話用來詢問對方的工作計劃。(Câu này被用來詢問有關工作計劃的問題...)'
            '你有什麼工作計劃呢？(Bạn có kế hoạch gì cho công việc không?)';

        const seg = MultilingualTtsSegmenter();
        final expectedSegments = seg.segment(input);

        final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 50));
        final controller = CompanionVoiceController(
          tokenProvider: () async => 'fake-token',
          ttsFetcher: backend.fetcher,
          audioPlayer: backend.player,
        );
        final result = await controller.speak(input, aiGender: 'female', learningMode: 'zh_vi');
        controller.dispose();

        expect(result.expectedSegments, expectedSegments.length);
        expect(result.playedSegments, expectedSegments.length);
        expect(result.failedSegments, 0);

        final letterRe = RegExp(r'\p{L}', unicode: true);
        for (final t in backend.playLog) {
          expect(letterRe.hasMatch(t), isTrue,
              reason: 'Segment gan nhu im lang duoc gui sang TTS: "$t"');
        }
      },
    );
  });
}
