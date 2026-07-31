import 'trend_language_models.dart';
import 'trend_language_pack_vi.dart';
import 'trend_language_pack_zh.dart';
import 'trend_language_pack_en.dart';

abstract class TrendLanguageSource {
  List<TrendPhrase> loadPack(String locale);
}

/// Nguon cuc bo — pack curated nho, tinh. De danh cho remote source sau
/// nay (chua co trong Patch 1) khong doi interface goi tu ben ngoai.
class LocalTrendLanguageSource implements TrendLanguageSource {
  const LocalTrendLanguageSource();

  @override
  List<TrendPhrase> loadPack(String locale) {
    switch (locale) {
      case 'vi-VN':
        return viTrendPack;
      case 'zh-TW':
        return zhTrendPack;
      case 'en-global':
        return enTrendPack;
      default:
        return const [];
    }
  }
}