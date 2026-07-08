import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Resize ảnh về tối đa 1600px cạnh dài trước khi upload — giảm mạnh
/// dung lượng với ảnh tải từ internet (thường rất lớn), giữ đủ chất lượng
/// để OCR đọc chữ chính xác.
String resizeBase64Image(String base64Str, {int maxDimension = 1600}) {
  try {
    final bytes = base64Decode(base64Str);
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return base64Str; // decode lỗi → giữ nguyên, không chặn luồng

    if (decoded.width <= maxDimension && decoded.height <= maxDimension) {
      return base64Str; // ảnh đã đủ nhỏ, không cần resize
    }

    final resized = decoded.width > decoded.height
        ? img.copyResize(decoded, width: maxDimension)
        : img.copyResize(decoded, height: maxDimension);

    final Uint8List jpgBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    return base64Encode(jpgBytes);
  } catch (_) {
    return base64Str; // an toàn — lỗi resize không được làm hỏng cả luồng dịch
  }
}