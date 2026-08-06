import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_providers.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_models.dart';
import 'package:chinesemate/features/mock_exam/presentation/widgets/mock_exam_design.dart';
import 'package:chinesemate/features/mock_exam/presentation/screens/mock_exam_taking_screen.dart';
import 'package:chinesemate/features/mock_exam/presentation/screens/mock_exam_history_screen.dart';

/// Man hinh chinh cua tab "Thi thử" — danh sach ky thi dang mo + trang thai
/// luot thi (Free/VIP) + tiep tuc bai dang lam do (neu co) + loi vao lich su.
class MockExamListScreen extends ConsumerStatefulWidget {
  final String initialLanguage; // 'zh' | 'en' — dong bo voi ngon ngu dang hoc o Learn Hub
  const MockExamListScreen({super.key, this.initialLanguage = 'zh'});

  @override
  ConsumerState<MockExamListScreen> createState() => _MockExamListScreenState();
}

class _MockExamListScreenState extends ConsumerState<MockExamListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedMockExamLanguageProvider.notifier).state = widget.initialLanguage;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(mockExamEligibilityProvider);
    ref.invalidate(mockExamPeriodsProvider);
    ref.invalidate(mockExamLatestProvider);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(selectedMockExamLanguageProvider);

    return Container(
      color: ExamDS.bg,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildLanguageToggle(lang),
            const SizedBox(height: 16),
            _buildInProgressBanner(),
            _buildEligibilityCard(lang),
            const SizedBox(height: 16),
            _buildHistoryLink(),
            const SizedBox(height: 16),
            const Text('Kỳ thi đang mở',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ExamDS.textDark)),
            const SizedBox(height: 8),
            _buildPeriodsList(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(String lang) {
    Widget chip(String code, String label) {
      final selected = lang == code;
      return Expanded(
        child: GestureDetector(
          onTap: () => ref.read(selectedMockExamLanguageProvider.notifier).state = code,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? ExamDS.indigo : ExamDS.white,
              borderRadius: BorderRadius.circular(ExamDS.radiusSm),
              border: Border.all(color: selected ? ExamDS.indigo : const Color(0xFFE0E4F5)),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : ExamDS.textGrey)),
            ),
          ),
        ),
      );
    }

    return Row(children: [chip('zh', '中文 TOCFL'), chip('en', 'English')]);
  }

  Widget _buildInProgressBanner() {
    final latestAsync = ref.watch(mockExamLatestProvider);
    return latestAsync.when(
      data: (latest) {
        if (latest == null || latest.status != 'in_progress') return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ExamDS.yellowLight,
              borderRadius: BorderRadius.circular(ExamDS.radius),
            ),
            child: Row(children: [
              const Text('⏳', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Bạn đang có 1 bài thi chưa nộp',
                    style: TextStyle(fontWeight: FontWeight.w800, color: ExamDS.textDark)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MockExamTakingScreen.resume(attemptId: latest.attemptId),
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ExamDS.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tiếp tục', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildEligibilityCard(String lang) {
    final eligAsync = ref.watch(mockExamEligibilityProvider);
    return eligAsync.when(
      data: (elig) {
        String text;
        Color bg;
        if (!elig.vipRequired) {
          text = elig.periodType == 'half_month'
              ? 'Bạn là VIP — có thể thi mỗi nửa tháng.'
              : 'Bạn còn 1 lượt thi thử miễn phí.';
          bg = ExamDS.greenLight;
        } else if (elig.nextAvailableAt != null) {
          text = 'Đã dùng hết lượt. Lượt tiếp theo: '
              '${DateFormat('dd/MM/yyyy HH:mm').format(elig.nextAvailableAt!.toLocal())}';
          bg = ExamDS.redLight;
        } else {
          text = 'Đã dùng hết lượt thi thử miễn phí. Nâng cấp VIP để thi định kỳ mỗi nửa tháng.';
          bg = ExamDS.redLight;
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(ExamDS.radiusSm)),
          child: Text(text, style: const TextStyle(color: ExamDS.textDark, fontWeight: FontWeight.w600)),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(color: ExamDS.indigo),
      ),
      error: (e, __) => Text('Không tải được trạng thái lượt thi: $e',
          style: const TextStyle(color: ExamDS.red)),
    );
  }

  Widget _buildHistoryLink() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MockExamHistoryScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radiusSm)),
        child: Row(children: const [
          Text('📊', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Expanded(child: Text('Xem lịch sử các lần thi', style: TextStyle(fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right, color: ExamDS.textGrey),
        ]),
      ),
    );
  }

  Widget _buildPeriodsList(String lang) {
    final periodsAsync = ref.watch(mockExamPeriodsProvider);
    final eligAsync = ref.watch(mockExamEligibilityProvider);
    final latestAsync = ref.watch(mockExamLatestProvider);

    return periodsAsync.when(
      data: (periods) {
        if (periods.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Chưa có kỳ thi nào đang mở cho ngôn ngữ này.',
                  style: TextStyle(color: ExamDS.textGrey)),
            ),
          );
        }
        final canStart = eligAsync.asData?.value.vipRequired == false;
        final hasInProgress = latestAsync.asData?.value?.status == 'in_progress';

        return Column(
          children: periods.map((p) => _PeriodCard(
            period: p,
            enabled: canStart && !hasInProgress,
            onStart: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MockExamTakingScreen.start(
                assessmentVersionId: p.assessmentVersionId,
                totalQuestionCount: p.questionCount,
              ),
            )).then((_) => _refresh()),
          )).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: ExamDS.indigo)),
      ),
      error: (e, __) => Text('Không tải được danh sách kỳ thi: $e',
          style: const TextStyle(color: ExamDS.red)),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final MockExamPeriod period;
  final bool enabled;
  final VoidCallback onStart;

  const _PeriodCard({required this.period, required this.enabled, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: ExamDS.indigoLight, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('📝', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kỳ thi ${period.versionLabel}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: ExamDS.textDark)),
            const SizedBox(height: 2),
            Text('${period.questionCount} câu · ${languageDisplayName(period.languageCode)}',
                style: const TextStyle(fontSize: 12, color: ExamDS.textGrey)),
          ]),
        ),
        ElevatedButton(
          onPressed: enabled ? onStart : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ExamDS.indigo,
            disabledBackgroundColor: const Color(0xFFE0E4F5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Bắt đầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}
