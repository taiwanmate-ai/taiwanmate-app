import 'package:flutter/material.dart';

/// Thanh hien cau user VUA NOI ngay khi server nhan dien xong (truoc ca khi AI tra loi) — "🎤 Mình nghe: …" — kem nut "Nói lại"
/// (2026-10-12, Dot 1 muc 3). [onRedo] = null thi an nut (luot go chu / server cu khong gui turn_id). Widget cong khai de test rieng.
class VoiceTranscriptBar extends StatelessWidget {
  const VoiceTranscriptBar({super.key, required this.text, this.onRedo});

  final String text;
  final VoidCallback? onRedo;

  static const redoButtonKey = ValueKey('voice_redo_button');
  static const textKey = ValueKey('voice_transcript_text');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.16),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '🎤 Mình nghe: $text',
              key: textKey,
              style: TextStyle(color: scheme.onSurface, fontSize: 15, height: 1.35),
            ),
          ),
          if (onRedo != null)
            TextButton.icon(
              key: redoButtonKey,
              onPressed: onRedo,
              icon: const Icon(Icons.replay, size: 16),
              label: const Text('Nói lại'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
              ),
            ),
        ],
      ),
    );
  }
}
