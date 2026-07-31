import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:chinesemate/features/translate/utils/image_orientation_fix.dart';

Uint8List _makeTestJpeg(int orientation) {
  final image =
      img.Image(width: 100, height: 50); // hinh chu nhat de phat hien xoay
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  image.exif.imageIfd.orientation = orientation;
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('normalizeOrientationForOverlay', () {
    test('orientation normal (1) — khong xoay, giu nguyen kich thuoc', () {
      final result = normalizeOrientationForOverlay(_makeTestJpeg(1));
      expect(result.size.width, 100);
      expect(result.size.height, 50);
    });

    test('orientation 6 (xoay 90°) — width/height hoan doi', () {
      final result = normalizeOrientationForOverlay(_makeTestJpeg(6));
      expect(result.size.width, 50);
      expect(result.size.height, 100);
    });

    test('orientation 3 (xoay 180°) — giu nguyen kich thuoc', () {
      final result = normalizeOrientationForOverlay(_makeTestJpeg(3));
      expect(result.size.width, 100);
      expect(result.size.height, 50);
    });

    test('orientation 8 (xoay 270°) — width/height hoan doi', () {
      final result = normalizeOrientationForOverlay(_makeTestJpeg(8));
      expect(result.size.width, 50);
      expect(result.size.height, 100);
    });

    test(
        'sau khi chuan hoa, khong con thong tin xoay du thua (null hoac 1 deu hop le)',
        () {
      final result = normalizeOrientationForOverlay(_makeTestJpeg(6));
      final redecoded = img.decodeImage(result.bytes);
      // ca 2 gia tri deu mang cung y nghia: "khong can xoay them" —
      // null (khong co the) va 1 (binh thuong) tuong duong nhau ve mat
      // hanh vi doc file, khong phai loi.
      expect(redecoded?.exif.imageIfd.orientation, anyOf(1, isNull));
    });
  });
}
