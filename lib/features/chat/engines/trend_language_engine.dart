import 'trend_language_models.dart';
import 'trend_language_source.dart';

class TrendLanguageEngine {
  const TrendLanguageEngine({this.source = const LocalTrendLanguageSource()});
  final TrendLanguageSource source;

  int _freshnessScore(TrendFreshness f) {
    switch (f) {
      case TrendFreshness.fresh:
        return 3;
      case TrendFreshness.active:
        return 2;
      case TrendFreshness.fading:
        return 1;
      case TrendFreshness.archived:
        return 0;
    }
  }

  /// Tra ve -1 neu tuyet doi khong duoc dung trend (an toan).
  int _maxOffensivenessFor(TrendContext context) {
    if (context.emotionalTier == EmotionalTier.distressedSensitive) return -1;
    if (context.emotionalTier == EmotionalTier.sad) return -1;

    if (context.audience == TrendAudience.kid) return 0;

    int ceiling = context.audience == TrendAudience.elder ? 0 : 1;

    if (context.relationship == TrendRelationship.stranger ||
        context.relationship == TrendRelationship.familiar) {
      if (ceiling > 0) ceiling = 0;
    }

    if (context.styleSignals.userIsFormal) {
      ceiling = 0;
    } else if (context.styleSignals.userUsesProfanity &&
        (context.relationship == TrendRelationship.friend ||
            context.relationship == TrendRelationship.bestFriend)) {
      ceiling = 2;
    }

    if (context.emotionalTier == EmotionalTier.frustrated && ceiling > 1) {
      ceiling = 1;
    }

    return ceiling;
  }

  TrendPhrase? select({
    required String locale,
    required TrendContext context,
    int seed = 0,
  }) {
    final maxOffensiveness = _maxOffensivenessFor(context);
    if (maxOffensiveness < 0) return null;

    final pack = source.loadPack(locale);
    final eligible = pack.where((p) {
      if (p.freshness == TrendFreshness.archived) return false;
      if (p.offensiveness > maxOffensiveness) return false;
      if (context.recentlySuggestedPhraseIds.contains(p.id)) return false;
      if (p.blockedContexts.contains(context.situation)) return false;
      if (p.allowedContexts.isNotEmpty && !p.allowedContexts.contains(context.situation)) return false;
      return true;
    }).toList();

    if (eligible.isEmpty) return null;

    eligible.sort((a, b) => _freshnessScore(b.freshness).compareTo(_freshnessScore(a.freshness)));
    final topScore = _freshnessScore(eligible.first.freshness);
    final topTier = eligible.where((p) => _freshnessScore(p.freshness) == topScore).toList();

    if (topTier.length == 1) return topTier.first;
    return topTier[seed % topTier.length];
  }
}