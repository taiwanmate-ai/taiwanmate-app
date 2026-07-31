import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/trend_language_models.dart';
import 'package:chinesemate/features/chat/engines/trend_language_engine.dart';
import 'package:chinesemate/features/chat/engines/trend_language_source.dart';

class _FakeSource implements TrendLanguageSource {
  final List<TrendPhrase> pack;
  const _FakeSource(this.pack);
  @override
  List<TrendPhrase> loadPack(String locale) => pack;
}

const _baseSignals = CurrentTurnStyleSignals(
  userUsesInformalPronouns: false,
  userUsesProfanity: false,
  userUsesSlang: false,
  userIsFormal: false,
);

TrendContext _ctx({
  TrendSituation situation = TrendSituation.casualChitchat,
  EmotionalTier emotionalTier = EmotionalTier.normal,
  TrendRelationship relationship = TrendRelationship.friend,
  TrendAudience audience = TrendAudience.student,
  CurrentTurnStyleSignals styleSignals = _baseSignals,
  Set<String> recentlySuggestedPhraseIds = const {},
}) =>
    TrendContext(
      situation: situation,
      emotionalTier: emotionalTier,
      relationship: relationship,
      audience: audience,
      styleSignals: styleSignals,
      recentlySuggestedPhraseIds: recentlySuggestedPhraseIds,
    );

const _p1 = TrendPhrase(
    id: 'p1',
    phrase: 'a',
    locale: 'zh-TW',
    category: 'x',
    freshness: TrendFreshness.active,
    offensiveness: 0,
    lastVerifiedAt: '2026-01-01');

void main() {
  group('TrendLanguageEngine', () {
    test('distressedSensitive -> null', () {
      final engine = TrendLanguageEngine(source: _FakeSource([_p1]));
      final r = engine.select(
          locale: 'zh-TW',
          context: _ctx(emotionalTier: EmotionalTier.distressedSensitive));
      expect(r, isNull);
    });

    test('archived khong bao gio duoc chon', () {
      const p = TrendPhrase(
          id: 'a1',
          phrase: 'x',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.archived,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([p]));
      expect(engine.select(locale: 'zh-TW', context: _ctx()), isNull);
    });

    test('offensiveness vuot nguong khong duoc chon', () {
      const p = TrendPhrase(
          id: 'o1',
          phrase: 'x',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 2,
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([p]));
      final r = engine.select(
          locale: 'zh-TW',
          context: _ctx(relationship: TrendRelationship.stranger));
      expect(r, isNull);
    });

    test('locale chi lay dung pack', () {
      final engine = TrendLanguageEngine(source: _FakeSource([_p1]));
      final r = engine.select(locale: 'en-global', context: _ctx());
      // _FakeSource tra ve cung list bat ke locale, nen test nay dung LocalTrendLanguageSource that
      final realEngine = const TrendLanguageEngine();
      final rEn = realEngine.select(locale: 'en-global', context: _ctx());
      expect(rEn == null || rEn.locale == 'en-global', isTrue);
      expect(r,
          isNotNull); // fake source khong loc theo locale, chi de kiem tra co goi duoc
    });

    test('allowedContext khong khop thi khong chon', () {
      const p = TrendPhrase(
          id: 'c1',
          phrase: 'x',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 0,
          allowedContexts: {TrendSituation.seriousExplanation},
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([p]));
      final r = engine.select(
          locale: 'zh-TW',
          context: _ctx(situation: TrendSituation.casualChitchat));
      expect(r, isNull);
    });

    test('phrase gan day khong duoc lap', () {
      final engine = TrendLanguageEngine(source: _FakeSource([_p1]));
      final r = engine.select(
          locale: 'zh-TW', context: _ctx(recentlySuggestedPhraseIds: {'p1'}));
      expect(r, isNull);
    });

    test('formal user message khong chon phrase tuc', () {
      const p = TrendPhrase(
          id: 'f1',
          phrase: 'x',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 1,
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([p]));
      final r = engine.select(
        locale: 'zh-TW',
        context: _ctx(
            styleSignals: const CurrentTurnStyleSignals(
                userUsesInformalPronouns: false,
                userUsesProfanity: false,
                userUsesSlang: false,
                userIsFormal: true)),
      );
      expect(r, isNull);
    });

    test('seeded random cho ket qua on dinh', () {
      const pA = TrendPhrase(
          id: 'sA',
          phrase: 'a',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.fresh,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      const pB = TrendPhrase(
          id: 'sB',
          phrase: 'b',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.fresh,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([pA, pB]));
      final r1 = engine.select(locale: 'zh-TW', context: _ctx(), seed: 1);
      final r2 = engine.select(locale: 'zh-TW', context: _ctx(), seed: 1);
      expect(r1?.id, r2?.id);
    });

    test('kid/elder ap dung gioi han dung', () {
      const p = TrendPhrase(
          id: 'k1',
          phrase: 'x',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 1,
          lastVerifiedAt: '2026-01-01');
      final engine = TrendLanguageEngine(source: _FakeSource([p]));
      expect(
          engine.select(
              locale: 'zh-TW', context: _ctx(audience: TrendAudience.kid)),
          isNull);
      expect(
          engine.select(
              locale: 'zh-TW', context: _ctx(audience: TrendAudience.elder)),
          isNull);
    });

    test('fresh uu tien hon active', () {
      const pFresh = TrendPhrase(
          id: 'fr1',
          phrase: 'a',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.fresh,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      const pActive = TrendPhrase(
          id: 'ac1',
          phrase: 'b',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      final engine =
          TrendLanguageEngine(source: _FakeSource([pFresh, pActive]));
      final r = engine.select(locale: 'zh-TW', context: _ctx());
      expect(r?.id, 'fr1');
    });

    test('active uu tien hon fading', () {
      const pActive = TrendPhrase(
          id: 'ac2',
          phrase: 'a',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      const pFading = TrendPhrase(
          id: 'fd2',
          phrase: 'b',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.fading,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      final engine =
          TrendLanguageEngine(source: _FakeSource([pActive, pFading]));
      final r = engine.select(locale: 'zh-TW', context: _ctx());
      expect(r?.id, 'ac2');
    });

    test('fresh vua duoc goi y thi active duoc chon thay the', () {
      const pFresh = TrendPhrase(
          id: 'fr3',
          phrase: 'a',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.fresh,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      const pActive = TrendPhrase(
          id: 'ac3',
          phrase: 'b',
          locale: 'zh-TW',
          category: 'c',
          freshness: TrendFreshness.active,
          offensiveness: 0,
          lastVerifiedAt: '2026-01-01');
      final engine =
          TrendLanguageEngine(source: _FakeSource([pFresh, pActive]));
      final r = engine.select(
          locale: 'zh-TW', context: _ctx(recentlySuggestedPhraseIds: {'fr3'}));
      expect(r?.id, 'ac3');
    });
  });
}
