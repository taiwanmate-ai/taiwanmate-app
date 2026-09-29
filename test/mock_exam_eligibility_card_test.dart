// Audit Mock Exam (2026-09-28, phan 5+6): widget test cho 4 trang thai the "lượt thi thử"
// (Free con/hết, VIP con/hết) qua fake repository — dac biet xac nhan bug da sua: VIP het luot
// ky nay (nextAvailableAt co gia tri) PHAI hien dong "Đã dùng hết lượt...", KHONG con hien nham
// "Bạn là VIP — có thể thi..." nhu con luot (vip_required cua backend LUON false voi VIP, xem
// docstring _buildEligibilityCard).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_providers.dart';
import 'package:chinesemate/features/mock_exam/data/repositories/mock_exam_repository.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';
import 'package:chinesemate/features/mock_exam/presentation/screens/mock_exam_list_screen.dart';

class _FakeRepo implements MockExamRepository {
  final MockExamEligibility Function(String languageCode) eligibilityFor;
  final MockExamResult? Function(String? languageCode)? latestFor;
  _FakeRepo({required this.eligibilityFor, this.latestFor});

  @override
  Future<MockExamEligibility> getEligibility(String languageCode) async => eligibilityFor(languageCode);

  @override
  Future<MockExamResult?> getLatest([String? languageCode]) async =>
      latestFor == null ? null : latestFor!(languageCode);

  @override
  Future<List<MockExamPeriod>> listPeriods({String? languageId}) async => [];
  @override
  Future<List<MockExamResult>> getHistory() async => [];

  @override
  Future<MockExamResult> start(String assessmentVersionId) => throw UnimplementedError();
  @override
  Future<({bool hasNext, ExamQuestion? question})> getNextQuestion(String attemptId) => throw UnimplementedError();
  @override
  Future<void> submitAnswer(String attemptId, {required String questionId, String? selectedOptionId}) =>
      throw UnimplementedError();
  @override
  Future<StimulusPlayResult> playStimulus(String attemptId, String stimulusId) => throw UnimplementedError();
  @override
  Future<MockExamResult> finish(String attemptId) => throw UnimplementedError();
  @override
  Future<MockExamResult> getResult(String attemptId) => throw UnimplementedError();
}

MockExamEligibility _elig({
  required bool trialUsed,
  required bool vipRequired,
  DateTime? nextAvailableAt,
  required String periodType,
  required String languageCode,
}) =>
    MockExamEligibility(
      trialUsed: trialUsed,
      vipRequired: vipRequired,
      nextAvailableAt: nextAvailableAt,
      periodType: periodType,
      periodKey: 'k',
      languageCode: languageCode,
    );

Future<void> _pump(WidgetTester tester, MockExamEligibility Function(String) eligibilityFor,
    {String initialLanguage = 'zh'}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [mockExamRepositoryProvider.overrideWithValue(_FakeRepo(eligibilityFor: eligibilityFor))],
    child: MaterialApp(home: Scaffold(body: MockExamListScreen(initialLanguage: initialLanguage))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('The trang thai luot thi thu — 4 truong hop', () {
    testWidgets('Free con luot', (tester) async {
      await _pump(tester, (lang) => _elig(
          trialUsed: false, vipRequired: false, nextAvailableAt: null,
          periodType: 'lifetime', languageCode: 'zh-Hant-TW'));
      expect(find.textContaining('Bạn còn 1 lượt thi thử miễn phí'), findsOneWidget);
      expect(find.textContaining('mỗi ngôn ngữ có 1 lượt riêng'), findsOneWidget);
      expect(find.textContaining('Đã dùng hết lượt'), findsNothing);
    });

    testWidgets('Free hết luot', (tester) async {
      await _pump(tester, (lang) => _elig(
          trialUsed: true, vipRequired: true, nextAvailableAt: null,
          periodType: 'lifetime', languageCode: 'zh-Hant-TW'));
      expect(find.textContaining('Đã dùng hết lượt thi thử miễn phí'), findsOneWidget);
      expect(find.textContaining('Bạn còn 1 lượt'), findsNothing);
      expect(find.textContaining('Bạn là VIP'), findsNothing);
    });

    testWidgets('VIP con luot ky nay (nextAvailableAt null)', (tester) async {
      await _pump(tester, (lang) => _elig(
          trialUsed: false, vipRequired: false, nextAvailableAt: null,
          periodType: 'half_month', languageCode: 'en'));
      expect(find.textContaining('Bạn là VIP — có thể thi'), findsOneWidget);
      expect(find.textContaining('mỗi nửa tháng'), findsOneWidget);
      expect(find.textContaining('Đã dùng hết lượt'), findsNothing);
    });

    testWidgets('VIP hết luot ky nay (nextAvailableAt co gia tri) — bug da sua: PHAI hien "đã '
        'dùng hết", KHÔNG được hiện nhầm "có thể thi" như còn lượt', (tester) async {
      await _pump(tester, (lang) => _elig(
          trialUsed: false, vipRequired: false, nextAvailableAt: DateTime(2026, 10, 1),
          periodType: 'half_month', languageCode: 'en'));
      expect(find.textContaining('Đã dùng hết lượt'), findsOneWidget);
      expect(find.textContaining('Lượt tiếp theo'), findsOneWidget);
      expect(find.textContaining('Bạn là VIP — có thể thi'), findsNothing); // day chinh la bug da sua
    });
  });
}
