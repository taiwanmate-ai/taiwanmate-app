import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/models/ocr_region.dart';
import 'package:chinesemate/features/translate/services/ocr_region_service.dart';

void main() {
  const service = OcrRegionService();

  test('sap xep dung thu tu tren-truoc, trai-truoc', () {
    final regions = [
      const OcrRegion(
          id: 'c',
          text: 'C',
          boundingBox: Rect.fromLTWH(0, 100, 50, 20),
          blockIndex: 0,
          lineIndex: 2),
      const OcrRegion(
          id: 'a',
          text: 'A',
          boundingBox: Rect.fromLTWH(0, 0, 50, 20),
          blockIndex: 0,
          lineIndex: 0),
      const OcrRegion(
          id: 'b',
          text: 'B',
          boundingBox: Rect.fromLTWH(60, 0, 50, 20),
          blockIndex: 0,
          lineIndex: 1),
    ];
    final sorted = service.sortByReadingOrder(regions);
    expect(sorted.map((r) => r.id).toList(), ['a', 'b', 'c']);
  });

  test('ghep dung text theo thu tu doc, khong theo thu tu bam', () {
    final regions = [
      const OcrRegion(
          id: 'a',
          text: 'Xin',
          boundingBox: Rect.fromLTWH(0, 0, 50, 20),
          blockIndex: 0,
          lineIndex: 0),
      const OcrRegion(
          id: 'b',
          text: 'chào',
          boundingBox: Rect.fromLTWH(60, 0, 50, 20),
          blockIndex: 0,
          lineIndex: 0),
    ];
    final sorted = service.sortByReadingOrder(regions);
    // gia su user bam B truoc, A sau — ket qua van phai la "Xin chào"
    final combined = service.combineSelectedText(sorted, {'b', 'a'});
    expect(combined, 'Xin chào');
  });
}
