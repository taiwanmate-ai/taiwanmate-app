import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/constants/api_constants.dart';

/// Tam an Voice (2026-10-14): server (VOICE_FEATURE_ENABLED / VOICE_FEATURE_ALLOWLIST) quyet dinh tai khoan nay co thay Voice khong, qua truong
/// `voice_feature_enabled` cua GET /auth/me. Moi diem vao Voice + duong thanh toan Voice trong app doc co nay; chua tai xong / loi mang / thieu truong -> AN.
typedef VoiceFeatureFetcher = Future<bool> Function();

Future<bool> fetchVoiceFeatureEnabled() async {
  try {
    final token = await const FlutterSecureStorage().read(key: 'access_token');
    if (token == null || token.isEmpty) return false;
    final response = await Dio().get(
      '${ApiConstants.baseUrl}${ApiConstants.me}',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data;
    return data is Map && data['voice_feature_enabled'] == true;
  } catch (_) {
    return false;
  }
}

/// Thay the trong test (override) de khong goi mang.
final voiceFeatureFetcherProvider = Provider<VoiceFeatureFetcher>((ref) => fetchVoiceFeatureEnabled);

final voiceFeatureEnabledProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(voiceFeatureFetcherProvider)());
