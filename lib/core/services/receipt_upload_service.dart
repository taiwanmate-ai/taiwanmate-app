import 'dart:convert';
import 'package:http/http.dart' as http;

class ReceiptUploadService {
  static const String _cloudName = 'cybgrtzr';
  static const String _uploadPreset = 'taiwanmate_receipts';

  /// Upload ảnh biên lai lên Cloudinary, trả về secure_url.
  /// Trả về null nếu upload thất bại (network lỗi, timeout...).
  static Future<String?> uploadReceipt(String imageBase64) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['file'] = 'data:image/jpeg;base64,$imageBase64';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Upload timeout'),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}