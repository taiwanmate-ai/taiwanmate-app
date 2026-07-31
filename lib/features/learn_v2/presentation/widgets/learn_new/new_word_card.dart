import 'package:flutter/material.dart';
import 'package:chinesemate/features/learn_v2/domain/models/vocabulary_word.dart';

class NewWordCard extends StatelessWidget {
  final VocabularyWord word;
  final String language;
  final VoidCallback? onTap;

  const NewWordCard({super.key, required this.word, required this.language, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayWord = word.displayWord(language);
    final pronunciation = word.displayPronunciation(language);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayWord.isNotEmpty ? displayWord : '(không có dữ liệu)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'NotoSansTC',
                      ),
                    ),
                    if (pronunciation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pronunciation,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      word.vietnamese,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}