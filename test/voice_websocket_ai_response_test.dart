/// Buoc 4a (2026-08-15) — kiem tra luong "gia lap toan bo": transcript
/// gia -> ai_text_response gia -> xac nhan Flutter nhan dung -> goi DUNG
/// pipeline TTS hien co (CompanionVoiceController), khong viet logic TTS
/// moi.
///
/// Buoc 4b (2026-08-15) — NANG CAP: server gio gui
/// {"type":"ai_text_response_chunk","text":...,"is_final":...} STREAMING
/// that (xem voice_websocket_service.dart), khong con
/// {"type":"ai_text_response"} 1-lan nua. File nay chuyen sang test
/// WIRING THAT SU giua 3 lop doc lap da duoc test rieng o noi khac:
///   VoiceWebSocketService (protocol, test rieng o day)
///   -> SentenceAccumulator (gom delta thanh cau, test rieng o
///      sentence_accumulator_test.dart)
///   -> CompanionVoiceController streaming API (phat TTS tung cau, test
///      rieng o companion_voice_controller_streaming_test.dart)
/// Day la "keo dan" dai dien cho 1 orchestrator/man hinh that se lam o
/// Lop 6 — dung LAI ca 3 lop KHONG SUA GI, chi noi chung lai bang closure
/// trong test, giong dung tinh than "moi lop 1 trach nhiem, wiring la
/// viec cua caller" da neu trong docstring VoiceWebSocketService.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';
import 'package:chinesemate/features/chat/engines/sentence_accumulator.dart';

/// Sao chep tu companion_voice_controller_test.dart (khong import test
/// khac — moi file test doc lap) — GIU NGUYEN hanh vi gia lap TTS backend
/// da dung cho toan bo cac test CompanionVoiceController khac trong repo.
class _FakeTtsBackend {
  _FakeTtsBackend({this.perCallLatency = const Duration(milliseconds: 5)});
  final Duration perCallLatency;
  final List<String> fetchLog = [];
  final List<String> playLog = [];

  Future<List<int>?> Function(String, String, String, String) get fetcher =>
      (text, lang, gender, token) async {
        fetchLog.add('$lang:$text');
        await Future<void>.delayed(perCallLatency);
        return utf8.encode('AUDIO[$text]');
      };

  Future<bool> Function(List<int>) get player => (bytes) async {
        final text = utf8.decode(bytes).replaceFirst('AUDIO[', '').replaceFirst(']', '');
        playLog.add(text);
        return true;
      };
}

/// Noi VoiceWebSocketService + SentenceAccumulator + CompanionVoiceController
/// streaming API lai voi nhau — dung 1 ham helper de KHONG lap lai closure
/// nay o moi test (nhung logic wiring VAN o day, khong an vao 1 class
/// production moi — dung y "chua xay orchestrator that, Lop 6 se lam").
void _wireStreamingPipeline(VoiceWebSocketService wsService, CompanionVoiceController voiceController) {
  final accumulator = SentenceAccumulator();
  wsService.onAiTextResponseChunk = (text, isFinal) {
    if (isFinal) {
      final remainder = accumulator.flush();
      if (remainder.isNotEmpty) {
        voiceController.appendStreamingSentence(remainder, aiGender: 'female');
      }
      voiceController.finishStreamingSpeak();
      return;
    }
    final sentences = accumulator.addDelta(text);
    for (final s in sentences) {
      voiceController.appendStreamingSentence(s, aiGender: 'female');
    }
  };
}

void main() {
  group('Buoc 4b — wiring that: VoiceWebSocketService chunk -> SentenceAccumulator -> CompanionVoiceController streaming', () {
    test('Nhieu chunk gom du 2 cau hoan chinh -> ca 2 cau duoc TTS phat DUNG THU TU, chi khi du dau cau', () async {
      final backend = _FakeTtsBackend();
      final voiceController = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');
      _wireStreamingPipeline(wsService, voiceController);

      voiceController.startStreamingSpeak(aiGender: 'female');

      for (final delta in ['Xin ', 'chào', '! ', 'Hôm ', 'nay ', 'trời ', 'đẹp', '.']) {
        wsService.handleRawMessageForTesting(
          jsonEncode({'type': 'ai_text_response_chunk', 'text': delta, 'is_final': false}),
        );
      }
      wsService.handleRawMessageForTesting(
        jsonEncode({'type': 'ai_text_response_chunk', 'text': '', 'is_final': true}),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(backend.playLog, ['Xin chào!', 'Hôm nay trời đẹp.'],
          reason: 'Moi cau phai duoc phat DUNG LUC co du dau cau, dung thu tu, khong lap/mat');
      expect(voiceController.isSpeaking, isFalse);

      voiceController.dispose();
      wsService.dispose();
    });

    test('Chunk cuoi (is_final=true) con sot lai text CHUA co dau cau -> van duoc flush() va phat (khong mat cau cuoi)', () async {
      final backend = _FakeTtsBackend();
      final voiceController = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');
      _wireStreamingPipeline(wsService, voiceController);

      voiceController.startStreamingSpeak(aiGender: 'female');

      wsService.handleRawMessageForTesting(
        jsonEncode({'type': 'ai_text_response_chunk', 'text': 'Câu không có dấu chấm cuối', 'is_final': false}),
      );
      wsService.handleRawMessageForTesting(
        jsonEncode({'type': 'ai_text_response_chunk', 'text': '', 'is_final': true}),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(backend.playLog, ['Câu không có dấu chấm cuối'],
          reason: 'AI ket thuc ma khong co dau cau cuoi van khong duoc mat noi dung');

      voiceController.dispose();
      wsService.dispose();
    });

    test('ai_text_response_error KHONG goi TTS (khong co gi de phat, chua tung startStreamingSpeak)', () async {
      final backend = _FakeTtsBackend();
      final voiceController = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');
      _wireStreamingPipeline(wsService, voiceController);

      String? capturedError;
      wsService.onAiTextResponseError = (message) {
        capturedError = message;
      };

      wsService.handleRawMessageForTesting(
        jsonEncode({'type': 'ai_text_response_error', 'message': 'Không tạo được câu trả lời'}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(capturedError, 'Không tạo được câu trả lời');
      expect(backend.fetchLog, isEmpty, reason: 'ai_text_response_error khong co text -> khong duoc goi TTS');

      voiceController.dispose();
      wsService.dispose();
    });

    test('transcript va transcript_error callback nhan dung du lieu (Buoc 3, kiem tra lai qua service)', () {
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');
      String? capturedTranscript;
      String? capturedTranscriptError;
      wsService.onTranscript = (text) => capturedTranscript = text;
      wsService.onTranscriptError = (message) => capturedTranscriptError = message;

      wsService.handleRawMessageForTesting(jsonEncode({'type': 'transcript', 'text': 'xin chào bạn'}));
      expect(capturedTranscript, 'xin chào bạn');

      wsService.handleRawMessageForTesting(jsonEncode({'type': 'transcript_error', 'message': 'Không nhận diện được giọng nói'}));
      expect(capturedTranscriptError, 'Không nhận diện được giọng nói');

      wsService.dispose();
    });

    test('transcript_low_confidence (Whisper Confidence Gate) -> callback nhan dung text+message, KHONG goi onTranscript/onAiTextResponseChunk', () async {
      final backend = _FakeTtsBackend();
      final voiceController = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');

      String? capturedText;
      String? capturedMessage;
      wsService.onTranscriptLowConfidence = (text, message) {
        capturedText = text;
        capturedMessage = message;
        // Mo phong dung y VoiceChatScreen: phat lai message qua TTS thay
        // vi coi text la cau tra loi dang tin cay.
        voiceController.speak(message, aiGender: 'female', learningMode: 'zh_vi');
      };
      wsService.onTranscript = (text) => fail('KHONG duoc goi onTranscript khi low_confidence');
      _wireStreamingPipeline(wsService, voiceController);

      wsService.handleRawMessageForTesting(jsonEncode({
        'type': 'transcript_low_confidence',
        'text': 'cau nghe khong ro',
        'message': 'Mình nghe chưa rõ lắm, bạn nói lại được không?',
      }));

      expect(capturedText, 'cau nghe khong ro');
      expect(capturedMessage, 'Mình nghe chưa rõ lắm, bạn nói lại được không?');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(backend.playLog, ['Mình nghe chưa rõ lắm, bạn nói lại được không?'],
          reason: 'Message xac nhan phai duoc phat qua TTS, giong phan ung nguoi that xin noi lai');

      voiceController.dispose();
      wsService.dispose();
    });

    test('Message type khong lien quan (vd pong/error/audio_received) KHONG goi nham callback TTS', () async {
      final backend = _FakeTtsBackend();
      final voiceController = CompanionVoiceController(
        tokenProvider: () async => 'fake-token',
        ttsFetcher: backend.fetcher,
        audioPlayer: backend.player,
      );
      final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');
      _wireStreamingPipeline(wsService, voiceController);

      wsService.handleRawMessageForTesting(jsonEncode({'type': 'pong'}));
      wsService.handleRawMessageForTesting(jsonEncode({'type': 'error', 'message': 'loi khong lien quan'}));
      wsService.handleRawMessageForTesting(jsonEncode({'type': 'audio_received', 'total_bytes': 10}));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(backend.fetchLog, isEmpty);

      voiceController.dispose();
      wsService.dispose();
    });
  });
}
