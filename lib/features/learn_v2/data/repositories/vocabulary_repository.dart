import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';

/// Interface — cho phep thay the/mock khi test, khong phu thuoc Dio truc tiep
/// o tang goi (provider/UI).
abstract class VocabularyRepository {
  Future<List<VocabularyWord>> getNewWords({required String language});

  /// Luu 1 tu vao kho ca nhan — tai dung DUNG endpoint POST /vocabulary
  /// da co san (dung chung voi tinh nang "Luu tu" o Tab Dich).
  Future<void> saveWord({required VocabularyWord word, required String language});
}

/// Impl that — goi DUNG endpoint hien co, KHONG dung Vocabulary Core.
class VocabularyRepositoryImpl implements VocabularyRepository {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  static const _baseUrl = 'https://taiwanmate-backend-production.up.railway.app/api/v1';

  VocabularyRepositoryImpl({FlutterSecureStorage? storage, Dio? dio})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio();

@override
  Future<void> saveWord({required VocabularyWord word, required String language}) async {
    final token = await _storage.read(key: 'access_token');
    final isEn = language == 'en';
    // Backend bat buoc chinese/pinyin la string (khong duoc null) — xac nhan
    // qua loi 422 that. Voi tu tieng Anh, gui chuoi rong thay vi null.
    await _dio.post(
      '$_baseUrl/vocabulary',
      data: {
        'chinese': isEn ? '' : (word.chinese ?? ''),
        'english': isEn ? word.english : null,
        'pinyin': isEn ? '' : (word.pinyin ?? ''),
        'vietnamese': word.vietnamese,
        'source': 'learning_session',
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  @override
  Future<List<VocabularyWord>> getNewWords({required String language}) async {
    final token = await _storage.read(key: 'access_token');
    final response = await _dio.get(
      '$_baseUrl/vocabulary/daily',
      queryParameters: {'lang': language},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final List<dynamic> raw = response.data as List<dynamic>;
    final allWords = raw
        .map((json) => VocabularyWord.fromJson(json as Map<String, dynamic>))
        .toList();

    // Loc CHI tu moi — day chinh la logic "Hoc moi" (Review se lam sau)
    return allWords.where((w) => !w.isReview).toList();
  }
}