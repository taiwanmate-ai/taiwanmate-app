import 'dart:ui';

/// Ham thuan quy doi toa do — KHONG phu thuoc BuildContext/Widget,
/// test duoc bang flutter test thuong, khong can thiet bi that.
class ImageOverlayTransform {
  final Size imageSize;
  final Size displaySize;
  late final double scale;
  late final double offsetX;
  late final double offsetY;

  ImageOverlayTransform({required this.imageSize, required this.displaySize}) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      scale = 1.0;
      offsetX = 0;
      offsetY = 0;
      return;
    }
    final scaleX = displaySize.width / imageSize.width;
    final scaleY = displaySize.height / imageSize.height;
    scale = scaleX < scaleY ? scaleX : scaleY; // BoxFit.contain
    final scaledW = imageSize.width * scale;
    final scaledH = imageSize.height * scale;
    offsetX = (displaySize.width - scaledW) / 2;
    offsetY = (displaySize.height - scaledH) / 2;
  }

  /// Anh goc -> vi tri hien thi tren man hinh
  Rect imageToDisplay(Rect r) {
    return Rect.fromLTWH(
      offsetX + r.left * scale,
      offsetY + r.top * scale,
      r.width * scale,
      r.height * scale,
    );
  }

  /// Cham man hinh -> toa do tren anh goc (dung de hit-test)
  Offset displayPointToImage(Offset p) {
    return Offset((p.dx - offsetX) / scale, (p.dy - offsetY) / scale);
  }
}
