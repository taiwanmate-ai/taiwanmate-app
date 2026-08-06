import 'package:dio/dio.dart';
import 'package:chinesemate/core/network/dio_client.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';

/// Goi cac endpoint /mock-exam/* (backend). next-question dung route RIENG
/// cua Mock Exam (/mock-exam/attempts/{id}/next-question — server tu chon
/// dung section reading/listening/grammar con thieu); answer + stimulus-play
/// van dung chung /cat-v2/attempts/* (khong phu thuoc attempt_type, khong
/// can/khong duoc viet rieng). Dung DioClient.instance (co san Authorization
/// interceptor tu SecureStorage) thay vi tu quan ly token nhu vai repository cu.
abstract class MockExamRepository {
  Future<MockExamEligibility> getEligibility();
  Future<List<MockExamPeriod>> listPeriods({String? languageId});
  Future<MockExamResult> start(String assessmentVersionId);
  Future<({bool hasNext, ExamQuestion? question})> getNextQuestion(String attemptId);
  Future<void> submitAnswer(String attemptId, {required String questionId, String? selectedOptionId});
  Future<StimulusPlayResult> playStimulus(String attemptId, String stimulusId);
  Future<MockExamResult> finish(String attemptId);
  Future<MockExamResult> getResult(String attemptId);
  Future<MockExamResult?> getLatest();
  Future<List<MockExamResult>> getHistory();
}

class MockExamRepositoryImpl implements MockExamRepository {
  final Dio _dio;

  MockExamRepositoryImpl({Dio? dio}) : _dio = dio ?? DioClient.instance;

  @override
  Future<MockExamEligibility> getEligibility() async {
    final resp = await _dio.get('/mock-exam/eligibility');
    return MockExamEligibility.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<List<MockExamPeriod>> listPeriods({String? languageId}) async {
    final resp = await _dio.get(
      '/mock-exam/periods',
      queryParameters: languageId == null ? null : {'language_id': languageId},
    );
    final data = resp.data as Map<String, dynamic>;
    return ((data['periods'] ?? []) as List)
        .map((p) => MockExamPeriod.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<MockExamResult> start(String assessmentVersionId) async {
    final resp = await _dio.post(
      '/mock-exam/start',
      data: {'assessment_version_id': assessmentVersionId},
    );
    return MockExamResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<({bool hasNext, ExamQuestion? question})> getNextQuestion(String attemptId) async {
    // Dung route RIENG cua Mock Exam (/mock-exam/..., khong phai /cat-v2/...
    // dung chung) — server tu chon dung section (reading/listening/grammar)
    // con thieu truoc khi lay cau, Flutter khong can/khong duoc tu chon.
    final resp = await _dio.get('/mock-exam/attempts/$attemptId/next-question');
    final data = resp.data as Map<String, dynamic>;
    final hasNext = data['has_next'] == true;
    final question = data['question'] == null
        ? null
        : ExamQuestion.fromJson(data['question'] as Map<String, dynamic>);
    return (hasNext: hasNext, question: question);
  }

  @override
  Future<void> submitAnswer(String attemptId, {required String questionId, String? selectedOptionId}) async {
    await _dio.post(
      '/cat-v2/attempts/$attemptId/answer',
      data: {
        'question_id': questionId,
        if (selectedOptionId != null) 'selected_option_id': selectedOptionId,
      },
    );
  }

  @override
  Future<StimulusPlayResult> playStimulus(String attemptId, String stimulusId) async {
    final resp = await _dio.post(
      '/cat-v2/attempts/$attemptId/stimulus-play',
      data: {'stimulus_id': stimulusId},
    );
    return StimulusPlayResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<MockExamResult> finish(String attemptId) async {
    final resp = await _dio.post('/mock-exam/attempts/$attemptId/finish');
    return MockExamResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<MockExamResult> getResult(String attemptId) async {
    final resp = await _dio.get('/mock-exam/attempts/$attemptId/result');
    return MockExamResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<MockExamResult?> getLatest() async {
    final resp = await _dio.get('/mock-exam/latest');
    if (resp.data == null) return null;
    return MockExamResult.fromJson(resp.data as Map<String, dynamic>);
  }

  @override
  Future<List<MockExamResult>> getHistory() async {
    final resp = await _dio.get('/mock-exam/history');
    final data = resp.data as Map<String, dynamic>;
    return ((data['history'] ?? []) as List)
        .map((r) => MockExamResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
