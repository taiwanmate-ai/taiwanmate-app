/// Buoc 4b (2026-08-15) — DO THUC TE time-to-first-audio giua Buoc 4a
/// (doi AI sinh XONG TOAN BO cau tra loi roi moi goi speak() 1 lan) va
/// Buoc 4b (bat dau TTS cau dau tien NGAY KHI cau do san sang, khong doi
/// cac cau sau). Yeu cau ro rang tu nguoi dung: "Đo lại time-to-first-audio
/// thực tế so với Bước 4a, xác nhận có cải thiện đáng kể không" — file nay
/// la bang chung DO DUOC (khong chi suy luan ly thuyet).
///
/// Mo hinh gia lap: AI can genDelaySentence1 de sinh xong CAU DAU, roi
/// them genDelaySentence2 de sinh xong CAU HAI (giong dung nhip 1 AI
/// streaming that — cau sau luon den SAU cau truoc). TTS fetch mat
/// ttsFetchLatency co dinh cho MOI cau (gia lap goi API TTS that).
///
///   Buoc 4a: tong thoi gian tu luc AI BAT DAU sinh -> co audio dau tien
///     = genDelaySentence1 + genDelaySentence2 + ttsFetchLatency
///     (PHAI doi CA 2 cau sinh xong vi speak() chi goi 1 lan sau cung).
///   Buoc 4b: tong thoi gian tuong tu
///     = genDelaySentence1 + ttsFetchLatency
///     (TTS cau 1 bat dau ngay sau khi cau 1 san sang, KHONG doi cau 2).
///
/// Chenh lech ly thuyet = genDelaySentence2 — CHINH LA thoi gian sinh cau
/// thu 2, dung tinh than "giam do tre bang cach bat dau TTS cau dau trong
/// khi AI van dang sinh cau sau" ma nguoi dung yeu cau.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';

class _FakeTtsBackend {
  _FakeTtsBackend({required this.perCallLatency});
  final Duration perCallLatency;
  final List<String> playLog = [];

  Future<List<int>?> Function(String, String, String, String) get fetcher =>
      (text, lang, gender, token) async {
        await Future<void>.delayed(perCallLatency);
        return utf8.encode('AUDIO[$text]');
      };

  Future<bool> Function(List<int>) get player => (bytes) async {
        final text = utf8.decode(bytes).replaceFirst('AUDIO[', '').replaceFirst(']', '');
        playLog.add(text);
        return true;
      };
}

void main() {
  test('SO SANH THUC TE: Buoc 4b (streaming) co time-to-first-audio THAP HON Buoc 4a (doi full text) mot khoang = thoi gian sinh cau 2', () async {
    const genDelaySentence1 = Duration(milliseconds: 150);
    const genDelaySentence2 = Duration(milliseconds: 150);
    const ttsFetchLatency = Duration(milliseconds: 100);

    // ---- Buoc 4a: mo phong "gom het roi goi speak() 1 lan" ----
    final backendA = _FakeTtsBackend(perCallLatency: ttsFetchLatency);
    final controllerA = CompanionVoiceController(
      tokenProvider: () async => 'fake-token',
      ttsFetcher: backendA.fetcher,
      audioPlayer: backendA.player,
    );
    await Future<void>.delayed(genDelaySentence1);
    await Future<void>.delayed(genDelaySentence2); // AI sinh xong CA 2 cau moi goi speak()
    final resultA = await controllerA.speak(
      'Câu một đây. Câu hai đây.',
      aiGender: 'female',
      learningMode: 'zh_vi',
    );
    final ttfaWithinSpeakA = resultA.timeToFirstAudio ?? Duration.zero;
    final totalElapsedA = genDelaySentence1 + genDelaySentence2 + ttfaWithinSpeakA;
    controllerA.dispose();

    // ---- Buoc 4b: mo phong streaming that — append cau 1 ngay khi san sang ----
    final backendB = _FakeTtsBackend(perCallLatency: ttsFetchLatency);
    final controllerB = CompanionVoiceController(
      tokenProvider: () async => 'fake-token',
      ttsFetcher: backendB.fetcher,
      audioPlayer: backendB.player,
    );
    controllerB.startStreamingSpeak(aiGender: 'female');
    await Future<void>.delayed(genDelaySentence1);
    controllerB.appendStreamingSentence('Câu một đây.', aiGender: 'female');
    await Future<void>.delayed(genDelaySentence2);
    controllerB.appendStreamingSentence('Câu hai đây.', aiGender: 'female');
    controllerB.finishStreamingSpeak();
    await Future<void>.delayed(const Duration(milliseconds: 400)); // doi phat xong het
    // QUAN TRONG: _streamingStopwatch bat dau NGAY LUC startStreamingSpeak()
    // duoc goi (TRUOC ca genDelaySentence1) — khac voi speak() (stopwatch
    // bat dau NGAY LUC speak() duoc goi, tuc SAU CA 2 gen delay o kich ban
    // Buoc 4a). Vi vay lastStreamingTimeToFirstAudio o day DA BAO GOM san
    // genDelaySentence1 ben trong no — KHONG duoc cong them lan nua.
    final totalElapsedB = controllerB.lastStreamingTimeToFirstAudio ?? Duration.zero;
    controllerB.dispose();

    // ignore: avoid_print
    print(
      '[SO SANH TTFA] Buoc4a: genCau1=${genDelaySentence1.inMilliseconds}ms + genCau2=${genDelaySentence2.inMilliseconds}ms + '
      'ttsFetch=${ttfaWithinSpeakA.inMilliseconds}ms = TONG ${totalElapsedA.inMilliseconds}ms  |  '
      'Buoc4b: (genCau1 + ttsFetch, do lien tuc tu startStreamingSpeak) = TONG ${totalElapsedB.inMilliseconds}ms  |  '
      'CAI THIEN = ${totalElapsedA.inMilliseconds - totalElapsedB.inMilliseconds}ms',
    );

    // speak() TU NO cung dung MultilingualTtsSegmenter tach cau giong het
    // appendStreamingSentence() — ca 2 kich ban deu phat 2 segment rieng,
    // CHI KHAC nhau O THOI DIEM fetch cau 1 bat dau (ngay vs doi ca 2 cau).
    expect(backendA.playLog, ['Câu một đây.', 'Câu hai đây.']);
    expect(backendB.playLog, ['Câu một đây.', 'Câu hai đây.']);

    // Buoc 4b PHAI nhanh hon Buoc 4a it nhat gan bang thoi gian sinh cau 2
    // (150ms) — cho bien do +-50ms cho overhead test/timer thuc te.
    final improvement = totalElapsedA - totalElapsedB;
    expect(improvement.inMilliseconds, greaterThan(100),
        reason: 'Streaming phai cai thien ro ret (ky vong ~150ms, gan bang thoi gian sinh cau 2) — neu khong thi Buoc 4b khong dat muc dich giam do tre');
  });
}
