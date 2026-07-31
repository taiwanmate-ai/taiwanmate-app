import 'package:dio/dio.dart';

/// CompanionMemoryService — tach network logic cua _loadMemory()/_saveMemory()
/// khoi ChatScreen. Khong dung BuildContext, khong goi setState, khong doc
/// FlutterSecureStorage truc tiep (token duoc truyen vao tu ben ngoai).
/// Giu nguyen endpoint, header, payload va cach nuot loi hien tai.
class CompanionMemoryService {
  const CompanionMemoryService();

  /// GET /api/v1/chat/memory. Tra ve Map neu backend co memory (ke ca
  /// rong {}), tra ve null neu memory:null hoac co loi xay ra.
  Future<Map<String, dynamic>?> loadMemory(String? token) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/memory',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['memory'] != null) {
        return Map<String, dynamic>.from(response.data['memory']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/v1/chat/memory. Fire-and-forget — nuot loi im lang giong
  /// code goc, khong throw, khong retry.
  Future<void> saveMemory({
    required String? token,
    required List<Map<String, dynamic>> messages,
    required Map<String, dynamic> existingMemory,
  }) async {
    try {
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/memory',
        data: {
          'messages': messages,
          'existing_memory': existingMemory,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (e) {}
  }
}