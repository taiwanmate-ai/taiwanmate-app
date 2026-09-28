// Audit Mock Exam (2026-09-28): quota Free tach RIENG theo ngon ngu + start() khong bao gio
// duoc am tham tra ve attempt cua ngon ngu khac — client (session provider) phai TU KIEM TRA,
// khong tin mu quang ket qua backend tra ve (dong thoi phong hong neu backend co loi tuong tu).
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_session_provider.dart';
import 'package:chinesemate/features/mock_exam/data/repositories/mock_exam_repository.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_session_state.dart';

MockExamResult _result({required String attemptId, required String versionId, bool completed = false}) {
  return MockExamResult(
    attemptId: attemptId,
    assessmentVersionId: versionId,
    languageCode: 'zh-Hant-TW',
    status: completed ? 'completed' : 'in_progress',
    sectionScores: const [],
    strengths: const [],
    weaknesses: const [],
  );
}

class _FakeRepo implements MockExamRepository {
  final MockExamResult? startResult;
  _FakeRepo({this.startResult});

  @override
  Future<MockExamResult> start(String assessmentVersionId) async => startResult!;

  @override
  Future<({bool hasNext, ExamQuestion? question})> getNextQuestion(String attemptId) async =>
      (hasNext: false, question: null);

  @override
  Future<MockExamResult> finish(String attemptId) async => _result(attemptId: attemptId, versionId: 'v');

  // Cac method con lai khong dung trong test nay.
  @override
  Future<MockExamEligibility> getEligibility(String languageCode) => throw UnimplementedError();
  @override
  Future<List<MockExamPeriod>> listPeriods({String? languageId}) => throw UnimplementedError();
  @override
  Future<void> submitAnswer(String attemptId, {required String questionId, String? selectedOptionId}) =>
      throw UnimplementedError();
  @override
  Future<StimulusPlayResult> playStimulus(String attemptId, String stimulusId) => throw UnimplementedError();
  @override
  Future<MockExamResult> getResult(String attemptId) => throw UnimplementedError();
  @override
  Future<MockExamResult?> getLatest() => throw UnimplementedError();
  @override
  Future<List<MockExamResult>> getHistory() => throw UnimplementedError();
}

void main() {
  group('MockExamEligibility.fromJson', () {
    test('doc dung language_code (quota gio rieng theo ngon ngu)', () {
      final e = MockExamEligibility.fromJson({
        'trial_used': false, 'vip_required': false, 'next_available_at': null,
        'period_type': 'lifetime', 'period_key': 'LIFETIME:en', 'language_code': 'en',
      });
      expect(e.languageCode, 'en');
      expect(e.trialUsed, isFalse);
    });
  });

  group('MockExamResult.fromJson', () {
    test('doc dung assessment_version_id + language_code (de client tu kiem tra)', () {
      final r = MockExamResult.fromJson({
        'attempt_id': 'a1', 'assessment_version_id': 'v1', 'language_code': 'zh-Hant-TW',
        'status': 'in_progress', 'section_scores': [], 'strengths': [], 'weaknesses': [],
      });
      expect(r.assessmentVersionId, 'v1');
      expect(r.languageCode, 'zh-Hant-TW');
    });
  });

  group('MockExamSessionNotifier.startOrResume — chong tra nham attempt khac ngon ngu/version', () {
    test('assessment_version_id KHOP -> khong bi chan, tiep tuc luong binh thuong', () async {
      final notifier = MockExamSessionNotifier(
        _FakeRepo(startResult: _result(attemptId: 'a1', versionId: 'v-en')),
      );
      await notifier.startOrResume('v-en');
      // Fake getNextQuestion() luon hasNext=false -> luong that se tu dong finish() ngay (dung
      // hanh vi binh thuong, khac voi truong hop bi CHAN o duoi) — chi can xac nhan KHONG bi
      // guard moi chan nham (phase khac error, dung attemptId cua ket qua tra ve).
      expect(notifier.state.phase, isNot(ExamPhase.error));
      expect(notifier.state.attemptId, 'a1');
    });

    test('assessment_version_id LECH (bug backend tra nham) -> error, KHONG vao inProgress/finished', () async {
      final notifier = MockExamSessionNotifier(
        // Client yeu cau 'v-en' nhung backend (gia lap loi) tra ve attempt cua 'v-zh'.
        _FakeRepo(startResult: _result(attemptId: 'a-zh', versionId: 'v-zh')),
      );
      await notifier.startOrResume('v-en');
      expect(notifier.state.phase, ExamPhase.error);
      expect(notifier.state.errorMessage, contains('không khớp'));
      // KHONG duoc gan attemptId cua attempt sai ngon ngu vao state.
      expect(notifier.state.attemptId, isNull);
    });

    test('lech ca khi attempt da hoan thanh (isCompleted) -> van bao loi, khong hien nham ket qua', () async {
      final notifier = MockExamSessionNotifier(
        _FakeRepo(startResult: _result(attemptId: 'a-zh', versionId: 'v-zh', completed: true)),
      );
      await notifier.startOrResume('v-en');
      expect(notifier.state.phase, ExamPhase.error);
      expect(notifier.state.finalResult, isNull);
    });
  });
}
