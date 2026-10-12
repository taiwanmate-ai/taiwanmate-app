import 'package:flutter/material.dart';
import 'package:chinesemate/features/chat/engines/voice_stt_language.dart';

/// Hang chon ngon ngu nhan dien giong noi: [Tự động | 中文 | Tiếng Việt (| English)] — 1 cham, gon (chip nho, tu xuong dong tren man hep).
class VoiceLanguageSelector extends StatelessWidget {
  const VoiceLanguageSelector({super.key, required this.options, required this.selected, required this.onChanged});

  final List<VoiceSttLanguage> options;
  final VoiceSttLanguage selected;
  final ValueChanged<VoiceSttLanguage> onChanged;

  static Key keyFor(VoiceSttLanguage l) => ValueKey('voice_lang_${l.wire}');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final l in options)
          ChoiceChip(
            key: keyFor(l),
            label: Text(l.label, style: const TextStyle(fontSize: 13)),
            selected: l == selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selectedColor: scheme.primary.withValues(alpha: 0.22),
            onSelected: (_) => onChanged(l),
          ),
      ],
    );
  }
}
