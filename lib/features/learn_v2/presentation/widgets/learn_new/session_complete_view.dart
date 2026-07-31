import 'package:flutter/material.dart';

class SessionCompleteView extends StatelessWidget {
  final int totalLearned;
  final int savedCount;
  final VoidCallback onBack;

  const SessionCompleteView({
    super.key,
    required this.totalLearned,
    required this.savedCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Hoàn thành!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Text('Hôm nay bạn vừa học:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('$totalLearned từ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  const Text('Đã lưu:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('$savedCount từ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onBack, child: const Text('Quay lại')),
            ),
          ],
        ),
      ),
    );
  }
}