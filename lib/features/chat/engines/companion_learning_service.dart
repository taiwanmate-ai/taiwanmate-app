import 'package:dio/dio.dart';

/// CompanionLearningService — tach network logic cua _loadNextAction()
/// khoi ChatScreen. Khong dung BuildContext, khong goi setState, khong doc
/// FlutterSecureStorage truc tiep (token duoc truyen vao tu ben ngoai).
/// Khac voi CompanionLearningEngine (ham thuan, khong network) — service
/// nay chi chiu trach nhiem goi API mastery/next-action.
class CompanionLearningService {
  const CompanionLearningService();

  /// GET /api/v1/mastery/next-action. Tra ve Map neu co goi y
  /// (has_suggestion == true), tra ve null neu khong co goi y hoac
  /// xay ra loi.
  Future<Map<String, dynamic>?> loadNextAction(String? token) async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/mastery/next-action',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.data['has_suggestion'] == true) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}