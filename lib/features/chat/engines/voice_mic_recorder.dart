/// VoiceMicRecorder — Lop 6 (2026-08-15).
///
/// Ghi am mic THAT + phat bien do (dB) THAT, DUNG CHUNG 1 code path cho
/// CA Web va mobile qua package `record` (AudioRecorder) — xac nhan qua
/// doc source code truoc khi lam (khong doan): record_web (ban dang dung,
/// 2.1.1) co MediaRecorderDelegate dung Web Audio API AnalyserNode THAT
/// de tinh bien do song song voi ghi am opus/webm qua MediaRecorder cua
/// trinh duyet — KHONG phai gia lap/stub. Vi vay KHONG can tach 2 duong
/// di rieng (native dung record, web dung dart:html) nhu code ghi am CU
/// (xem web_utils_impl.dart/_stub.dart, viet truoc khi biet dieu nay) —
/// class nay dung THANG AudioRecorder cho ca 2 nen tang.
///
/// Encoder dung AudioEncoder.opus + duoi .webm — KHOP DUNG dinh dang
/// backend Whisper mong doi (transcribe_only(..., audio_format="webm")),
/// giong dung combo da xac nhan dung o Lop 3 (test_voice_websocket.py).
///
/// stop() tra ve gia tri KHAC NHAU theo nen tang (native: duong dan file
/// that; web: 1 blob: URL) — xem webReadRecordedBytes() (core/utils/
/// web_utils.dart) de doc bytes dung tren CA 2 nen tang qua 1 ham duy
/// nhat, TAI SU DUNG dung co che conditional-export co san cua app cho
/// van de nay (dart:io.File KHONG BIEN DICH duoc tren web).
library;

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chinesemate/core/utils/web_utils.dart';

class VoiceMicRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Xin quyen (neu chua co) va bat dau ghi am. Tra ve false neu KHONG co
  /// quyen mic hoac loi khoi tao — CALLER tu quyet dinh hien thi loi gi.
  Future<bool> start() async {
    if (_isRecording) return true;
    try {
      if (!await _recorder.hasPermission()) return false;

      // Path CHI thuc su can thiet tren native (AudioRecorder ghi ra file
      // that o do) — tren web, record_web's MediaRecorderDelegate KHONG
      // dung gia tri nay de ghi file that (no tu quan ly qua Blob noi
      // bo), nen 1 chuoi placeholder la du, KHONG can path_provider tren
      // web (path_provider khong co y nghia filesystem that o do).
      String path;
      if (kIsWeb) {
        path = 'voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      } else {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      }

      // echoCancel: true — giam (KHONG loai bo hoan toan) kha nang mic tu
      // bat lai am thanh AI dang phat qua loa (khong co tai nghe) thanh
      // "tieng noi" gia, gay interrupt nham. Day la co che khu vong native
      // cua trinh duyet/OS (getUserMedia echoCancellation tren web) — VAN
      // khuyen nghi dung tai nghe khi test that de tranh vong lap am thanh.
      //
      // noiseSuppress: BAT LAI (2026-08-15, sau khi doi chieu THAT qua
      // file debug voice_debug_last_audio.webm — xem docstring dau file
      // voice_ws.py phan TEMP DEBUG): nghe truc tiep file audio that xac
      // nhan giong noi DUNG, KHONG hong/lan luot — nhung CO tap am nen
      // dang ke, day moi la nguyen nhan Whisper nghe sai (khong phai loi
      // buffer/encode). Truoc do da RUT LAI co nay vi nghi ngo WebRTC
      // noise suppression lam bien dang tin hieu — bang chung THAT nay
      // dao nguoc nghi ngo do: THIEU khu tap am moi la van de, khong
      // phai CO no. Bat lai — danh doi hop ly voi bang chung hien co.
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.opus, echoCancel: true, noiseSuppress: true),
        path: path,
      );
      _isRecording = true;
      return true;
    } catch (e) {
      _isRecording = false;
      return false;
    }
  }

  /// Stream bien do (dB, cung thang gia tri VoiceActivityDetector.
  /// processAmplitude() mong doi — xem docstring class do) — CHI co gia
  /// tri trong luc dang ghi am (start() da goi thanh cong).
  Stream<double> onAmplitudeDb({Duration interval = const Duration(milliseconds: 200)}) {
    return _recorder.onAmplitudeChanged(interval).map((a) => a.current);
  }

  /// Dung ghi am, tra ve bytes audio da ghi (webm/opus) — null neu loi/
  /// khong co gi de doc. AN TOAN goi nhieu lan (lan 2 tro di tra ve null
  /// ngay vi _isRecording da false).
  Future<List<int>?> stop() async {
    if (!_isRecording) return null;
    _isRecording = false;
    try {
      final pathOrUrl = await _recorder.stop();
      if (pathOrUrl == null) return null;
      return await webReadRecordedBytes(pathOrUrl);
    } catch (e) {
      return null;
    }
  }

  /// Huy ghi am NGAY, KHONG can lay bytes (dung khi user roi man hinh
  /// giua chung, hoac interrupt huy luot ghi dang cho VAD dang xu ly).
  Future<void> cancel() async {
    if (!_isRecording) return;
    _isRecording = false;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      if (_isRecording) await _recorder.stop();
    } catch (_) {}
    await _recorder.dispose();
  }
}
