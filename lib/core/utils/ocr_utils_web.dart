/// Web KHONG ho tro ML Kit on-device — luon tra null de code goi tu dong
/// fallback ve /translate/image (GPT Vision) nhu truoc, dung theo yeu cau
/// "Web giu nguyen luong hien tai".
Future<String?> recognizeTextOnDevice(String imagePath) async => null;

bool get isOnDeviceOcrSupported => false;

Future<List<OcrRegionRaw>?> recognizeTextRegionsOnDevice(
        String imagePath) async =>
    null;

class OcrRegionRaw {
  final String text;
  final double left, top, width, height;
  final int blockIndex, lineIndex;
  const OcrRegionRaw({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.blockIndex,
    required this.lineIndex,
  });
}
