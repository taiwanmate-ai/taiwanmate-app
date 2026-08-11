import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';
import 'package:chinesemate/features/chat/engines/trend_language_models.dart';
import 'package:chinesemate/features/chat/engines/trend_language_engine.dart';
import 'package:chinesemate/features/chat/engines/trend_language_source.dart';

class _FakeSource implements TrendLanguageSource {
  final List<TrendPhrase> pack;
  const _FakeSource(this.pack);
  @override
  List<TrendPhrase> loadPack(String locale) => pack;
}

// offensiveness=1 — theo dung logic that cua TrendLanguageEngine._maxOffensivenessFor:
// bi CAM voi relationship stranger/acquaintance (ceiling ep ve 0), nhung
// duoc PHEP voi friend/bestfriend (ceiling = 1 cho audience khong phai elder).
const _mildRoastPhrase = TrendPhrase(
  id: 'mild_roast_1',
  phrase: 'test roast phrase',
  locale: 'zh-TW',
  category: 'test',
  freshness: TrendFreshness.fresh,
  offensiveness: 1,
  lastVerifiedAt: '2026-01-01',
);

// Cau dac trung rieng cho tung muc intimacy cua userType=student — dung de
// xac nhan dung nguong relationship level nao dang duoc chon, khong doan.
const _labelStranger = 'Mới quen: thân thiện "bạn/mình"';
const _labelAcquaintance = 'Quen sơ: thân thiện hơn, bắt đầu thoải mái dùng "bạn/mình"';
const _labelFriend = 'Đã quen: casual "ê mày", bắt đầu trêu';
const _labelBestfriend = 'Thân rồi: nói chuyện như bạn thân thực sự';

({String prompt, String? usedTrendPhraseId}) _buildResult({
  required String userType,
  required Map<String, dynamic> aiMemory,
  int sessionMessages = 1,
  String currentUserText = 'Hôm nay tao học từ mới nhé',
  CompanionPersonalityEngine engine = const CompanionPersonalityEngine(),
}) {
  return engine.buildSystemPromptV2(
    learningMode: 'zh_vi',
    userType: userType,
    sessionMessages: sessionMessages,
    mistakes: const [],
    userFrustrated: false,
    aiMemory: aiMemory,
    nextAction: null,
    aiName: 'Yuki',
    aiGender: 'female',
    isVip: false,
    now: DateTime(2026, 8, 10, 15, 0),
    currentUserText: currentUserText,
    recentlySuggestedTrendPhraseIds: const {},
  );
}

String _buildPrompt({
  required String userType,
  required Map<String, dynamic> aiMemory,
  int sessionMessages = 1,
  String currentUserText = 'Hôm nay tao học từ mới nhé',
}) {
  return _buildResult(
    userType: userType,
    aiMemory: aiMemory,
    sessionMessages: sessionMessages,
    currentUserText: currentUserText,
  ).prompt;
}

void main() {
  group('CompanionPersonalityEngine — relationship level thong nhat (uu tien 2)', () {
    test('stranger (aiMemory rong) -> intimacy "Mới quen"', () {
      final prompt = _buildPrompt(userType: 'student', aiMemory: const {});
      expect(prompt.contains(_labelStranger), isTrue);
      expect(prompt.contains(_labelAcquaintance), isFalse);
      expect(prompt.contains(_labelFriend), isFalse);
      expect(prompt.contains(_labelBestfriend), isFalse);
    });

    test('acquaintance -> intimacy "Quen sơ"', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'acquaintance'},
      );
      expect(prompt.contains(_labelAcquaintance), isTrue);
      expect(prompt.contains(_labelStranger), isFalse);
    });

    test('friend -> intimacy "Đã quen"', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
      );
      expect(prompt.contains(_labelFriend), isTrue);
      expect(prompt.contains(_labelAcquaintance), isFalse);
    });

    test('bestfriend -> intimacy "Thân rồi"', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'bestfriend'},
      );
      expect(prompt.contains(_labelBestfriend), isTrue);
      expect(prompt.contains(_labelFriend), isFalse);
    });

    test('gia tri relationship KHONG HOP LE trong aiMemory -> fallback ve stranger, khong hien nguyen van rac', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'gia_tri_linh_tinh_khong_ton_tai'},
      );
      expect(prompt.contains(_labelStranger), isTrue,
          reason: 'Gia tri khong hop le phai fallback ve stranger, khong duoc coi la 1 muc khac');
      expect(prompt.contains('gia_tri_linh_tinh_khong_ton_tai'), isFalse);
    });

    test('KHONG con phu thuoc sessionMessages nua — sessionMessages=100 nhung aiMemory rong (stranger) van la "Mới quen"', () {
      // Bug da sua: TRUOC DAY intimacy tinh tu sessionMessages (session
      // cuc bo), khong phai lich su that. Test nay xac nhan dung aiMemory
      // lam nguon that, KHONG con bi sessionMessages chi phoi nua.
      final prompt = _buildPrompt(userType: 'student', aiMemory: const {}, sessionMessages: 100);
      expect(prompt.contains(_labelStranger), isTrue,
          reason: 'aiMemory rong (stranger That su) phai la "Moi quen" du sessionMessages lon');
      expect(prompt.contains(_labelBestfriend), isFalse);
    });

    test('sessionMessages=1 (moi vao phien) nhung aiMemory da la bestfriend -> van hien "Thân rồi" (khong reset khi mo lai man hinh)', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'bestfriend'},
        sessionMessages: 1,
      );
      expect(prompt.contains(_labelBestfriend), isTrue,
          reason: 'Relationship level phai persist qua aiMemory, KHONG reset ve stranger khi mo lai man hinh (sessionMessages=1)');
    });

    test('USER MEMORY hien thi dung relationshipLevel DA CHUAN HOA, khong doc tho tu aiMemory', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        aiMemory: const {'relationship': 'FRIEND'}, // chu hoa — phai duoc chuan hoa
      );
      expect(prompt.contains('Mức độ thân thiết: friend'), isTrue,
          reason: 'memoryNote phai hien gia tri DA chuan hoa (lowercase), khong hien "FRIEND" tho');
    });

    test('MOI userType deu dung CHUNG 1 nguon relationship (khong con rieng cho student) — adult', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        aiMemory: const {'relationship': 'bestfriend'},
      );
      expect(prompt.contains('Mức độ thân thiết: bestfriend'), isTrue);
    });

    test('MOI userType deu dung CHUNG 1 nguon relationship — kid', () {
      final prompt = _buildPrompt(
        userType: 'kid',
        aiMemory: const {'relationship': 'friend'},
      );
      expect(prompt.contains('Mức độ thân thiết: friend'), isTrue);
    });

    test('MOI userType deu dung CHUNG 1 nguon relationship — elder', () {
      final prompt = _buildPrompt(
        userType: 'elder',
        aiMemory: const {'relationship': 'acquaintance'},
      );
      expect(prompt.contains('Mức độ thân thiết: acquaintance'), isTrue);
    });

    // ─────────────────────────────────────────────────────────
    // Xac nhan RANG BUOC #5: khong pha vo tich hop trendEngine hien tai —
    // relationship level tu aiMemory (nguon MOI, thong nhat) van truyen
    // dung vao TrendContext.relationship (kieu TrendRelationship, KHONG
    // doi) va anh huong dung logic that cua TrendLanguageEngine.
    // ─────────────────────────────────────────────────────────
    test('trendEngine tich hop: relationship=stranger -> phrase co offensiveness=1 BI LOAI (ceiling ep ve 0)', () {
      final engine = CompanionPersonalityEngine(
        trendEngine: TrendLanguageEngine(source: const _FakeSource([_mildRoastPhrase])),
      );
      final result = _buildResult(
        userType: 'student',
        aiMemory: const {}, // stranger
        engine: engine,
      );
      expect(result.usedTrendPhraseId, isNull,
          reason: 'Voi stranger, phrase offensiveness=1 phai bi loai boi ceiling=0 that su cua TrendLanguageEngine');
    });

    test('trendEngine tich hop: relationship=friend -> phrase co offensiveness=1 DUOC CHON (ceiling=1 cho phep)', () {
      final engine = CompanionPersonalityEngine(
        trendEngine: TrendLanguageEngine(source: const _FakeSource([_mildRoastPhrase])),
      );
      final result = _buildResult(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
        engine: engine,
      );
      expect(result.usedTrendPhraseId, equals('mild_roast_1'),
          reason: 'Voi friend, phrase offensiveness=1 phai duoc phep chon — xac nhan relationship '
              'tu aiMemory (nguon moi) THAT SU truyen dung vao TrendContext, khong pha vo tich hop cu');
    });
  });
}
