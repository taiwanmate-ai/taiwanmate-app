import '../models/ocr_region.dart';

/// Ham thuan: sap xep va ghep text — khong Flutter, test duoc de dang.
class OcrRegionService {
  const OcrRegionService();

  /// Sap theo thu tu doc: tren truoc, cung hang thi trai truoc.
  /// Dung sai 10px de coi 2 vung la "cung hang" (chu khong bang tuyet doi).
  static const double _sameRowThresholdPx = 10.0;

  List<OcrRegion> sortByReadingOrder(List<OcrRegion> regions) {
    final sorted = List<OcrRegion>.from(regions);
    sorted.sort((a, b) {
      final topDiff = a.boundingBox.top - b.boundingBox.top;
      if (topDiff.abs() > _sameRowThresholdPx) {
        return topDiff > 0 ? 1 : -1;
      }
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });
    return sorted;
  }

  /// Ghep text cac vung DA CHON theo dung thu tu doc (khong theo thu tu bam)
  String combineSelectedText(
      List<OcrRegion> allRegionsSorted, Set<String> selectedIds) {
    return allRegionsSorted
        .where((r) => selectedIds.contains(r.id))
        .map((r) => r.text)
        .join(' ');
  }
}
