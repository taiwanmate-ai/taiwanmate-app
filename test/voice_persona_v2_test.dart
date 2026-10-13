/// Persona Voice v2 phia app (2026-10-14): gui ai_gender, xin giong TTS v2 chi khi server bao, khong doi gi voi tai khoan khac.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';

class _Sink implements WebSocketSink {
  final List<dynamic> sent = [];
  @override
  void add(dynamic data) => sent.add(data);
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _FakeChannel implements WebSocketChannel {
  final _Sink fakeSink = _Sink();
  @override
  WebSocketSink get sink => fakeSink;
  @override
  Stream get stream => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('request TTS /translate/tts-mixed', () {
    test('mac dinh KHONG co persona (giong het truoc day); co persona thi gui "v2"', () {
      expect(CompanionVoiceController.buildTtsRequestBody('Xin chào', 'female', 'vi'), {'text': 'Xin chào', 'gender': 'female', 'lang': 'vi'});
      expect(CompanionVoiceController.buildTtsRequestBody('Xin chào', 'male', 'vi', mood: 'comforting', persona: 'v2'),
          {'text': 'Xin chào', 'gender': 'male', 'lang': 'vi', 'mood': 'comforting', 'persona': 'v2'});
      expect(CompanionVoiceController.buildTtsRequestBody('你好', 'female', 'zh', persona: 'v2').containsKey('mood'), isFalse);
    });

    test('voicePersona la thuoc tinh cua controller, mac dinh null', () {
      final c = CompanionVoiceController(tokenProvider: () async => 't');
      expect(c.voicePersona, isNull);
      c.voicePersona = 'v2';
      expect(c.voicePersona, 'v2');
      c.dispose();
    });
  });

  group('giao thuc voice_features + ai_gender', () {
    test('persona_v2 trong voice_features -> tham so thu 3; thieu -> false', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final got = <bool>[];
      svc.onVoiceFeatures = (sel, opts, persona) => got.add(persona);
      svc.handleRawMessageForTesting(jsonEncode({'type': 'voice_features', 'stt_language_selector': false, 'persona_v2': true}));
      svc.handleRawMessageForTesting(jsonEncode({'type': 'voice_features', 'stt_language_selector': true}));
      expect(got, [true, false]);
    });

    test('sendAudioEnd/sendTextInput chi them ai_gender khi duoc truyen', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final ch = _FakeChannel();
      svc.attachChannelForTesting(ch);
      svc.sendAudioEnd(systemPrompt: 'p', learningMode: 'zh_vi');
      svc.sendAudioEnd(systemPrompt: 'p', learningMode: 'zh_vi', aiGender: 'male');
      svc.sendTextInput('xin chào', systemPrompt: 'p', learningMode: 'zh_vi');
      svc.sendTextInput('xin chào', systemPrompt: 'p', learningMode: 'zh_vi', aiGender: 'female');
      final m = ch.fakeSink.sent.map((e) => jsonDecode(e as String) as Map<String, dynamic>).toList();
      expect(m[0].containsKey('ai_gender'), isFalse);
      expect(m[1]['ai_gender'], 'male');
      expect(m[2].containsKey('ai_gender'), isFalse);
      expect(m[3]['ai_gender'], 'female');
    });
  });
}
