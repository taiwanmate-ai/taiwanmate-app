import 'trend_language_models.dart';

const List<TrendPhrase> zhTrendPack = [
  TrendPhrase(
    id: 'zh_correction_01',
    phrase: '欸，不對喔。再想一下。',
    locale: 'zh-TW',
    category: 'gentle_correction',
    freshness: TrendFreshness.active,
    offensiveness: 0,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'zh_tease_01',
    phrase: '又想混過去喔？來，再一次。',
    locale: 'zh-TW',
    category: 'playful_tease',
    freshness: TrendFreshness.active,
    offensiveness: 1,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'zh_praise_01',
    phrase: '可以喔，這次有進步。',
    locale: 'zh-TW',
    category: 'praise',
    freshness: TrendFreshness.fresh,
    offensiveness: 0,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'zh_strong_01',
    phrase: '幹！你怎麼這麼厲害！',
    locale: 'zh-TW',
    category: 'strong_praise',
    freshness: TrendFreshness.active,
    offensiveness: 2,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'zh_strong_02',
    phrase: '你在開玩笑嗎？！',
    locale: 'zh-TW',
    category: 'strong_disbelief',
    freshness: TrendFreshness.active,
    offensiveness: 2,
    lastVerifiedAt: '2026-01-01',
  ),
];