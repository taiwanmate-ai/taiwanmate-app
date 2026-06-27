 
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
 
const _base = 'https://taiwanmate-backend-production.up.railway.app/api/v1';
 
class AppCache {
  AppCache._();
  static final AppCache instance = AppCache._();
 
  // ── Data store ──────────────────────────────────────────
  Map<String, dynamic>? userInfo;         // /auth/me
  List<Map<String, dynamic>>? vocabulary; // /vocabulary
  List<Map<String, dynamic>>? news;       // /news/feed
  List<Map<String, dynamic>>? dailyVocab; // /vocabulary/daily
  String? dailyVocabLang;                 // lang dùng khi cache daily
 
  // ── Loading flags (tránh gọi double khi 2 widget cùng await) ──
  bool _loadingUser = false;
  bool _loadingVocab = false;
  bool _loadingNews = false;
  bool _loadingDaily = false;
 
  final _storage = const FlutterSecureStorage();
 
  Dio _dio() => Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));
 
  Future<String?> _token() => _storage.read(key: 'access_token');
 
  // ── User info ────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUser({bool forceRefresh = false}) async {
    if (userInfo != null && !forceRefresh) return userInfo;
    if (_loadingUser) {
      // Chờ 100ms rồi thử lại — tránh gọi double
      await Future.delayed(const Duration(milliseconds: 100));
      return userInfo;
    }
    _loadingUser = true;
    try {
      final token = await _token();
       if (token == null) return null;
      final res = await _dio().get('/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      userInfo = Map<String, dynamic>.from(res.data);
      return userInfo;
    } catch (_) {
      return null;
    } finally {
      _loadingUser = false;
    }
  }
 
  // ── Vocabulary (toàn bộ) ─────────────────────────────────
  Future<List<Map<String, dynamic>>?> getVocabulary({
    String lang = 'zh',
    bool forceRefresh = false,
  }) async {
    if (vocabulary != null && !forceRefresh) return vocabulary;
    if (_loadingVocab) {
      await Future.delayed(const Duration(milliseconds: 100));
      return vocabulary;
    }
    _loadingVocab = true;
    try {
      final token = await _token();
      if (token == null) return []; 
      final res = await _dio().get('/vocabulary?lang=$lang',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      vocabulary = List<Map<String, dynamic>>.from(res.data);
      return vocabulary;
    } catch (_) {
      return null;
    } finally {
      _loadingVocab = false;
    }
  }
 
  // ── Daily vocabulary ─────────────────────────────────────
  Future<List<Map<String, dynamic>>?> getDailyVocab({
    String lang = 'zh',
    bool forceRefresh = false,
  }) async {
    // Nếu đổi lang thì phải refresh
    if (dailyVocab != null && dailyVocabLang == lang && !forceRefresh) return dailyVocab;
    if (_loadingDaily) {
      await Future.delayed(const Duration(milliseconds: 100));
      return dailyVocab;
    }
    _loadingDaily = true;
    try {
      final token = await _token();
      if (token == null) return []; 
      final res = await _dio().get('/vocabulary/daily?limit=30&lang=$lang',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      dailyVocab = List<Map<String, dynamic>>.from(res.data);
      dailyVocabLang = lang;
      return dailyVocab;
    } catch (_) {
      return null;
    } finally {
      _loadingDaily = false;
    }
  }
 
  // ── News ─────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>?> getNews({bool forceRefresh = false}) async {
    if (news != null && !forceRefresh) return news;
    if (_loadingNews) {
      await Future.delayed(const Duration(milliseconds: 100));
      return news;
    }
    _loadingNews = true;
    try {
      final token = await _token();
      if (token == null) return []; 
      final res = await _dio().get('/news/feed',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      news = List<Map<String, dynamic>>.from(res.data['news'] ?? []);
      return news;
    } catch (_) {
      return null;
    } finally {
      _loadingNews = false;
    }
  }
 
  // ── Preload tất cả khi app khởi động ─────────────────────
  Future<void> preloadAll() async {
    await Future.wait([
      getUser(),
      getDailyVocab(),
      getNews(),
    ]);
  }
 
  // ── Xóa cache khi logout ──────────────────────────────────
  void clear() {
    userInfo = null;
    vocabulary = null;
    news = null;
    dailyVocab = null;
    dailyVocabLang = null;
  }
}