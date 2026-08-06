/// Models go kieu ro rang cho Mock Exam (Sprint Flutter) — map truc tiep
/// tu response JSON that cua cac endpoint /mock-exam/* va /cat-v2/attempts/*
/// da co san (backend KHONG doi de phuc vu rieng Flutter, tru phan bo sung
/// language_code o MockExamPeriod va bo level_framework_id o finish()).

class MockExamEligibility {
  final bool trialUsed;
  final bool vipRequired;
  final DateTime? nextAvailableAt;
  final String periodType; // 'lifetime' (Free) | 'half_month' (VIP)
  final String periodKey;

  const MockExamEligibility({
    required this.trialUsed,
    required this.vipRequired,
    required this.nextAvailableAt,
    required this.periodType,
    required this.periodKey,
  });

  factory MockExamEligibility.fromJson(Map<String, dynamic> json) {
    return MockExamEligibility(
      trialUsed: json['trial_used'] == true,
      vipRequired: json['vip_required'] == true,
      nextAvailableAt: json['next_available_at'] == null
          ? null
          : DateTime.parse(json['next_available_at'] as String),
      periodType: (json['period_type'] ?? '') as String,
      periodKey: (json['period_key'] ?? '') as String,
    );
  }
}

class MockExamPeriod {
  final String assessmentVersionId;
  final String versionLabel;
  final String languageId;
  final String languageCode; // 'zh-Hant-TW' | 'en'
  final int questionCount;

  const MockExamPeriod({
    required this.assessmentVersionId,
    required this.versionLabel,
    required this.languageId,
    required this.languageCode,
    required this.questionCount,
  });

  factory MockExamPeriod.fromJson(Map<String, dynamic> json) {
    return MockExamPeriod(
      assessmentVersionId: json['assessment_version_id'] as String,
      versionLabel: (json['version_label'] ?? '') as String,
      languageId: json['language_id'] as String,
      languageCode: (json['language_code'] ?? '') as String,
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionOptionInfo {
  final String id;
  final String optionText;
  final int sortOrder;

  const QuestionOptionInfo({required this.id, required this.optionText, required this.sortOrder});

  factory QuestionOptionInfo.fromJson(Map<String, dynamic> json) {
    return QuestionOptionInfo(
      id: json['id'] as String,
      optionText: (json['option_text'] ?? '') as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class StimulusCandidateInfo {
  final String id;
  final String stimulusType; // 'audio' | 'text' | 'image'
  final String? mediaUrl;
  final int? durationSeconds;
  final int? replayLimit;

  const StimulusCandidateInfo({
    required this.id,
    required this.stimulusType,
    this.mediaUrl,
    this.durationSeconds,
    this.replayLimit,
  });

  factory StimulusCandidateInfo.fromJson(Map<String, dynamic> json) {
    return StimulusCandidateInfo(
      id: json['id'] as String,
      stimulusType: (json['stimulus_type'] ?? '') as String,
      mediaUrl: json['media_url'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      replayLimit: (json['replay_limit'] as num?)?.toInt(),
    );
  }
}

class ExamQuestion {
  final String id;
  final String questionType;
  final String promptText;
  final String? contextText;
  final List<QuestionOptionInfo> options;
  final StimulusCandidateInfo? stimulus;

  const ExamQuestion({
    required this.id,
    required this.questionType,
    required this.promptText,
    this.contextText,
    required this.options,
    this.stimulus,
  });

  factory ExamQuestion.fromJson(Map<String, dynamic> json) {
    return ExamQuestion(
      id: json['id'] as String,
      questionType: (json['question_type'] ?? '') as String,
      promptText: (json['prompt_text'] ?? '') as String,
      contextText: json['context_text'] as String?,
      options: ((json['options'] ?? []) as List)
          .map((o) => QuestionOptionInfo.fromJson(o as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      stimulus: json['stimulus'] == null
          ? null
          : StimulusCandidateInfo.fromJson(json['stimulus'] as Map<String, dynamic>),
    );
  }
}

class SectionScore {
  final String? sectionId;
  final String? sectionCode;
  final int answeredCount;
  final int correctCount;

  const SectionScore({
    this.sectionId,
    this.sectionCode,
    required this.answeredCount,
    required this.correctCount,
  });

  factory SectionScore.fromJson(Map<String, dynamic> json) {
    return SectionScore(
      sectionId: json['section_id'] as String?,
      sectionCode: json['section_code'] as String?,
      answeredCount: (json['answered_count'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class ConceptPerformance {
  final String conceptId;
  final String? conceptName;
  final double rawScore;
  final int evidenceCount;
  final String confidence;
  final bool isLeaf;

  const ConceptPerformance({
    required this.conceptId,
    this.conceptName,
    required this.rawScore,
    required this.evidenceCount,
    required this.confidence,
    required this.isLeaf,
  });

  factory ConceptPerformance.fromJson(Map<String, dynamic> json) {
    return ConceptPerformance(
      conceptId: json['concept_id'] as String,
      conceptName: json['concept_name'] as String?,
      rawScore: (json['raw_score'] as num?)?.toDouble() ?? 0,
      evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
      confidence: (json['confidence'] ?? '') as String,
      isLeaf: json['is_leaf'] == true,
    );
  }
}

class MockExamRecommendation {
  final String conceptId;
  final String conceptName;
  final String confidence;
  final String performance;
  final String priority;
  final String recommendedAction;

  const MockExamRecommendation({
    required this.conceptId,
    required this.conceptName,
    required this.confidence,
    required this.performance,
    required this.priority,
    required this.recommendedAction,
  });

  factory MockExamRecommendation.fromJson(Map<String, dynamic> json) {
    return MockExamRecommendation(
      conceptId: json['concept_id'] as String,
      conceptName: (json['concept_name'] ?? '') as String,
      confidence: (json['confidence'] ?? '') as String,
      performance: (json['performance'] ?? '') as String,
      priority: (json['priority'] ?? '') as String,
      recommendedAction: (json['recommended_action'] ?? '') as String,
    );
  }
}

class MockExamResult {
  final String attemptId;
  final String status; // 'in_progress' | 'completed'
  final String? periodType;
  final String? periodKey;
  final DateTime? completedAt;
  final double? overallScore;
  final String? cefrBand;
  final List<SectionScore> sectionScores;
  final List<ConceptPerformance> strengths;
  final List<ConceptPerformance> weaknesses;
  final List<MockExamRecommendation>? recommendations;

  const MockExamResult({
    required this.attemptId,
    required this.status,
    this.periodType,
    this.periodKey,
    this.completedAt,
    this.overallScore,
    this.cefrBand,
    required this.sectionScores,
    required this.strengths,
    required this.weaknesses,
    this.recommendations,
  });

  bool get isCompleted => status == 'completed';

  factory MockExamResult.fromJson(Map<String, dynamic> json) {
    return MockExamResult(
      attemptId: json['attempt_id'] as String,
      status: (json['status'] ?? '') as String,
      periodType: json['period_type'] as String?,
      periodKey: json['period_key'] as String?,
      completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      cefrBand: json['cefr_band'] as String?,
      sectionScores: ((json['section_scores'] ?? []) as List)
          .map((s) => SectionScore.fromJson(s as Map<String, dynamic>))
          .toList(),
      strengths: ((json['strengths'] ?? []) as List)
          .map((s) => ConceptPerformance.fromJson(s as Map<String, dynamic>))
          .toList(),
      weaknesses: ((json['weaknesses'] ?? []) as List)
          .map((s) => ConceptPerformance.fromJson(s as Map<String, dynamic>))
          .toList(),
      recommendations: json['recommendations'] == null
          ? null
          : (json['recommendations'] as List)
              .map((r) => MockExamRecommendation.fromJson(r as Map<String, dynamic>))
              .toList(),
    );
  }
}

class StimulusPlayResult {
  final int playCount;
  final int? remainingPlays;
  final String? transcript;

  const StimulusPlayResult({required this.playCount, this.remainingPlays, this.transcript});

  factory StimulusPlayResult.fromJson(Map<String, dynamic> json) {
    return StimulusPlayResult(
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      remainingPlays: (json['remaining_plays'] as num?)?.toInt(),
      transcript: json['transcript'] as String?,
    );
  }
}
