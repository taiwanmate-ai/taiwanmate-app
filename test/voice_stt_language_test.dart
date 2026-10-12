/// Chon ngon ngu nhan dien giong noi Voice (2026-10-13, Dot 2): enum/tuy chon, nho lua chon theo user, widget, giao thuc voice_features + stt_language.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chinesemate/features/chat/engines/voice_stt_language.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';
import 'package:chinesemate/features/chat/presentation/widgets/voice_language_selector.dart';

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VoiceSttLanguage', () {
    test('fromWire: gia tri la/null -> auto', () {
      expect(VoiceSttLanguage.fromWire('zh'), VoiceSttLanguage.zh);
      expect(VoiceSttLanguage.fromWire('vi'), VoiceSttLanguage.vi);
      expect(VoiceSttLanguage.fromWire('en'), VoiceSttLanguage.en);
      expect(VoiceSttLanguage.fromWire('xx'), VoiceSttLanguage.auto);
      expect(VoiceSttLanguage.fromWire(null), VoiceSttLanguage.auto);
    });

    test('tuy chon: Tu dong | 中文 | Tiếng Việt; them English chi khi bai la en; server gioi han thi loc theo server', () {
      expect(voiceSttLanguageOptions(learningMode: 'zh_vi').map((l) => l.label), ['Tự động', '中文', 'Tiếng Việt']);
      expect(voiceSttLanguageOptions(learningMode: 'zh_only').length, 3);
      expect(voiceSttLanguageOptions(learningMode: 'en_vi').map((l) => l.wire), ['auto', 'zh', 'vi', 'en']);
      expect(voiceSttLanguageOptions(learningMode: 'en_only').last, VoiceSttLanguage.en);
      expect(voiceSttLanguageOptions(learningMode: 'en_vi', serverOptions: ['auto', 'zh', 'vi']).map((l) => l.wire), ['auto', 'zh', 'vi']);
      expect(voiceSttLanguageOptions(learningMode: 'zh_vi', serverOptions: const []).length, 3);
    });
  });

  group('VoiceSttLanguageStore — nho lua chon cuoi theo tung nguoi dung', () {
    test('mac dinh Tu dong; luu roi doc lai; moi user mot khoa rieng', () async {
      const store = VoiceSttLanguageStore();
      expect(await store.load('u1'), VoiceSttLanguage.auto);
      await store.save('u1', VoiceSttLanguage.zh);
      await store.save('u2', VoiceSttLanguage.vi);
      expect(await store.load('u1'), VoiceSttLanguage.zh);
      expect(await store.load('u2'), VoiceSttLanguage.vi);
      expect(await store.load('u3'), VoiceSttLanguage.auto);
      expect(await store.load(null), VoiceSttLanguage.auto);
      expect(VoiceSttLanguageStore.keyFor('u1'), isNot(VoiceSttLanguageStore.keyFor('u2')));
    });

    test('gia tri hong trong bo nho -> Tu dong', () async {
      SharedPreferences.setMockInitialValues({VoiceSttLanguageStore.keyFor('u1'): 'klingon'});
      expect(await const VoiceSttLanguageStore().load('u1'), VoiceSttLanguage.auto);
    });
  });

  group('VoiceLanguageSelector', () {
    testWidgets('hien dung cac chip, danh dau lua chon, 1 cham doi lua chon', (tester) async {
      var selected = VoiceSttLanguage.auto;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            return VoiceLanguageSelector(
              options: voiceSttLanguageOptions(learningMode: 'zh_vi'),
              selected: selected,
              onChanged: (l) => setState(() => selected = l),
            );
          }),
        ),
      ));
      expect(find.text('Tự động'), findsOneWidget);
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(VoiceLanguageSelector.keyFor(VoiceSttLanguage.auto))).selected, isTrue);

      await tester.tap(find.byKey(VoiceLanguageSelector.keyFor(VoiceSttLanguage.zh)));
      await tester.pump();
      expect(selected, VoiceSttLanguage.zh);
      expect(tester.widget<ChoiceChip>(find.byKey(VoiceLanguageSelector.keyFor(VoiceSttLanguage.zh))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(VoiceLanguageSelector.keyFor(VoiceSttLanguage.auto))).selected, isFalse);
    });

    testWidgets('man hep (320px) khong tran ngang du co 4 lua chon', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VoiceLanguageSelector(
            options: voiceSttLanguageOptions(learningMode: 'en_vi'),
            selected: VoiceSttLanguage.auto,
            onChanged: (_) {},
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('VoiceWebSocketService — voice_features + stt_language', () {
    test('voice_features -> onVoiceFeatures(selector, options); thieu truong -> false/rong', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final got = <String>[];
      svc.onVoiceFeatures = (sel, opts) => got.add('$sel:${opts.join(",")}');
      svc.handleRawMessageForTesting(jsonEncode({'type': 'voice_features', 'stt_language_selector': true, 'stt_language_options': ['auto', 'zh', 'vi', 'en']}));
      svc.handleRawMessageForTesting(jsonEncode({'type': 'voice_features'}));
      expect(got, ['true:auto,zh,vi,en', 'false:']);
    });

    test('sendAudioEnd chi them stt_language khi duoc truyen (tai khoan khac van gui y het nhu cu)', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final ch = _FakeChannel();
      svc.attachChannelForTesting(ch);
      svc.sendAudioEnd(systemPrompt: 'p', learningMode: 'zh_vi');
      svc.sendAudioEnd(systemPrompt: 'p', learningMode: 'zh_vi', sttLanguage: 'zh');
      final a = jsonDecode(ch.fakeSink.sent[0] as String) as Map<String, dynamic>;
      final b = jsonDecode(ch.fakeSink.sent[1] as String) as Map<String, dynamic>;
      expect(a.containsKey('stt_language'), isFalse);
      expect(a['type'], 'audio_end');
      expect(b['stt_language'], 'zh');
      expect(b['learning_mode'], 'zh_vi');
    });
  });
}
