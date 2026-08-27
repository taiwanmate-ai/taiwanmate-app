/// Buoc 4b (2026-08-15) — test rieng cho co che STREAMING moi
/// (startStreamingSpeak/appendStreamingSentence/finishStreamingSpeak),
/// TACH KHOI companion_voice_controller_test.dart (test speak() thuong)
/// de ro rang pham vi — 2 co che DOC LAP, khong dung chung 1 file test
/// tranh nham lan cai nao dang duoc kiem tra.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';

/// Sao chep cung mo hinh _FakeTtsBackend da dung o companion_voice_controller_test.dart
/// va voice_websocket_ai_response_test.dart — GIU NHAT QUAN cach gia lap
/// TTS backend trong toan bo repo, moi file test doc lap khong import test khac.
class _FakeTtsBackend {
  _FakeTtsBackend({this.perCallLatency = const Duration(milliseconds: 30), this.msPerChar = 5});
  final Duration perCallLatency;
  final int msPerChar;
  final List<String> fetchLog = [];
  final List<String> playLog = [];
  final List<DateTime> playStartTimes = [];
  final List<DateTime> playEndTimes = [];

  Future<List<int>?> Function(String, String, String, String) get fetcher =>
      (text, lang, gender, token) async {
        fetchLog.add('$lang:$text');
        await Future<void>.delayed(perCallLatency);
        return utf8.encode('AUDIO[$text]');
      };

  Future<bool> Function(List<int>) get player => (bytes) async {
        final text = utf8.decode(bytes).replaceFirst('AUDIO[', '').replaceFirst(']', '');
        playStartTimes.add(DateTime.now());
        playLog.add(text);
        await Future<void>.delayed(Duration(milliseconds: text.length * msPerChar));
        playEndTimes.add(DateTime.now());
        return true;
      };
}

void main() {
  group('Buoc 4b — streaming: cau moi KHONG cat ngang cau dang phat (khac speak() goi nhieu lan)', () {
    test('append 2 cau lien tiep NGAY LAP TUC (truoc khi cau 1 phat xong) -> CA 2 deu duoc phat DU, dung thu tu', () async {
      final backend = _FakeTtsBackend();
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Câu một.', aiGender: 'female');
      controller.appendStreamingSentence('Câu hai.', aiGender: 'female');
      controller.finishStreamingSpeak();

      // Doi toan bo chuoi (fetch + phat ca 2 cau) hoan tat.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(backend.playLog, ['Câu một.', 'Câu hai.'], reason: 'Ca 2 cau phai phat DU, DUNG THU TU — khong cau nao bi cat ngang');
      expect(controller.isSpeaking, isFalse, reason: 'finishStreamingSpeak() + het hang doi -> phien tu ket thuc');
      controller.dispose();
    });

    test('append 3 cau voi do tre KHONG DEU giua cac lan goi (mo phong AI stream that, toc do sinh chu khong on dinh) -> van dung thu tu, khong chong cheo', () async {
      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 20));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Một.', aiGender: 'female');
      await Future<void>.delayed(const Duration(milliseconds: 5)); // chunk den nhanh
      controller.appendStreamingSentence('Hai.', aiGender: 'female');
      await Future<void>.delayed(const Duration(milliseconds: 80)); // chunk den cham (AI dang "nghi")
      controller.appendStreamingSentence('Ba.', aiGender: 'female');
      controller.finishStreamingSpeak();

      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(backend.playLog, ['Một.', 'Hai.', 'Ba.']);
      // Khong co 2 lan phat nao CHONG THOI GIAN (playStart cua cau sau >= playEnd cua cau truoc).
      for (var i = 1; i < backend.playStartTimes.length; i++) {
        expect(
          backend.playStartTimes[i].isBefore(backend.playEndTimes[i - 1]),
          isFalse,
          reason: 'Cau #$i bat dau phat TRUOC KHI cau #${i - 1} phat xong — bi chong tieng',
        );
      }
      controller.dispose();
    });
  });

  group('Buoc 4b — do time-to-first-audio streaming', () {
    test('lastStreamingTimeToFirstAudio duoc ghi nhan, xap xi do tre fetch cau dau tien', () async {
      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 100));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Câu đầu tiên.', aiGender: 'female');
      controller.finishStreamingSpeak();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final ttfa = controller.lastStreamingTimeToFirstAudio;
      expect(ttfa, isNotNull);
      // ~100ms fetch cau dau -> ttfa phai nam trong khoang hop ly (co bien
      // do cho overhead test), KHONG duoc gan 0 (chua fetch xong da tinh)
      // hay qua lon (vd doi ca cau 2 moi tinh).
      expect(ttfa!.inMilliseconds, greaterThanOrEqualTo(90));
      expect(ttfa.inMilliseconds, lessThan(300));
      controller.dispose();
    });
  });

  group('Buoc 4b — chuan bi cho Lop 5 (Interrupt): stopSpeaking() giua streaming', () {
    test('stopSpeaking() khi cau 1 dang phat -> cau 2/3 con lai trong "hang doi" (chua append) KHONG duoc phat', () async {
      final backend = _FakeTtsBackend(perCallLatency: const Duration(milliseconds: 20));
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Câu một dài để có thời gian ngắt giữa chừng.', aiGender: 'female');

      // Doi vua du de cau 1 BAT DAU phat (qua fetch ~20ms) nhung CHUA xong
      // (text dai, phat mat nhieu hon).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(backend.playLog, isNotEmpty, reason: 'Cau 1 phai da bat dau phat truoc khi ngat');

      controller.stopSpeaking(); // Interrupt
      controller.appendStreamingSentence('Câu hai không được phát.', aiGender: 'female');
      controller.finishStreamingSpeak();

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(backend.playLog, isNot(contains('Câu hai không được phát.')),
          reason: 'Sau stopSpeaking(), cau append THEM vao (thuoc session CU, da bi vo hieu) khong duoc phat');
      expect(controller.isSpeaking, isFalse);
      controller.dispose();
    });

    test('stopSpeaking() ngay sau startStreamingSpeak() (chua kip append cau nao) -> khong crash, isSpeaking ve false', () {
      final backend = _FakeTtsBackend();
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      expect(controller.isSpeaking, isTrue);
      controller.stopSpeaking();
      expect(controller.isSpeaking, isFalse);
      controller.dispose();
    });
  });

  group('Buoc 4b — truong hop bien', () {
    test('appendStreamingSentence() truoc khi goi startStreamingSpeak() -> khong lam gi, khong crash', () {
      final backend = _FakeTtsBackend();
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      controller.appendStreamingSentence('Câu không hợp lệ.', aiGender: 'female');
      expect(backend.fetchLog, isEmpty);
      controller.dispose();
    });

    test('finishStreamingSpeak() ngay lap tuc (khong co cau nao duoc append) -> ket thuc phien sach, khong treo', () async {
      final backend = _FakeTtsBackend();
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      controller.startStreamingSpeak(aiGender: 'female');
      controller.finishStreamingSpeak();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isSpeaking, isFalse);
      controller.dispose();
    });

    test('1 segment trong 1 cau bi loi TTS (tra null) -> bo qua, cac cau khac van phat du (giong hanh vi _speakSegments)', () async {
      var callCount = 0;
      final backend = _FakeTtsBackend();
      final controller = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: (text, lang, gender, token) async {
          callCount++;
          if (text.contains('LOI')) return null; // gia lap segment nay loi ca 2 lan (retry cung loi)
          return backend.fetcher(text, lang, gender, token);
        },
        audioPlayer: backend.player,
      );

      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Câu LOI này.', aiGender: 'female');
      controller.appendStreamingSentence('Câu ổn định.', aiGender: 'female');
      controller.finishStreamingSpeak();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(backend.playLog, ['Câu ổn định.'], reason: 'Cau loi bi bo qua (khong crash), cau con lai van phat');
      expect(callCount, greaterThan(0));
      controller.dispose();
    });
  });
}
