import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/mock_exam/data/repositories/mock_exam_repository.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_session_state.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_providers.dart';

class MockExamSessionNotifier extends StateNotifier<MockExamSessionState> {
  final MockExamRepository _repository;

  MockExamSessionNotifier(this._repository) : super(const MockExamSessionState());

  /// Bat dau (hoac resume, server tu quyet dinh — xem docstring
  /// MockExamService.start_or_resume) 1 ky thi. totalQuestionCount la uoc
  /// luong tu MockExamPeriod (chi hien thi "x / ~y", KHONG dung de dieu
  /// khien logic ket thuc — server (has_next=false) moi la nguon that).
  Future<void> startOrResume(String assessmentVersionId, {int? totalQuestionCount}) async {
    state = MockExamSessionState(phase: ExamPhase.loading, totalQuestionCount: totalQuestionCount);
    try {
      final result = await _repository.start(assessmentVersionId);
      if (result.isCompleted) {
        // Da lam xong ky nay tu truoc (het luot, server tra nguyen ket qua cu).
        state = state.copyWith(phase: ExamPhase.finished, attemptId: result.attemptId, finalResult: result);
        return;
      }
      state = state.copyWith(phase: ExamPhase.inProgress, attemptId: result.attemptId);
      await _loadNextQuestion();
    } catch (e) {
      state = state.copyWith(phase: ExamPhase.error, errorMessage: e.toString());
    }
  }

  /// Resume 1 attempt DA BIET attempt_id (vd tu GET /mock-exam/latest khi
  /// status='in_progress') — KHONG can goi lai POST /start (khong co san
  /// assessment_version_id o MockExamResultOutSchema, va cung khong can
  /// thiet: next-question hoat dong truc tiep tren attempt_id da co, chi
  /// can dung ownership dung nhu goi tu dau).
  Future<void> resumeAttempt(String attemptId, {int? totalQuestionCount}) async {
    state = MockExamSessionState(
      phase: ExamPhase.loading, attemptId: attemptId, totalQuestionCount: totalQuestionCount,
    );
    await _loadNextQuestion();
  }

  Future<void> _loadNextQuestion() async {
    final attemptId = state.attemptId;
    if (attemptId == null) return;
    try {
      final next = await _repository.getNextQuestion(attemptId);
      if (!next.hasNext || next.question == null) {
        await _finish();
        return;
      }
      state = state.copyWith(
        phase: ExamPhase.inProgress,
        currentQuestion: next.question,
        clearSelectedOptionId: true,
        // Bug da sua: KHONG reset 3 field nay tung khien remaining_plays/
        // nut "Phat" cua cau TRUOC "dinh" sang cau MOI — xem docstring
        // playbackNonce trong mock_exam_session_state.dart.
        clearPlaybackState: true,
      );
    } catch (e) {
      state = state.copyWith(phase: ExamPhase.error, errorMessage: e.toString());
    }
  }

  void selectOption(String optionId) {
    if (state.phase != ExamPhase.inProgress) return;
    state = state.copyWith(selectedOptionId: optionId);
  }

  /// Nop dap an cau hien tai roi tu dong tai cau ke tiep (hoac ket thuc neu
  /// het cau — server quyet dinh qua has_next, khong phai client dem so).
  Future<void> submitAndAdvance() async {
    final attemptId = state.attemptId;
    final question = state.currentQuestion;
    final selected = state.selectedOptionId;
    if (attemptId == null || question == null || selected == null) return;

    state = state.copyWith(phase: ExamPhase.submitting);
    try {
      await _repository.submitAnswer(attemptId, questionId: question.id, selectedOptionId: selected);
      state = state.copyWith(answeredCount: state.answeredCount + 1);
      await _loadNextQuestion();
    } catch (e) {
      state = state.copyWith(phase: ExamPhase.error, errorMessage: e.toString());
    }
  }

  /// Phat Stimulus cua cau hien tai — dung cho CA 'audio' (client tu phat
  /// media_url, transcript tra ve se la null) LAN 'text' (chua co audio TTS
  /// that, client dung flutter_tts doc transcript tra ve — xem
  /// mock_exam_taking_screen.dart). playbackNonce tang moi lan goi thanh
  /// cong de man hinh phan biet duoc 1 lan phat MOI (ke ca phat lai).
  Future<void> playCurrentStimulus() async {
    final attemptId = state.attemptId;
    final stimulus = state.currentQuestion?.stimulus;
    if (attemptId == null || stimulus == null) return;

    try {
      final result = await _repository.playStimulus(attemptId, stimulus.id);
      state = state.copyWith(
        lastPlayedTranscript: result.transcript,
        lastPlayedRemainingPlays: result.remainingPlays,
        playbackNonce: state.playbackNonce + 1,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> _finish() async {
    final attemptId = state.attemptId;
    if (attemptId == null) return;
    try {
      final result = await _repository.finish(attemptId);
      state = state.copyWith(phase: ExamPhase.finished, finalResult: result, clearCurrentQuestion: true);
    } catch (e) {
      state = state.copyWith(phase: ExamPhase.error, errorMessage: e.toString());
    }
  }
}

/// Provider thu cong (autoDispose) — man hinh lam bai goi .startOrResume()
/// trong initState, giong quy uoc cua learningSessionProvider (learn_v2).
final mockExamSessionProvider =
    StateNotifierProvider.autoDispose<MockExamSessionNotifier, MockExamSessionState>((ref) {
  final repository = ref.watch(mockExamRepositoryProvider);
  return MockExamSessionNotifier(repository);
});
