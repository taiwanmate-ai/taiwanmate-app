import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/constants/api_constants.dart';
import 'package:chinesemate/core/utils/web_utils.dart';

/// Bai hoc moi (lesson v2). Cong tac nam o SERVER (LESSON_V2_ALLOWLIST) — client doc `lesson_v2_enabled` tu GET /auth/me; thieu/loi -> dung bai cu.
class LessonV2Disabled implements Exception {
  @override
  String toString() => 'LessonV2Disabled';
}

/// Bai tinh huong chua duoc duyet / app can cap nhat (409 SITUATION_NOT_READY | SITUATION_CAPS_REQUIRED): hien thong diep, KHONG roi ve bai cu.
class SituationUnavailable implements Exception {
  final String message;
  SituationUnavailable(this.message);
  @override
  String toString() => 'SituationUnavailable($message)';
}

abstract class LessonV2Api {
  Future<Map<String, dynamic>> fetchSession(String unitId);
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body);
  Future<void> reportQuestion(String questionId, {String? reason});
  Future<Map<String, dynamic>> submitGame(int matched, int misses);
  Future<void> playAudio(Map<String, dynamic>? audio);
}

/// API rieng cua bai tinh huong (Q3, sau co SITUATION_V1): bang pinyin, kiem tra bo qua, cham dich. TACH khoi [LessonV2Api] de cac lop gia cu (implements LessonV2Api) khong vo.
abstract class SituationApi {
  Future<Map<String, dynamic>> fetchPinyinChart();
  Future<Map<String, dynamic>> fetchPronTest();
  Future<Map<String, dynamic>> submitPronTest(int correct, int total);
  Future<Map<String, dynamic>> gradeTranslation(String exerciseId, int segmentIdx, String text);
  Future<void> reportGrade(String attemptId);
}

/// Loi nghiep vu khi cham dich (429 het luot / 503 AI tam ngung / 400 noi dung) — hien thong diep than thien cho nguoi hoc.
class GradeError implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? quota;
  GradeError(this.code, this.message, {this.quota});
  @override
  String toString() => 'GradeError($code)';
}

class HttpLessonV2Api implements LessonV2Api, SituationApi {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Map<String, String> _b64Cache = {};
  HttpLessonV2Api({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 60))),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Options> get _auth async => Options(headers: {'Authorization': 'Bearer ${await _storage.read(key: 'access_token')}'});

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final d = e.response?.data;
      if (e.response?.statusCode == 403 && d is Map && d['detail'] is Map && d['detail']['code'] == 'LESSON_V2_DISABLED') {
        throw LessonV2Disabled();
      }
      if (e.response?.statusCode == 409 && d is Map && d['detail'] is Map && '${d['detail']['code']}'.startsWith('SITUATION_')) {
        throw SituationUnavailable('${d['detail']['message'] ?? 'Bài này chưa sẵn sàng'}');
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) => _guard(() async {
        // caps: cac dang cau moi app nay biet hien thi (server chi gui dang moi khi app bao)
        final r = await _dio.get('${ApiConstants.baseUrl}/lesson/$unitId/session', queryParameters: {'caps': 'arrange_sentence,situation_v1'}, options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body) => _guard(() async {
        final r = await _dio.post('${ApiConstants.baseUrl}/lesson/$unitId/answers', data: body, options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<void> reportQuestion(String questionId, {String? reason}) => _guard(() async {
        await _dio.post('${ApiConstants.baseUrl}/lesson/question/$questionId/report', data: {'reason': reason}, options: await _auth);
      });

  @override
  Future<Map<String, dynamic>> submitGame(int matched, int misses) => _guard(() async {
        final r = await _dio.post('${ApiConstants.baseUrl}/lesson/game/match60/score', data: {'matched': matched, 'misses': misses}, options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<Map<String, dynamic>> fetchPinyinChart() => _guard(() async {
        final r = await _dio.get('${ApiConstants.baseUrl}/lesson/pinyin-chart', options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<Map<String, dynamic>> fetchPronTest() => _guard(() async {
        final r = await _dio.get('${ApiConstants.baseUrl}/lesson/pron-test', options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<Map<String, dynamic>> submitPronTest(int correct, int total) => _guard(() async {
        final r = await _dio.post('${ApiConstants.baseUrl}/lesson/pron-test/result', data: {'correct': correct, 'total': total}, options: await _auth);
        return Map<String, dynamic>.from(r.data as Map);
      });

  @override
  Future<Map<String, dynamic>> gradeTranslation(String exerciseId, int segmentIdx, String text) async {
    try {
      final r = await _dio.post('${ApiConstants.baseUrl}/translation/grade',
          data: {'exercise_id': exerciseId, 'segment_idx': segmentIdx, 'text': text}, options: await _auth);
      return Map<String, dynamic>.from(r.data as Map);
    } on DioException catch (e) {
      final d = e.response?.data;
      final detail = d is Map ? d['detail'] : null;
      if (detail is Map) {
        throw GradeError('${detail['code']}', '${detail['message'] ?? 'Không chấm được, thử lại sau nhé'}', quota: detail['quota'] is Map ? Map<String, dynamic>.from(detail['quota'] as Map) : null);
      }
      throw GradeError('ERROR', e.response?.statusCode == 404 ? 'Bài dịch này chưa sẵn sàng' : 'Chấm bài tạm thời không được, thử lại sau nhé');
    }
  }

  @override
  Future<void> reportGrade(String attemptId) async {
    try {
      await _dio.post('${ApiConstants.baseUrl}/translation/attempt/$attemptId/report', options: await _auth);
    } catch (_) {}
  }

  /// Audio: file tinh cua backend neu co `url` (A1), con khong thi /translate/tts nhu bai cu. Loi am thanh KHONG lam hong bai hoc.
  @override
  Future<void> playAudio(Map<String, dynamic>? audio) async {
    if (audio == null) return;
    final text = audio['text'] as String?;
    if (text == null || text.isEmpty) return;
    try {
      final voice = audio['voice'] as String?;
      final cacheKey = (audio['url'] as String?) ?? '${audio['lang']}|${voice ?? ''}|$text';
      var b64 = _b64Cache[cacheKey];
      if (b64 == null) {
        final bytesDio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 60), responseType: ResponseType.bytes));
        if (audio['url'] is String) {
          final origin = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
          final r = await bytesDio.get('$origin${audio['url']}');
          b64 = base64Encode(r.data as List<int>);
        } else {
          final r = await bytesDio.post('${ApiConstants.baseUrl}/translate/tts',
              data: {'text': text, 'lang': audio['lang'] == 'en' ? 'en-US' : 'zh-TW', 'slow': true, if (voice != null && voice != 'A') 'voice': voice}, options: await _auth);
          b64 = base64Encode(r.data as List<int>);
        }
        _b64Cache[cacheKey] = b64;
      }
      await webPlayAudio(b64);
    } catch (_) {}
  }
}

final lessonV2ApiProvider = Provider<LessonV2Api>((ref) => HttpLessonV2Api());

/// Server quyet dinh tai khoan nay co bai moi khong (`lesson_v2_enabled` o GET /auth/me). Chua tai xong / loi mang / thieu truong -> false (bai cu).
typedef LessonV2Fetcher = Future<bool> Function();

Future<bool> fetchLessonV2Enabled() async {
  try {
    final token = await const FlutterSecureStorage().read(key: 'access_token');
    if (token == null || token.isEmpty) return false;
    final r = await Dio().get('${ApiConstants.baseUrl}${ApiConstants.me}', options: Options(headers: {'Authorization': 'Bearer $token'}));
    final d = r.data;
    return d is Map && d['lesson_v2_enabled'] == true;
  } catch (_) {
    return false;
  }
}

final lessonV2FetcherProvider = Provider<LessonV2Fetcher>((ref) => fetchLessonV2Enabled);
final lessonV2EnabledProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(lessonV2FetcherProvider)());
