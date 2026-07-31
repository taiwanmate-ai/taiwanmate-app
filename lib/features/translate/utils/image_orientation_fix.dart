import 'dart:typed_data';
import 'package:flutter/material.dart' show Size;
import 'package:image/image.dart' as img;

class NormalizedImage {
  final Uint8List bytes;
  final Size size;
  const NormalizedImage({required this.bytes, required this.size});
}

/// Phase 3 RIENG: chuan hoa xoay anh theo EXIF ("bake") DUNG MOT LAN,
/// dam bao 1 bo pixel THONG NHAT dung chung cho ca hien thi overlay lan
/// input gui ML Kit — tranh lech toa do do 2 tang xu ly khac huong.
/// KHONG dung chung/thay the resizeBase64Image (Phase 1-2), doc lap hoan toan.
NormalizedImage normalizeOrientationForOverlay(Uint8List originalBytes) {
  final decoded = img.decodeImage(originalBytes);
  if (decoded == null) {
    throw ArgumentError('Không decode được ảnh — dữ liệu không hợp lệ');
  }
  final baked = img.bakeOrientation(decoded);
  // bakeOrientation() da tu dat orientation=null trong imageIfd (xac nhan
  // qua source code that cua package, tu ban 3.3.0+). Dat lai ro rang ve
  // "normal" (1) bang API CO THAT (.exif.imageIfd.orientation), khong dung
  // ham .clear() gia dinh sai truoc do.
  baked.exif.imageIfd.orientation = 1;
  final encoded = Uint8List.fromList(img.encodeJpg(baked, quality: 90));
  return NormalizedImage(
    bytes: encoded,
    size: Size(baked.width.toDouble(), baked.height.toDouble()),
  );
}
