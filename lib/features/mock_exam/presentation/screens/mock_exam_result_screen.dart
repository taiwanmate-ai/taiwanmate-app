import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_providers.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';
import 'package:chinesemate/features/mock_exam/presentation/widgets/mock_exam_design.dart';

/// Xem ket qua 1 lan thi — dung ngay sau khi nop bai (co san MockExamResult,
/// khong can goi lai API) HOAC mo tu Lich su (chi co attemptId, can fetch
/// qua GET /mock-exam/attempts/{id}/result).
class MockExamResultScreen extends ConsumerWidget {
  final MockExamResult? initialResult;
  final String? attemptId;

  const MockExamResultScreen.fromResult(MockExamResult result, {Key? key})
      : initialResult = result, attemptId = null, super(key: key);

  const MockExamResultScreen.fromAttemptId(String attemptId, {Key? key})
      : initialResult = null, attemptId = attemptId, super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialResult != null) {
      return _ResultBody(result: initialResult!);
    }
    final resultAsync = ref.watch(mockExamResultProvider(attemptId!));
    return Scaffold(
      backgroundColor: ExamDS.bg,
      appBar: AppBar(backgroundColor: ExamDS.bg, elevation: 0, foregroundColor: ExamDS.textDark,
          title: const Text('Kết quả')),
      body: resultAsync.when(
        data: (result) => _ResultBody(result: result, embedded: true),
        loading: () => const Center(child: CircularProgressIndicator(color: ExamDS.indigo)),
        error: (e, __) => Center(child: Text('Không tải được kết quả: $e')),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final MockExamResult result;
  final bool embedded; // true = Scaffold cha da co AppBar rieng, khong ve them

  const _ResultBody({required this.result, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildScoreCard(),
        const SizedBox(height: 16),
        if (result.sectionScores.isNotEmpty) _buildSectionScores(),
        if (result.strengths.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildConceptList('💪 Điểm mạnh', result.strengths, ExamDS.green, ExamDS.greenLight),
        ],
        if (result.weaknesses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildConceptList('📌 Cần cải thiện', result.weaknesses, ExamDS.red, ExamDS.redLight),
        ],
        if (result.recommendations != null && result.recommendations!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRecommendations(),
        ],
      ]),
    );

    if (embedded) return content;

    return Scaffold(
      backgroundColor: ExamDS.bg,
      appBar: AppBar(
        backgroundColor: ExamDS.bg, elevation: 0, foregroundColor: ExamDS.textDark,
        title: const Text('Kết quả bài thi'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Xong', style: TextStyle(color: ExamDS.indigo, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [ExamDS.indigo, ExamDS.indigoDark]),
        borderRadius: BorderRadius.circular(ExamDS.radius),
      ),
      child: Column(children: [
        const Text('Điểm tổng', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          result.overallScore != null ? '${result.overallScore!.toStringAsFixed(1)}%' : '—',
          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
        ),
        if (result.cefrBand != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            // overall_raw_score la % dung tren ngan hang cau hoi TU SOAN cua
            // TaiwanMate, KHONG phai scale score chinh thuc TOCFL/HSK, va
            // CEFR khong co thang diem chinh thuc nao — nhan phai noi ro day
            // la uoc tinh noi bo, KHONG duoc de hieu nham la chung chi/diem
            // chinh thuc (xem LevelBandRule nguong % noi bo, seed_level_
            // band_rules.py).
            child: Text('Trình độ ước tính: ${result.cefrBand} (tham khảo nội bộ TaiwanMate)',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ]),
    );
  }

  Widget _buildSectionScores() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Điểm theo phần', style: TextStyle(fontWeight: FontWeight.w900, color: ExamDS.textDark)),
        const SizedBox(height: 12),
        ...result.sectionScores.map((s) {
          final ratio = s.answeredCount == 0 ? 0.0 : s.correctCount / s.answeredCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(sectionLabel(s.sectionCode), style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('${s.correctCount}/${s.answeredCount}', style: const TextStyle(color: ExamDS.textGrey)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio, minHeight: 8, backgroundColor: const Color(0xFFEDEFFB),
                  color: ExamDS.indigo,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildConceptList(String title, List<ConceptPerformance> items, Color color, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: ExamDS.textDark)),
        const SizedBox(height: 10),
        ...items.take(6).map((c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text(c.conceptName ?? c.conceptId, style: const TextStyle(fontWeight: FontWeight.w600))),
            // Bug da sua: rawScore tu backend (PlacementScoringService.
            // score_attempt) DA la thang 0-100 (weighted_correct/weighted_
            // total * 100), KHONG phai 0-1 — nhan them 100 lan nua ra
            // "10000%" thay vi "100%".
            Text('${c.rawScore.toStringAsFixed(0)}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ]),
        )),
      ]),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('💡 Gợi ý học tiếp theo', style: TextStyle(fontWeight: FontWeight.w900, color: ExamDS.textDark)),
        const SizedBox(height: 10),
        ...result.recommendations!.take(5).map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  ', style: TextStyle(color: ExamDS.indigo, fontWeight: FontWeight.w900)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.conceptName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(r.recommendedAction, style: const TextStyle(fontSize: 12, color: ExamDS.textGrey)),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }
}
