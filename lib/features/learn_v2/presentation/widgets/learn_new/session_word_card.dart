import 'package:flutter/material.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';

class SessionWordCard extends StatefulWidget {
  final VocabularyWord word;
  final String language;
  final bool isSaved;
  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onNext;

  const SessionWordCard({
    super.key,
    required this.word,
    required this.language,
    required this.isSaved,
    required this.isSaving,
    required this.onSave,
    required this.onNext,
  });

  @override
  State<SessionWordCard> createState() => _SessionWordCardState();
}

class _SessionWordCardState extends State<SessionWordCard> {
  // Moi tu (key doi theo vocabularyId o man cha) se tao lai State moi,
  // nen _isRevealed tu dong reset ve false khi sang tu tiep theo.
  bool _isRevealed = false;

  @override
  Widget build(BuildContext context) {
    final displayWord = widget.word.displayWord(widget.language);
    final pronunciation = widget.word.displayPronunciation(widget.language);
    final example = widget.word.displayExample(widget.language);
    final hasAudio = (widget.word.audioUrl ?? '').isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayWord.isNotEmpty ? displayWord : '(không có dữ liệu)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'NotoSansTC',
                            ),
                          ),
                        ),
                        if (hasAudio) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.volume_up_rounded, color: Colors.grey.shade500, size: 22),
                        ],
                      ],
                    ),
                    if (pronunciation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        pronunciation,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (!_isRevealed)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isRevealed = true),
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Hiện nghĩa'),
                      )
                    else ...[
                      Text(
                        widget.word.vietnamese,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      if (example.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            example,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontFamily: 'NotoSansTC'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.isSaved || widget.isSaving ? null : widget.onSave,
                  icon: widget.isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(widget.isSaved ? Icons.check_rounded : Icons.bookmark_add_outlined),
                  label: Text(widget.isSaved ? 'Đã lưu' : 'Lưu'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: widget.onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Tiếp theo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}