import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> webPickImage() async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  } catch (e) {
    return null;
  }
}

Future<String?> webCaptureImage() async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  } catch (e) {
    return null;
  }
}

final AudioRecorder _recorder = AudioRecorder();
String? _recordingPath;
void Function(String)? _onRecordData;
void Function(String)? _onRecordError;

// ─── State guard dùng chung cho cả ghi âm thường và tự-dừng-khi-im-lặng ───
bool _isRecording = false;
bool _isStopping = false;
bool _hasDetectedSpeech = false;
DateTime? _silenceStart;
DateTime? _recordingStartedAt;
StreamSubscription<Amplitude>? _amplitudeSub;
Timer? _maxDurationTimer;

const Duration _kSilenceDuration = Duration(milliseconds: 2500);
const Duration _kInitialGracePeriod = Duration(milliseconds: 1800);
const Duration _kMaxRecordingDuration = Duration(seconds: 45);

/// Khoi tao va bat dau ghi am — dung chung cho ca webStartRecording va
/// webStartRecordingAutoStop, tranh 2 implementation ghi am khac nhau.
/// Tra ve true neu bat dau ghi thanh cong.
Future<bool> _startRecordingInternal(
  void Function(String audioBase64) onData,
  void Function(String error) onError,
) async {
  try {
    if (!await _recorder.hasPermission()) {
      onError('Vui lòng cấp quyền microphone để ghi âm.');
      return false;
    }
    final dir = await getTemporaryDirectory();
    // Dùng opus/webm để khớp định dạng backend đang xử lý cứng (.webm)
    _recordingPath = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.webm';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path: _recordingPath!,
    );
    _onRecordData = onData;
    _onRecordError = onError;
    _isRecording = true;
    _isStopping = false;
    _hasDetectedSpeech = false;
    _silenceStart = null;
    _recordingStartedAt = DateTime.now();
    return true;
  } catch (e) {
    onError('Lỗi microphone: $e');
    return false;
  }
}

Future<void> webStartRecording(
  void Function(String audioBase64) onData,
  void Function(String error) onError,
) async {
  await _startRecordingInternal(onData, onError);
}

/// Ghi am voi tu-dong-dung-khi-im-lang. TAI SU DUNG dung logic khoi tao
/// cua _startRecordingInternal — khong tao them 1 luong ghi am khac.
/// Chi khac o cho: theo doi them onAmplitudeChanged() de tu goi webStopRecording().
Future<void> webStartRecordingAutoStop(
  void Function(String audioBase64) onData,
  void Function(String error) onError, {
  double silenceThresholdDb = -35.0,
  Duration silenceDuration = _kSilenceDuration,
}) async {
  final started = await _startRecordingInternal(onData, onError);
  if (!started) return;

 await _amplitudeSub?.cancel();
  _amplitudeSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 200)).listen(
    (amp) {
      if (!_isRecording || _isStopping) return;

      final now = DateTime.now();
      final elapsedSinceStart = now.difference(_recordingStartedAt!);

    // Chua het initialGracePeriod -> chua xet gi ca, tranh dung ngay khi vua mo mic
    if (elapsedSinceStart < _kInitialGracePeriod) return;

    if (amp.current > silenceThresholdDb) {
      // Co tieng noi -> danh dau da phat hien speech, reset dem im lang
      _hasDetectedSpeech = true;
      _silenceStart = null;
    } else {
        // Im lang -> CHI bat dau dem neu da tung phat hien speech truoc do
        if (!_hasDetectedSpeech) return;
        _silenceStart ??= now;
        if (now.difference(_silenceStart!) >= silenceDuration) {
          webStopRecording();
        }
      }
    },
    onError: (_) {
      // Loi doc amplitude khong duoc lam vo ghi am chinh — im lang bo qua
    },
  );
  // Luoi an toan tuyet doi: du khong phat hien duoc im lang, van tu dung sau maxRecordingDuration
  _maxDurationTimer?.cancel();
  _maxDurationTimer = Timer(_kMaxRecordingDuration, () {
    if (_isRecording && !_isStopping) {
      webStopRecording();
    }
  });
}

Future<void> _cleanupAutoStopResources() async {
  await _amplitudeSub?.cancel();
  _amplitudeSub = null;
  _maxDurationTimer?.cancel();
  _maxDurationTimer = null;
  _hasDetectedSpeech = false;
  _silenceStart = null;
  _recordingStartedAt = null;
}

void webStopRecording() async {
  // Chan goi stop() 2 lan du bam tay, timer im lang, hay loi cung xay ra
  if (_isStopping || !_isRecording) return;
  _isStopping = true;

  await _cleanupAutoStopResources();

  try {
    final path = await _recorder.stop();
    _isRecording = false;
    if (path == null) {
      _onRecordError?.call('Không ghi được âm thanh.');
      return;
    }
    final bytes = await File(path).readAsBytes();
    final base64Str = base64Encode(bytes);
    _onRecordData?.call(base64Str);
    // Dọn file tạm
    File(path).delete().catchError((_) => File(path));
  } catch (e) {
    _isRecording = false;
    _onRecordError?.call('Lỗi đọc dữ liệu âm thanh: $e');
  } finally {
    _isStopping = false;
  }
}
/// Lop 6 (2026-08-15) — doc bytes tu ket qua AudioRecorder.stop() cua
/// package `record` DUNG TRUC TIEP boi VoiceMicRecorder (Voice pipeline
/// moi, TACH RIENG khoi _recorder o tren — khong dung chung 1 instance
/// vi co the co 2 man hinh ghi am khac nhau). Tren native, stop() tra ve
/// 1 duong dan file THAT — doc bang dart:io File nhu da lam o
/// webStopRecording() phia tren.
Future<List<int>?> webReadRecordedBytes(String pathOrUrl) async {
  try {
    final file = File(pathOrUrl);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    file.delete().catchError((_) => file);
    return bytes;
  } catch (e) {
    return null;
  }
}

void webEval(String js) {}

void webCopyText(String text) {
  Clipboard.setData(ClipboardData(text: text));
}

void webOpenUrl(String url) {
  // Android không cần mở tab mới như web — dùng share_plus để share qua app khác
  // (Facebook, Twitter, LINE đều có thể nhận link/text qua share sheet native)
}

/// Audit "nut mua Voice khong bam duoc tren iOS Safari" (2026-09-02) — CHI
/// dung tren web (startPolarCheckout() luon gate qua kIsWeb truoc khi goi),
/// 3 ham nay o day CHI de bien dich duoc tren native, KHONG BAO GIO thuc su
/// duoc goi tren Android/iOS app that.
dynamic webOpenBlankWindow() => null;
void webNavigateWindow(dynamic windowHandle, String url) {}
void webCloseWindow(dynamic windowHandle) {}

// ─── Chat streaming thật cho Android (dùng http, thay cho fetch/js chỉ có trên web) ───
Stream<String> webChatStream({
  required String url,
  required String token,
  required Map<String, dynamic> body,
}) {
  final controller = StreamController<String>();

  () async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode(body);

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 403) {
        controller.addError('QUOTA_EXCEEDED');
        await controller.close();
        client.close();
        return;
      }
      if (streamedResponse.statusCode != 200) {
        controller.addError('HTTP ${streamedResponse.statusCode}');
        await controller.close();
        client.close();
        return;
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();
        for (final part in parts) {
          final line = part.trim();
          if (line.startsWith('data:')) {
            var d = line.substring(5);
            if (d.startsWith(' ')) d = d.substring(1);
            if (d.trim() == '[DONE]') {
              await controller.close();
              client.close();
              return;
            }
            if (d.isNotEmpty) controller.add(d);
          }
        }
      }
      await controller.close();
    } catch (e) {
      controller.addError(e.toString());
      await controller.close();
    } finally {
      client.close();
    }
  }();

  return controller.stream;
}

// ─── Audio playback thật cho Android (dùng audioplayers, thay cho dart:html Audio) ───
AudioPlayer? _mobileAudioPlayer;

Future<bool> webPlayAudio(String base64Mp3) async {
  webStopAudio();
  try {
    final bytes = base64Decode(base64Mp3);
    final player = AudioPlayer();
    _mobileAudioPlayer = player;

    final completer = Completer<bool>();
    late final StreamSubscription sub;
    sub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
      sub.cancel();
    });

    await player.play(BytesSource(bytes));
    return completer.future;
  } catch (e) {
    return false;
  }
}

void webStopAudio() {
  final player = _mobileAudioPlayer;
  _mobileAudioPlayer = null;
  if (player != null) {
    player.stop().then((_) => player.dispose());
  }
}
String getRecordingMimeType() => 'webm';