/// ChatModeSelectionScreen — Lop 6 (2026-08-15): man hinh chon che do khi
/// bam vao tab "AI Chat" tu thanh dieu huong duoi cung — thay vi vao
/// thang ChatScreen nhu truoc, gio cho chon giua "Chat" (nhan tin, y
/// nguyen ChatScreen cu) va "Trò chuyện trực tiếp" (Voice, man hinh moi
/// VoiceChatScreen — Phase 2 Voice Pipeline).
library;

import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'voice_chat_screen.dart';

class ChatModeSelectionScreen extends StatelessWidget {
  const ChatModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bạn muốn trò chuyện với AI theo cách nào?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),
              _ModeCard(
                icon: Icons.chat_bubble_outline,
                title: 'Chat',
                subtitle: 'Nhắn tin văn bản với AI Companion',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
                },
              ),
              const SizedBox(height: 16),
              _ModeCard(
                icon: Icons.mic,
                title: 'Trò chuyện trực tiếp',
                subtitle: 'Nói chuyện bằng giọng nói, AI trả lời bằng giọng nói (thử nghiệm)',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceChatScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(radius: 26, backgroundColor: color, child: Icon(icon, color: Colors.white, size: 26)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
