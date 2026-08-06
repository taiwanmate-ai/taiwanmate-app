import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/mock_exam/data/repositories/mock_exam_repository.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';

final mockExamRepositoryProvider = Provider<MockExamRepository>((ref) {
  return MockExamRepositoryImpl();
});

/// Ngon ngu dang chon cho tab Mock Exam — doc lap voi selectedLearnLanguageProvider
/// cua learn_v2 (tranh phu thuoc cheo giua 2 feature doc lap).
final selectedMockExamLanguageProvider = StateProvider<String>((ref) => 'zh');

final mockExamEligibilityProvider = FutureProvider.autoDispose<MockExamEligibility>((ref) async {
  final repo = ref.watch(mockExamRepositoryProvider);
  return repo.getEligibility();
});

/// Danh sach ky thi dang mo cho ngon ngu dang chon. language_id THAT (UUID)
/// khong co san o client — loc theo language_code tra ve tu API thay vi
/// truyen language_id vao query (API cho phep bo qua filter nay).
final mockExamPeriodsProvider = FutureProvider.autoDispose<List<MockExamPeriod>>((ref) async {
  final repo = ref.watch(mockExamRepositoryProvider);
  final lang = ref.watch(selectedMockExamLanguageProvider);
  final all = await repo.listPeriods();
  final wantedCode = lang == 'en' ? 'en' : 'zh-Hant-TW';
  return all.where((p) => p.languageCode == wantedCode).toList()
    ..sort((a, b) => a.versionLabel.compareTo(b.versionLabel));
});

final mockExamLatestProvider = FutureProvider.autoDispose<MockExamResult?>((ref) async {
  final repo = ref.watch(mockExamRepositoryProvider);
  return repo.getLatest();
});

final mockExamHistoryProvider = FutureProvider.autoDispose<List<MockExamResult>>((ref) async {
  final repo = ref.watch(mockExamRepositoryProvider);
  final history = await repo.getHistory();
  // Moi nhat truoc — backend khong dam bao thu tu, sap theo completed_at giam dan.
  final sorted = [...history];
  sorted.sort((a, b) {
    final ad = a.completedAt;
    final bd = b.completedAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return sorted;
});

/// Ket qua 1 attempt cu the (man hinh Xem ket qua tu lich su) — family theo
/// attemptId, autoDispose de khong giu cache mai khi roi man hinh.
final mockExamResultProvider =
    FutureProvider.autoDispose.family<MockExamResult, String>((ref, attemptId) async {
  final repo = ref.watch(mockExamRepositoryProvider);
  return repo.getResult(attemptId);
});
