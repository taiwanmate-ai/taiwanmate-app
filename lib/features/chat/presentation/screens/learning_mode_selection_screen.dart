/// LearningModeSelectionScreen — 2026-08-20.
///
/// "Bạn muốn học như thế nào?" — 4 lựa chọn zh_vi/zh_only/en_vi/en_only,
/// dùng CHUNG cho cả Chat và Voice (ghi qua learningModeProvider, xem
/// docstring learning_mode_provider.dart). 2 chế độ dùng:
///   - isFirstTime=true (từ ChatEntryGateScreen, lần đầu bấm "AI Chat"
///     chưa từng chọn) — sau khi chọn, THAY THẾ (pushReplacement) bằng
///     ChatModeSelectionScreen (Chat/Voice), không cho quay lại màn hình
///     chọn ngôn ngữ bằng nút back.
///   - isFirstTime=false (từ icon cài đặt trong ChatScreen/VoiceChatScreen
///     — đổi lựa chọn bất cứ lúc nào) — sau khi chọn, chỉ pop() quay lại
///     màn hình đã mở nó.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/core/providers/learning_mode_provider.dart';
import 'chat_mode_selection_screen.dart';

class LearningModeSelectionScreen extends ConsumerWidget {
  const LearningModeSelectionScreen({super.key, required this.isFirstTime});

  final bool isFirstTime;

  Future<void> _select(BuildContext context, WidgetRef ref, String mode) async {
    await ref.read(learningModeProvider.notifier).setMode(mode);
    if (!context.mounted) return;
    if (isFirstTime) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatModeSelectionScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(learningModeProvider);
    return Scaffold(
      appBar: isFirstTime ? null : AppBar(title: const Text('Chế độ học')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bạn muốn học như thế nào?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Áp dụng cho cả Chat và Trò chuyện trực tiếp — có thể đổi lại bất cứ lúc nào.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _ModeOption(
                emoji: '🇹🇼',
                title: 'Trung + Việt',
                subtitle: 'AI trả lời tiếng Trung, kèm dịch tiếng Việt',
                selected: currentMode == 'zh_vi',
                onTap: () => _select(context, ref, 'zh_vi'),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                emoji: '中',
                title: 'Chỉ tiếng Trung',
                subtitle: 'AI trả lời hoàn toàn bằng tiếng Trung',
                selected: currentMode == 'zh_only',
                onTap: () => _select(context, ref, 'zh_only'),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                emoji: '🇺🇸',
                title: 'Anh + Việt',
                subtitle: 'AI trả lời tiếng Anh, kèm dịch tiếng Việt',
                selected: currentMode == 'en_vi',
                onTap: () => _select(context, ref, 'en_vi'),
              ),
              const SizedBox(height: 12),
              _ModeOption(
                emoji: '🔤',
                title: 'Chỉ tiếng Anh',
                subtitle: 'AI trả lời hoàn toàn bằng tiếng Anh',
                selected: currentMode == 'en_only',
                onTap: () => _select(context, ref, 'en_only'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.indigo.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.indigo : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: Colors.indigo),
            ],
          ),
        ),
      ),
    );
  }
}
