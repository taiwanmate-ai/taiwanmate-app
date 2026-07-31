enum TrendFreshness { fresh, active, fading, archived }

enum TrendSituation {
  celebratingCorrectAnswer,
  teasingMistake,
  casualChitchat,
  encouragement,
  sensitiveTopic,
  seriousExplanation,
}

enum TrendRelationship { stranger, familiar, friend, bestFriend }

enum TrendAudience { kid, student, adult, elder }

enum EmotionalTier { normal, playful, frustrated, sad, distressedSensitive }

class TrendPhrase {
  final String id;
  final String phrase;
  final String locale;
  final String? region;
  final String category;
  final TrendFreshness freshness;
  final int offensiveness;
  final Set<TrendSituation> allowedContexts;
  final Set<TrendSituation> blockedContexts;
  final String lastVerifiedAt;

  const TrendPhrase({
    required this.id,
    required this.phrase,
    required this.locale,
    this.region,
    required this.category,
    required this.freshness,
    required this.offensiveness,
    this.allowedContexts = const {},
    this.blockedContexts = const {},
    required this.lastVerifiedAt,
  });
}

class CurrentTurnStyleSignals {
  final bool userUsesInformalPronouns;
  final bool userUsesProfanity;
  final bool userUsesSlang;
  final bool userIsFormal;

  const CurrentTurnStyleSignals({
    required this.userUsesInformalPronouns,
    required this.userUsesProfanity,
    required this.userUsesSlang,
    required this.userIsFormal,
  });
}

class TrendContext {
  final TrendSituation situation;
  final EmotionalTier emotionalTier;
  final TrendRelationship relationship;
  final TrendAudience audience;
  final CurrentTurnStyleSignals styleSignals;
  final Set<String> recentlySuggestedPhraseIds;

  const TrendContext({
    required this.situation,
    required this.emotionalTier,
    required this.relationship,
    required this.audience,
    required this.styleSignals,
    this.recentlySuggestedPhraseIds = const {},
  });
}

/// Phat hien tin hieu phong cach TU CAU HIEN TAI — moi locale co pattern
/// rieng. Khong dung "you"/"你/妳" lam bang chung suong sa.
CurrentTurnStyleSignals detectStyle({required String text, required String locale}) {
  final lower = text.toLowerCase();
  switch (locale) {
    case 'en-global':
      const informal = ['bro', 'dude', 'bruh', ' u ', 'lol', 'lmao'];
      const profanity = ['fuck', 'shit', 'damn'];
      const slang = ['lowkey', 'no cap', 'fr fr', 'bet', 'vibe'];
      const formal = ['could you please', 'i would like', 'good morning'];
      return CurrentTurnStyleSignals(
        userUsesInformalPronouns: informal.any((w) => lower.contains(w)),
        userUsesProfanity: profanity.any((w) => lower.contains(w)),
        userUsesSlang: slang.any((w) => lower.contains(w)),
        userIsFormal: formal.any((w) => lower.contains(w)),
      );
    case 'zh-TW':
      const informal = ['欸', '啦', '喔', '靠', '笑死', '太扯了'];
      const profanity = ['靠北', '幹', '媽的'];
      const slang = ['笑死', '太扯', '87'];
      const formal = ['您好', '請問', '謝謝您'];
      return CurrentTurnStyleSignals(
        userUsesInformalPronouns: informal.any((w) => text.contains(w)),
        userUsesProfanity: profanity.any((w) => text.contains(w)),
        userUsesSlang: slang.any((w) => text.contains(w)),
        userIsFormal: formal.any((w) => text.contains(w)),
      );
    default: // vi-VN
      const informal = ['mày', 'tao', 'bro', 'ông', 'fen'];
      const profanity = ['đm', 'vcl', 'đéo'];
      const slang = ['gì z', 'z ta', 'chill', 'trend'];
      const formal = ['xin chào', 'quý khách', 'dạ thưa'];
      return CurrentTurnStyleSignals(
        userUsesInformalPronouns: informal.any((w) => lower.contains(w)),
        userUsesProfanity: profanity.any((w) => lower.contains(w)),
        userUsesSlang: slang.any((w) => lower.contains(w)),
        userIsFormal: formal.any((w) => lower.contains(w)),
      );
  }
}

/// Phan loai 5 muc cam xuc TU CAU HIEN TAI, hoan toan thuan tuy, khong luu.
EmotionalTier classifyEmotionalTier(String text) {
  final lower = text.toLowerCase();
  const distress = ['tự tử', 'muốn chết', 'không muốn sống', 'kết thúc tất cả', 'suicide', 'kill myself', 'end my life', '自殺', '想死', '不想活'];
  const sad = ['buồn', 'nhớ nhà', 'khóc', 'cô đơn', 'chán nản', 'sad', 'lonely', 'miss home', 'depressed', '難過', '想家', '孤單'];
  const frustrated = ['chán', 'khó quá', 'bỏ cuộc', 'mệt', 'không hiểu', 'thôi', 'chịu rồi', 'give up', 'too hard', 'tired', '放棄', '好難', '不懂'];
  const playful = ['haha', 'lol', 'hihi', 'buồn cười', 'funny', '好笑', '笑死'];

  if (distress.any((w) => lower.contains(w))) return EmotionalTier.distressedSensitive;
  if (sad.any((w) => lower.contains(w))) return EmotionalTier.sad;
  if (frustrated.any((w) => lower.contains(w))) return EmotionalTier.frustrated;
  if (playful.any((w) => lower.contains(w))) return EmotionalTier.playful;
  return EmotionalTier.normal;
}