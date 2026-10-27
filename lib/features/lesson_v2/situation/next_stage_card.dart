import 'package:flutter/material.dart';

/// "Chặng tiếp theo ra mắt ngày X" — hiện ở màn kết quả của BÀI MỚI CUỐI CÙNG đang có (server: `next_stage` trong danh sách bài,
/// ngày lấy từ cấu hình server SITUATION_NEXT_STAGE_LAUNCH_DATE). Người học không gặp ngõ cụt: gợi ý ôn tập hoặc học tiếp bài cũ.

/// 'YYYY-MM-DD' -> 'dd/mm/yyyy'; null / sai định dạng -> null.
String? nextStageDateLabel(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

class NextStageCard extends StatelessWidget {
  final Map<String, dynamic> nextStage;
  const NextStageCard({super.key, required this.nextStage});

  @override
  Widget build(BuildContext context) {
    final stage = nextStage['stage'];
    final date = nextStageDateLabel(nextStage['launch_date'] as String?);
    return Container(
      key: const Key('next_stage_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🚀 Bạn đã học hết các bài mới hiện có!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          date != null ? 'Chặng $stage ra mắt ngày $date.' : 'Chặng $stage đang được soạn và sẽ ra mắt sớm.',
          key: const Key('next_stage_date'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 10),
        const Text('Trong lúc chờ, bạn có thể:', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('• Ôn lại từ đã học ở mục Học hôm nay.'),
        const Text('• Học tiếp các bài của giáo trình cũ trong danh sách (đã mở sẵn).'),
      ]),
    );
  }
}
