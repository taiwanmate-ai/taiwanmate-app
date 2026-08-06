import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';

enum ExamPhase { idle, loading, inProgress, submitting, finished, error }

/// State cho 1 phien lam bai Mock Exam — tu luc bat dau/resume toi luc nop
/// bai xong. KHONG luu toan bo danh sach cau hoi (server dieu phoi tuan tu
/// qua GET next-question, giong CAT V2 adaptive flow that su, khong phai
/// 1 danh sach co san de client tu duyet).
class MockExamSessionState {
  final ExamPhase phase;
  final String? attemptId;
  final ExamQuestion? currentQuestion;
  final String? selectedOptionId;
  final int answeredCount;
  final int? totalQuestionCount; // tu MockExamPeriod.questionCount, chi de hien "x/y" uoc luong
  final String? errorMessage;
  final MockExamResult? finalResult;

  /// Transcript vua fetch duoc tu lan phat gan nhat (stimulus_type='text')
  /// — man hinh lang nghe thay doi field nay de kich TTS, khong tu doc
  /// truc tiep tu day (tranh doc lai khi state rebuild vi ly do khac).
  final String? lastPlayedTranscript;
  final int? lastPlayedRemainingPlays;

  /// Tang moi lan phat MOI (ke ca phat lai cung 1 stimulus) de man hinh
  /// biet can TTS lai. RESET VE 0 moi khi sang cau moi (qua copyWith(
  /// clearPlaybackState: true) trong _loadNextQuestion()) — neu KHONG
  /// reset, 3 field nay (tung la bug that): (1) remaining_plays cua cau
  /// TRUOC bi hien nham cho cau MOI (kem ca khi da het luot -> nut "Phat"
  /// bi disable VINH VIEN tu do cho MOI cau sau, dung la trieu chung
  /// "cau ve sau khong doc nua"); (2) hasPlayed/nhan nut sai ("Nghe lai"
  /// thay vi "Phat" cho 1 cau chua tung duoc phat).
  final int playbackNonce;

  const MockExamSessionState({
    this.phase = ExamPhase.idle,
    this.attemptId,
    this.currentQuestion,
    this.selectedOptionId,
    this.answeredCount = 0,
    this.totalQuestionCount,
    this.errorMessage,
    this.finalResult,
    this.lastPlayedTranscript,
    this.lastPlayedRemainingPlays,
    this.playbackNonce = 0,
  });

  bool get canSubmit => selectedOptionId != null && phase == ExamPhase.inProgress;

  MockExamSessionState copyWith({
    ExamPhase? phase,
    String? attemptId,
    ExamQuestion? currentQuestion,
    bool clearCurrentQuestion = false,
    String? selectedOptionId,
    bool clearSelectedOptionId = false,
    int? answeredCount,
    int? totalQuestionCount,
    String? errorMessage,
    bool clearError = false,
    MockExamResult? finalResult,
    String? lastPlayedTranscript,
    int? lastPlayedRemainingPlays,
    int? playbackNonce,
    bool clearPlaybackState = false,
  }) {
    return MockExamSessionState(
      phase: phase ?? this.phase,
      attemptId: attemptId ?? this.attemptId,
      currentQuestion: clearCurrentQuestion ? null : (currentQuestion ?? this.currentQuestion),
      selectedOptionId: clearSelectedOptionId ? null : (selectedOptionId ?? this.selectedOptionId),
      answeredCount: answeredCount ?? this.answeredCount,
      totalQuestionCount: totalQuestionCount ?? this.totalQuestionCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      finalResult: finalResult ?? this.finalResult,
      lastPlayedTranscript: clearPlaybackState ? null : (lastPlayedTranscript ?? this.lastPlayedTranscript),
      lastPlayedRemainingPlays:
          clearPlaybackState ? null : (lastPlayedRemainingPlays ?? this.lastPlayedRemainingPlays),
      playbackNonce: clearPlaybackState ? 0 : (playbackNonce ?? this.playbackNonce),
    );
  }
}
