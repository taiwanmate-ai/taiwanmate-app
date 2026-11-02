import 'package:flutter/material.dart';

/// "Chặng tiếp theo ra mắt ngày X" — hiện ở màn kết quả của BÀI MỚI CUỐI CÙNG đang có (server: `next_stage` trong danh sách bài,
/// ngày lấy từ cấu hình server). Server layout=v2: `next` = "level" (đã hết chặng của cấp -> "A2 sắp ra mắt", ngày SITUATION_A2_LAUNCH_DATE)
/// hoặc "stage" (chặng kế tiếp, SITUATION_NEXT_STAGE_LAUNCH_DATE). Người học không gặp ngõ cụt: gợi ý ôn tập — KHÔNG đẩy sang bài giáo trình cũ (CTO 31/10).

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
    final stage = nextStage['stage_no'] ?? nextStage['stage']; // server: so chang trong cap (A2 chang 7 -> 1)
    final nextLevel = nextStage['next'] == 'level' ? (nextStage['next_level'] as String?) : null;
    final date = nextStageDateLabel(nextStage['launch_date'] as String?);
    final upcoming = nextLevel != null ? 'Cấp $nextLevel' : 'Chặng $stage';
    return Container(
      key: const Key('next_stage_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(nextLevel != null ? '🎉 Bạn đã học hết lộ trình cấp này!' : '🚀 Bạn đã học hết các bài mới hiện có!',
            key: const Key('next_stage_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          date != null ? '$upcoming ra mắt ngày $date.' : (nextLevel != null ? '$upcoming sắp ra mắt.' : '$upcoming đang được soạn và sẽ ra mắt sớm.'),
          key: const Key('next_stage_date'),
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 10),
        const Text('Trong lúc chờ, bạn có thể:', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('• Ôn tập: ôn lại từ đã học ở mục Học hôm nay.', key: Key('next_stage_review')),
        const Text('• Mở lại bài ôn tập cuối mỗi chặng để luyện nói và dịch.'),
      ]),
    );
  }
}
