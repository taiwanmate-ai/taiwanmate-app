/// Voice "Noi lai" + do do tre phia app (2026-10-12, Dot 1 muc 3-5).
/// Dung lop THAT: VoiceTurnState / VoiceLatencyTracker / VoiceTurnCoordinator / VoiceTranscriptBar / VoiceWebSocketService
/// (handleRawMessageForTesting) / CompanionVoiceController (streaming hooks). Man hinh Voice chi them phan UI.
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';
import 'package:chinesemate/features/chat/engines/voice_turn_tracking.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';
import 'package:chinesemate/features/chat/presentation/widgets/voice_transcript_bar.dart';

class _Clock {
  int now = 1000;
  int call() => now;
}

void main() {
  group('VoiceTurnState', () {
    test('co the Noi lai khi la luot mic co turn_id; requestRedo tra ve turn_id va xoa luot', () {
      final s = VoiceTurnState();
      s.onTranscript('Xin chào', 7, fromMic: true);
      expect(s.canRedo, isTrue);
      expect(s.requestRedo(), 7);
      expect(s.canRedo, isFalse);
      expect(s.transcript, '');
      expect(s.requestRedo(), isNull, reason: 'bam 2 lan khong gui discard 2 lan');
    });

    test('khong Noi lai duoc: luot go chu, server cu khong gui turn_id, chua co transcript', () {
      final s = VoiceTurnState();
      expect(s.canRedo, isFalse);
      s.onTranscript('abc', 3, fromMic: false);
      expect(s.canRedo, isFalse);
      s.onTranscript('abc', null, fromMic: true);
      expect(s.canRedo, isFalse);
      s.onTranscript('', 4, fromMic: true);
      expect(s.canRedo, isFalse);
    });

    test('sau khi Noi lai: bo qua chunk AI cho toi khi co ack turn_discarded', () {
      final s = VoiceTurnState();
      s.onTranscript('x', 1, fromMic: true);
      expect(s.shouldIgnoreAiChunks, isFalse);
      s.requestRedo();
      expect(s.shouldIgnoreAiChunks, isTrue);
      s.onDiscardAck();
      expect(s.shouldIgnoreAiChunks, isFalse);
      s.onDiscardAck(); // ack thua khong lam am
      expect(s.shouldIgnoreAiChunks, isFalse);
    });

    test('Noi lai 2 luot lien tiep: phai du 2 ack moi het bo qua', () {
      final s = VoiceTurnState();
      s.onTranscript('a', 1, fromMic: true);
      s.requestRedo();
      s.onTranscript('b', 2, fromMic: true);
      s.requestRedo();
      s.onDiscardAck();
      expect(s.shouldIgnoreAiChunks, isTrue);
      s.onDiscardAck();
      expect(s.shouldIgnoreAiChunks, isFalse);
    });

    test('reset (dung phien) xoa luon ack dang cho', () {
      final s = VoiceTurnState();
      s.onTranscript('a', 1, fromMic: true);
      s.requestRedo();
      s.reset();
      expect(s.shouldIgnoreAiChunks, isFalse);
    });
  });

  group('VoiceLatencyTracker', () {
    late _Clock clock;
    late List<Map<String, dynamic>> sent;
    late List<String> logs;
    VoiceLatencyTracker make({void Function(Map<String, dynamic>)? send}) => VoiceLatencyTracker(
          platform: 'web',
          sendReport: send ?? (r) => sent.add(r),
          nowMs: clock.call,
          log: logs.add,
        );
    setUp(() {
      clock = _Clock();
      sent = [];
      logs = [];
    });

    test('du 4 moc: bao cao dung so ms, log console + gui backend dung 1 lan', () {
      final t = make();
      t.markRelease();
      clock.now += 1200;
      t.markTranscript(5);
      clock.now += 1500;
      t.markFirstAudio();
      clock.now += 20;
      t.markPlaybackStart();
      expect(sent, hasLength(1));
      expect(sent.single, {
        'type': 'client_latency',
        'turn_id': 5,
        'release_to_transcript_ms': 1200,
        'release_to_first_audio_ms': 2700,
        'release_to_playback_ms': 2720,
        'platform': 'web',
      });
      expect(logs.single, startsWith('[VOICE_LATENCY] '));
      expect(jsonDecode(logs.single.substring('[VOICE_LATENCY] '.length))['release_to_playback_ms'], 2720);
      // cac moc sau khi da bao cao khong tao bao cao thu 2
      t.markFirstAudio();
      t.markPlaybackStart();
      t.abandon();
      expect(sent, hasLength(1));
    });

    test('moc chi ghi nhan lan DAU (transcript/audio lap lai khong ghi de)', () {
      final t = make();
      t.markRelease();
      clock.now += 100;
      t.markTranscript(1);
      clock.now += 900;
      t.markTranscript(99);
      t.markFirstAudio();
      clock.now += 500;
      t.markFirstAudio();
      t.markPlaybackStart();
      expect(sent.single['release_to_transcript_ms'], 100);
      expect(sent.single['turn_id'], 1);
      expect(sent.single['release_to_first_audio_ms'], 1000);
    });

    test('chua tha nut (khong luot dang do) thi moc bi bo qua, khong bao cao', () {
      final t = make();
      t.markTranscript(1);
      t.markFirstAudio();
      t.markPlaybackStart();
      expect(sent, isEmpty);
      expect(t.isActive, isFalse);
    });

    test('luot bi huy giua chung (loi / Noi lai): bao cao phan da do, cac moc con lai null', () {
      final t = make();
      t.markRelease();
      clock.now += 800;
      t.markTranscript(2);
      t.abandon();
      expect(sent.single['release_to_transcript_ms'], 800);
      expect(sent.single['release_to_first_audio_ms'], isNull);
      expect(sent.single['release_to_playback_ms'], isNull);
    });

    test('luot huy khi chua co gi (khong co transcript) thi khong bao cao', () {
      final t = make();
      t.markRelease();
      t.abandon();
      expect(sent, isEmpty);
    });

    test('markRelease moi bat dau luot moi, bo luot cu chua bao cao', () {
      final t = make();
      t.markRelease();
      clock.now += 5000;
      t.markTranscript(1);
      t.markRelease();
      clock.now += 300;
      t.markTranscript(2);
      t.abandon();
      expect(sent.single['turn_id'], 2);
      expect(sent.single['release_to_transcript_ms'], 300);
    });

    test('gui bao cao that bai (ket noi dong) khong lam hong luong chinh', () {
      final t = make(send: (_) => throw StateError('socket closed'));
      t.markRelease();
      t.markTranscript(1);
      t.markFirstAudio();
      expect(() => t.markPlaybackStart(), returnsNormally);
      expect(logs, hasLength(1));
    });
  });

  group('Controller streaming — moc audio dau tien', () {
    test('onStreamingFirstAudioReceived/PlaybackStart chi goi 1 lan cho ca phien, TRUOC khi phat; loi trong callback khong chan phat', () async {
      final events = <String>[];
      final controller = CompanionVoiceController(
        tokenProvider: () async => 't',
        ttsFetcher: (text, lang, gender, token) async => utf8.encode('A[$text]'),
        audioPlayer: (bytes) async {
          events.add('play');
          return true;
        },
      );
      controller.onStreamingFirstAudioReceived = () => events.add('first_audio');
      controller.onStreamingPlaybackStart = () {
        events.add('playback_start');
        throw StateError('callback loi');
      };
      controller.startStreamingSpeak(aiGender: 'female');
      controller.appendStreamingSentence('Câu một.', aiGender: 'female');
      controller.appendStreamingSentence('Câu hai.', aiGender: 'female');
      controller.finishStreamingSpeak();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(events, ['first_audio', 'playback_start', 'play', 'play']);
      controller.dispose();
    });
  });

  group('VoiceWebSocketService — giao thuc Noi lai', () {
    test('transcript co turn_id -> onTranscriptWithTurnId (va onTranscript cu van chay); thieu turn_id -> null', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final got = <String>[];
      svc.onTranscript = (t) => got.add('plain:$t');
      svc.onTranscriptWithTurnId = (t, id) => got.add('turn:$t:$id');
      svc.handleRawMessageForTesting(jsonEncode({'type': 'transcript', 'text': 'Xin chào', 'turn_id': 4}));
      svc.handleRawMessageForTesting(jsonEncode({'type': 'transcript', 'text': 'cu'}));
      svc.handleRawMessageForTesting(jsonEncode({'type': 'transcript', 'text': 'sai', 'turn_id': '9'}));
      expect(got, ['plain:Xin chào', 'turn:Xin chào:4', 'plain:cu', 'turn:cu:null', 'plain:sai', 'turn:sai:null']);
    });

    test('turn_discarded -> onTurnDiscarded(turnId, stage)', () {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final got = <String>[];
      svc.onTurnDiscarded = (id, stage) => got.add('$id:$stage');
      svc.handleRawMessageForTesting(jsonEncode({'type': 'turn_discarded', 'turn_id': 2, 'stage': 'in_flight'}));
      svc.handleRawMessageForTesting(jsonEncode({'type': 'turn_discarded'}));
      expect(got, ['2:in_flight', 'null:unknown']);
    });
  });

  group('VoiceTranscriptBar + luong Noi lai (service -> state -> bar -> coordinator)', () {
    testWidgets('hien "🎤 Mình nghe: ..." ngay khi co transcript; bam "Nói lại" -> dung phat + gui discard_turn dung turn_id; bar bien mat', (tester) async {
      final svc = VoiceWebSocketService(tokenProvider: () async => 't');
      final state = VoiceTurnState();
      final clock = _Clock();
      final reports = <Map<String, dynamic>>[];
      final latency = VoiceLatencyTracker(platform: 'android', sendReport: reports.add, nowMs: clock.call, log: (_) {});
      var stopped = 0;
      final discards = <int>[];
      final coordinator = VoiceTurnCoordinator(
        state: state,
        latency: latency,
        stopSpeaking: () => stopped++,
        sendDiscardTurn: discards.add,
      );
      String transcript = '';
      late StateSetter rebuild;

      latency.markRelease();
      svc.onTranscriptWithTurnId = (text, id) {
        state.onTranscript(text, id, fromMic: latency.isActive);
        latency.markTranscript(id);
        rebuild(() => transcript = text);
      };

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return transcript.isEmpty
                ? const SizedBox()
                : VoiceTranscriptBar(
                    text: transcript,
                    onRedo: state.canRedo
                        ? () {
                            coordinator.redo();
                            setState(() => transcript = '');
                          }
                        : null,
                  );
          }),
        ),
      ));
      expect(find.byKey(VoiceTranscriptBar.textKey), findsNothing);

      clock.now += 900;
      svc.handleRawMessageForTesting(jsonEncode({'type': 'transcript', 'text': 'Tôi muốn mua trà sữa', 'turn_id': 3}));
      await tester.pump();
      expect(find.text('🎤 Mình nghe: Tôi muốn mua trà sữa'), findsOneWidget);
      expect(find.byKey(VoiceTranscriptBar.redoButtonKey), findsOneWidget);
      expect(find.text('Nói lại'), findsOneWidget);

      await tester.tap(find.byKey(VoiceTranscriptBar.redoButtonKey));
      await tester.pump();
      expect(discards, [3]);
      expect(stopped, 1);
      expect(find.byKey(VoiceTranscriptBar.textKey), findsNothing);
      expect(state.shouldIgnoreAiChunks, isTrue, reason: 'chunk AI con sot cua luot bi bo phai bi bo qua');
      expect(reports.single['release_to_transcript_ms'], 900, reason: 'luot bi huy van bao cao do tre transcript');
      expect(reports.single['platform'], 'android');

      svc.onTurnDiscarded = (id, stage) => state.onDiscardAck();
      svc.handleRawMessageForTesting(jsonEncode({'type': 'turn_discarded', 'turn_id': 3, 'stage': 'in_flight'}));
      expect(state.shouldIgnoreAiChunks, isFalse);
    });

    testWidgets('onRedo = null (go chu / server cu) -> khong co nut Noi lai', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VoiceTranscriptBar(text: 'abc'))));
      expect(find.text('🎤 Mình nghe: abc'), findsOneWidget);
      expect(find.byKey(VoiceTranscriptBar.redoButtonKey), findsNothing);
    });

    test('coordinator.redo khi khong co luot nao: khong gui gi', () {
      var sentCount = 0;
      final c = VoiceTurnCoordinator(
        state: VoiceTurnState(),
        latency: VoiceLatencyTracker(platform: 'web', sendReport: (_) {}),
        stopSpeaking: () => sentCount++,
        sendDiscardTurn: (_) => sentCount++,
      );
      expect(c.redo(), isFalse);
      expect(sentCount, 0);
    });
  });
}
