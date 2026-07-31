/// Model go kieu ro rang cho 1 tu vung — thay the Map<String, dynamic>
/// dang dung trong learn_screen.dart cu. Map truc tiep tu response JSON
/// that cua GET /api/v1/vocabulary/daily (API HIEN CO, khong doi backend).
class VocabularyWord {
  final String vocabularyId;
  final String? chinese;
  final String? english;
  final String? pinyin;
  final String? ipa;
  final String vietnamese;
  final String? exampleZh;
  final String? exampleEn;
  final bool isReview;
  final int srsLevel;
  final String? tocflLevel;
  final String? cefrLevel;
  final String? audioUrl;

  const VocabularyWord({
    required this.vocabularyId,
    this.chinese,
    this.english,
    this.pinyin,
    this.ipa,
    required this.vietnamese,
    this.exampleZh,
    this.exampleEn,
    required this.isReview,
    required this.srsLevel,
    this.tocflLevel,
    this.cefrLevel,
    this.audioUrl,
  });

  factory VocabularyWord.fromJson(Map<String, dynamic> json) {
    return VocabularyWord(
      vocabularyId: (json['vocabulary_id'] ?? json['id'] ?? '').toString(),
      chinese: json['chinese'] as String?,
      english: json['english'] as String?,
      pinyin: json['pinyin'] as String?,
      ipa: json['ipa'] as String?,
      vietnamese: (json['vietnamese'] ?? '') as String,
      exampleZh: json['example_zh'] as String?,
      exampleEn: json['example_en'] as String?,
      isReview: json['is_review'] == true,
      srsLevel: (json['srs_level'] as num?)?.toInt() ?? 0,
      tocflLevel: json['tocfl_level'] as String?,
      cefrLevel: json['cefr_level'] as String?,
      audioUrl: json['audio_url'] as String?,
    );
  }

  /// Chu/tu hien thi chinh, tuy ngon ngu — thay the ham _getWord() cu
  String displayWord(String language) {
    if (language == 'en') return english ?? '';
    return chinese ?? '';
  }

  /// Phien am hien thi, tuy ngon ngu — thay the ham _getPinyin() cu
  String displayPronunciation(String language) {
    if (language == 'en') return ipa ?? '';
    return pinyin ?? '';
  }

  /// Vi du hien thi, tuy ngon ngu — thay the ham _getExample() cu
  String displayExample(String language) {
    if (language == 'en') return exampleEn ?? '';
    return exampleZh ?? '';
  }
}