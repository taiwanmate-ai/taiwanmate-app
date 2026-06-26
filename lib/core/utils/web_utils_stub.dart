Future<String?> webPickImage() async => null;

Future<String?> webCaptureImage() async => null;

Future<void> webStartRecording(
  void Function(String audioBase64) onData,
  void Function(String error) onError,
) async {
  onError('Ghi am chi ho tro tren trinh duyet web.');
}

void webStopRecording() {}

void webEval(String js) {}

void webCopyText(String text) {}

void webOpenUrl(String url) {}
