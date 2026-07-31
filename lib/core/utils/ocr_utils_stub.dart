import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR on-device (Phase 2). Dung cho Android (da xac nhan minSdk 24 du dieu
/// kien). iOS chua tung build/test that (thieu Mac/CocoaPods) — code van
/// bien dich duoc cho iOS nhung CHUA duoc xac nhan chay dung tren thiet bi
/// that, theo dung ghi nhan rui ro da neu truoc do.
Future<String?> recognizeTextOnDevice(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(inputImage);
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } catch (e) {
    return null;
  } finally {
    await recognizer.close();
  }
}

bool get isOnDeviceOcrSupported => Platform.isAndroid || Platform.isIOS;

/// Phase 3: tra ve danh sach vung chu (TextLine) kem bounding box, phuc vu
/// overlay cham chon. Ham RIENG BIET voi recognizeTextOnDevice (Phase 2) —
/// khong doi/xoa ham cu, de rollback doc lap.
Future<List<OcrRegionRaw>?> recognizeTextRegionsOnDevice(
    String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  try {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(inputImage);
    final regions = <OcrRegionRaw>[];
    for (int b = 0; b < result.blocks.length; b++) {
      final block = result.blocks[b];
      for (int l = 0; l < block.lines.length; l++) {
        final line = block.lines[l];
        regions.add(OcrRegionRaw(
          text: line.text,
          left: line.boundingBox.left.toDouble(),
          top: line.boundingBox.top.toDouble(),
          width: line.boundingBox.width.toDouble(),
          height: line.boundingBox.height.toDouble(),
          blockIndex: b,
          lineIndex: l,
        ));
      }
    }
    return regions.isEmpty ? null : regions;
  } catch (e) {
    return null;
  } finally {
    await recognizer.close();
  }
}

/// Du lieu tho tu ML Kit — khong dung dun.dart:ui de tach biet khoi Flutter UI
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
