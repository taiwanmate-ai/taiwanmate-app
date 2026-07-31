import 'trend_language_models.dart';

const List<TrendPhrase> enTrendPack = [
  TrendPhrase(
    id: 'en_correction_01',
    phrase: 'Hmm not quite. Try again?',
    locale: 'en-global',
    category: 'gentle_correction',
    freshness: TrendFreshness.active,
    offensiveness: 0,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'en_praise_01',
    phrase: "Okay that's actually solid.",
    locale: 'en-global',
    category: 'praise',
    freshness: TrendFreshness.fresh,
    offensiveness: 0,
    lastVerifiedAt: '2026-01-01',
  ),
  TrendPhrase(
    id: 'en_tease_01',
    phrase: 'Bro really tried to skip that 💀',
    locale: 'en-global',
    category: 'playful_tease',
    freshness: TrendFreshness.active,
    offensiveness: 1,
    lastVerifiedAt: '2026-01-01',
  ),
];