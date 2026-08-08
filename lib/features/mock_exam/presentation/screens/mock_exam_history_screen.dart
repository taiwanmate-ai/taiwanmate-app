import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_providers.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';
import 'package:chinesemate/features/mock_exam/presentation/widgets/mock_exam_design.dart';
import 'package:chinesemate/features/mock_exam/presentation/screens/mock_exam_result_screen.dart';

class MockExamHistoryScreen extends ConsumerWidget {
  const MockExamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(mockExamHistoryProvider);
    return Scaffold(
      backgroundColor: ExamDS.bg,
      appBar: AppBar(
        backgroundColor: ExamDS.bg, elevation: 0, foregroundColor: ExamDS.textDark,
        title: const Text('Lịch sử thi thử'),
      ),
      body: historyAsync.when(
        data: (history) {
          final completed = history.where((r) => r.isCompleted).toList();
          if (completed.isEmpty) {
            return const Center(
              child: Text('Chưa có lần thi nào hoàn thành.', style: TextStyle(color: ExamDS.textGrey)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: completed.length,
            itemBuilder: (context, i) => _HistoryCard(result: completed[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: ExamDS.indigo)),
        error: (e, __) => Center(child: Text('Không tải được lịch sử: $e')),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final MockExamResult result;
  const _HistoryCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final date = result.completedAt != null
        ? DateFormat('dd/MM/yyyy').format(result.completedAt!.toLocal())
        : '—';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MockExamResultScreen.fromAttemptId(result.attemptId),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: ExamDS.indigoLight, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(
                result.overallScore != null ? result.overallScore!.toStringAsFixed(0) : '—',
                style: const TextStyle(fontWeight: FontWeight.w900, color: ExamDS.indigo),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(date, style: const TextStyle(fontWeight: FontWeight.w800, color: ExamDS.textDark)),
              const SizedBox(height: 2),
              // Khong duoc de hieu nham la chung chi/diem chinh thuc — xem
              // ghi chu o mock_exam_result_screen.dart._buildScoreCard().
              Text(
                  result.cefrBand != null
                      ? 'Trình độ ước tính: ${result.cefrBand} (nội bộ)'
                      : 'Chưa xếp trình độ',
                  style: const TextStyle(fontSize: 12, color: ExamDS.textGrey)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: ExamDS.textGrey),
        ]),
      ),
    );
  }
}
