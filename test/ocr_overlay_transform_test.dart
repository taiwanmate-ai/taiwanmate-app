import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/utils/image_overlay_transform.dart';

void main() {
  group('ImageOverlayTransform', () {
    test('anh vuong hien thi trong khung ngang — co le trai/phai', () {
      final t = ImageOverlayTransform(
        imageSize: const Size(1000, 1000),
        displaySize: const Size(2000, 1000),
      );
      expect(t.scale, 1.0);
      expect(t.offsetX, 500);
      expect(t.offsetY, 0);
    });

    test('anh ngang hien thi trong khung doc — co le tren/duoi', () {
      final t = ImageOverlayTransform(
        imageSize: const Size(2000, 1000),
        displaySize: const Size(1000, 1000),
      );
      expect(t.scale, 0.5);
      expect(t.offsetX, 0);
      expect(t.offsetY, 250);
    });

    test('quy doi Rect anh goc sang hien thi dung', () {
      final t = ImageOverlayTransform(
        imageSize: const Size(1000, 1000),
        displaySize: const Size(2000, 1000),
      );
      final displayRect =
          t.imageToDisplay(const Rect.fromLTWH(100, 100, 200, 50));
      expect(displayRect.left, 600); // 500 + 100*1.0
      expect(displayRect.top, 100);
      expect(displayRect.width, 200);
    });

    test('cham man hinh quy nguoc ve dung toa do anh goc', () {
      final t = ImageOverlayTransform(
        imageSize: const Size(1000, 1000),
        displaySize: const Size(2000, 1000),
      );
      final imagePoint = t.displayPointToImage(const Offset(600, 100));
      expect(imagePoint.dx, closeTo(100, 0.01));
      expect(imagePoint.dy, closeTo(100, 0.01));
    });

    test('imageSize rong (0) khong crash, tra ve scale mac dinh', () {
      final t = ImageOverlayTransform(
          imageSize: Size.zero, displaySize: const Size(500, 500));
      expect(t.scale, 1.0);
    });
  });
}
