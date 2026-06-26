// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:js' as js;

html.MediaRecorder? _mediaRecorder;
List<html.Blob> _audioChunks = [];

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
    _mediaRecorder = html.MediaRecorder(stream);

    _mediaRecorder!.addEventListener('dataavailable', (event) {
      final blobEvent = event as html.BlobEvent;
      if (blobEvent.data != null && blobEvent.data!.size > 0) {
        _audioChunks.add(blobEvent.data!);
      }
    });

    _mediaRecorder!.addEventListener('stop', (event) {
      final blob = html.Blob(_audioChunks, 'audio/webm');
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
    onError('Loi microphone: $e');
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
