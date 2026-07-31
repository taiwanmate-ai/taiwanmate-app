import 'dart:ui';

/// 1 vung chu co the cham chon (tuong ung 1 TextLine cua ML Kit).
/// boundingBox tinh theo he toa do ANH GOC (khong phai widget hien thi).
class OcrRegion {
  final String id;
  final String text;
  final Rect boundingBox;
  final int blockIndex;
  final int lineIndex;

  const OcrRegion({
    required this.id,
    required this.text,
    required this.boundingBox,
    required this.blockIndex,
    required this.lineIndex,
  });
}
