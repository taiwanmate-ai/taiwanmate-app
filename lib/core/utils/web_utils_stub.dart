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

Future<void> webStartRecording(
  void Function(String audioBase64) onData,
  void Function(String error) onError,
) async {
  try {
    if (!await _recorder.hasPermission()) {
      onError('Vui lòng cấp quyền microphone để ghi âm.');
      return;
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
  } catch (e) {
    onError('Lỗi microphone: $e');
  }
}

void Function(String)? _onRecordData;
void Function(String)? _onRecordError;

void webStopRecording() async {
  try {
    final path = await _recorder.stop();
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
    _onRecordError?.call('Lỗi đọc dữ liệu âm thanh: $e');
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