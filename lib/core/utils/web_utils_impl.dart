// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;

html.MediaRecorder? _mediaRecorder;
List<html.Blob> _audioChunks = [];
String _currentMimeType = 'audio/webm';

Future<String?> webPickImage() => _pickImageInternal(capture: false);

Future<String?> webCaptureImage() => _pickImageInternal(capture: true);

Future<String?> _pickImageInternal({required bool capture}) {
  final completer = Completer<String?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  if (capture) input.setAttribute('capture', 'environment');

  input.click();
  input.onChange.listen((e) {
    if (input.files == null || input.files!.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = input.files!.first;
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((_) {
      final img = html.ImageElement();
      img.src = reader.result as String;
      img.onLoad.listen((_) {
        double ratio = 1.0;
        if (img.width! > 1600 || img.height! > 1200) {
          ratio = (img.width! > img.height!) ? 1600 / img.width! : 1200 / img.height!;
        }
        final w = (img.width! * ratio).toInt();
        final h = (img.height! * ratio).toInt();
        final canvas = html.CanvasElement(width: w, height: h);
        canvas.context2D.drawImageScaled(img, 0, 0, w, h);
        final compressed = canvas.toDataUrl('image/jpeg', 0.92);
        if (!completer.isCompleted) completer.complete(compressed.split(',')[1]);
      });
      img.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}

Future<void> webStartRecording(
  void Function(String audioBase64) onData,
  void Function(String error) onError,
) async {
  try {
    final stream = await html.window.navigator.mediaDevices!
        .getUserMedia({'audio': true});
    _audioChunks = [];

    String mimeType = 'audio/webm';
    if (html.MediaRecorder.isTypeSupported('audio/webm')) {
      mimeType = 'audio/webm';
    } else if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
      mimeType = 'audio/mp4';
    }
    _currentMimeType = mimeType;

    _mediaRecorder = html.MediaRecorder(stream, {'mimeType': mimeType});

    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _audioChunks.add(blobEvent.data!);
      }
    });

    _mediaRecorder!.addEventListener('stop', (event) {
      final blob = html.Blob(_audioChunks, mimeType);
      final reader = html.FileReader();
      reader.readAsDataUrl(blob);
      reader.onLoadEnd.listen((_) {
        final dataUrl = reader.result as String;
        onData(dataUrl.split(',')[1]);
      });
      reader.onError.listen((_) => onError('Loi doc du lieu am thanh.'));
      for (final track in stream.getTracks()) {
        track.stop();
      }
    });

    _mediaRecorder!.start();
  } catch (e) {
    onError('Trình duyệt không hỗ trợ ghi âm. Vui lòng dùng Chrome hoặc app.');
  }
}
void webStopRecording() {
  if (_mediaRecorder != null && _mediaRecorder!.state != 'inactive') {
    _mediaRecorder!.stop();
  }
}

void webEval(String jsCode) {
  js.context.callMethod('eval', [jsCode]);
}

void webCopyText(String text) {
  js.context.callMethod('eval', [
    "navigator.clipboard.writeText(${_jsString(text)});"
  ]);
}

void webOpenUrl(String url) {
  html.window.open(url, '_blank');
}

String _jsString(String s) {
  final escaped = s
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$escaped'";
}

Stream<String> webChatStream({
  required String url,
  required String token,
  required Map<String, dynamic> body,
}) {
  final controller = StreamController<String>();
  final id = DateTime.now().microsecondsSinceEpoch.toString();

  // JS đẩy chunk vào mảng global, Dart đọc dần
  js.context['_csQueue_$id'] = js.JsArray();
  js.context['_csDone_$id'] = false;
  js.context['_csErr_$id'] = '';
  js.context['_csBody'] = jsonEncode(body);
  js.context['_csToken'] = token;
  js.context['_csUrl'] = url;

  final jsCode = '''
(async function() {
  try {
    const q = window['_csQueue_$id'];
    const resp = await fetch(window._csUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + window._csToken,
        'X-Platform': 'web'
      },
      body: window._csBody
    });
    if (!resp.ok) {
      if (resp.status === 403) { window['_csErr_$id'] = 'QUOTA_EXCEEDED'; }
      else { window['_csErr_$id'] = 'HTTP ' + resp.status; }
      window['_csDone_$id'] = true;
      return;
    }
    const reader = resp.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buffer = '';
    while (true) {
      const r = await reader.read();
      if (r.done) break;
      buffer += decoder.decode(r.value, { stream: true });
      const parts = buffer.split('\\n\\n');
      buffer = parts.pop();
      for (const part of parts) {
        const line = part.trim();
        if (line.startsWith('data:')) {
          // Chỉ bỏ đúng 1 space sau "data:" (chuẩn SSE), GIỮ space nội dung
          let d = line.substring(5);
          if (d.startsWith(' ')) d = d.substring(1);
          if (d.trim() === '[DONE]') { window['_csDone_$id'] = true; return; }
          if (d.length > 0) q.push(d);
        }
      }
    }
    window['_csDone_$id'] = true;
  } catch (e) {
    window['_csErr_$id'] = String(e);
    window['_csDone_$id'] = true;
  }
})();
''';

  webEval(jsCode);

  // Dart đọc mảng global mỗi 60ms
  Timer.periodic(const Duration(milliseconds: 60), (timer) {
    try {
      final queue = js.context['_csQueue_$id'] as js.JsArray;
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        if (item != null) controller.add(item.toString());
      }
      final err = js.context['_csErr_$id'];
      final done = js.context['_csDone_$id'] == true;
      if (err != null && err.toString().isNotEmpty) {
        if (!controller.isClosed) { controller.addError(err.toString()); controller.close(); }
        timer.cancel();
        return;
      }
      if (done) {
        // đọc nốt phần còn lại rồi đóng
        while (queue.isNotEmpty) {
          final item = queue.removeAt(0);
          if (item != null) controller.add(item.toString());
        }
        if (!controller.isClosed) controller.close();
        timer.cancel();
        js.context.deleteProperty('_csQueue_$id');
        js.context.deleteProperty('_csDone_$id');
        js.context.deleteProperty('_csErr_$id');
      }
    } catch (e) {
      if (!controller.isClosed) { controller.addError(e); controller.close(); }
      timer.cancel();
    }
  });

  return controller.stream;
}

// ─── Audio playback có thể chờ ĐÚNG lúc phát xong thật, không đoán thời gian ───
Completer<bool>? _audioCompleter;
html.AudioElement? _currentAudioElement;
String? _currentAudioBlobUrl;

Future<bool> webPlayAudio(String base64Mp3) {
  webStopAudio(); // dừng audio cũ nếu còn đang phát dở

  final completer = Completer<bool>();
  _audioCompleter = completer;

  try {
    final bytes = base64Decode(base64Mp3);
    final blob = html.Blob([bytes], 'audio/mpeg');
    final url = html.Url.createObjectUrlFromBlob(blob);
    _currentAudioBlobUrl = url;

    final audio = html.AudioElement(url);
    _currentAudioElement = audio;

    audio.onEnded.listen((_) {
      if (!completer.isCompleted) completer.complete(true);
      _cleanupAudioUrl(url);
    });
    audio.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(false);
      _cleanupAudioUrl(url);
    });

    audio.play().catchError((e) {
      if (!completer.isCompleted) completer.complete(false);
      _cleanupAudioUrl(url);
    });
  } catch (e) {
    if (!completer.isCompleted) completer.complete(false);
  }

  return completer.future;
}

void _cleanupAudioUrl(String url) {
  try { html.Url.revokeObjectUrl(url); } catch (_) {}
  if (_currentAudioBlobUrl == url) _currentAudioBlobUrl = null;
}

void webStopAudio() {
  final audio = _currentAudioElement;
  if (audio != null) {
    try { audio.pause(); } catch (_) {}
    _currentAudioElement = null;
  }
  final completer = _audioCompleter;
  if (completer != null && !completer.isCompleted) completer.complete(false);
  _audioCompleter = null;
  if (_currentAudioBlobUrl != null) {
    try { html.Url.revokeObjectUrl(_currentAudioBlobUrl!); } catch (_) {}
    _currentAudioBlobUrl = null;
  }
}
String getRecordingMimeType() =>
    _currentMimeType.contains('mp4') ? 'mp4' : 'webm';