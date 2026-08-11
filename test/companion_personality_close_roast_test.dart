import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';

// Cau dac trung CHI xuat hien khi style "Gan gui/mang yeu" (close_roast)
// THAT SU duoc ap dung — dung de xac nhan CO/KHONG, khong doan.
const _closeRoastHeading = 'PERSONALITY — Gần gũi/mắng yêu';
const _closeRoastPhrase = 'Lười vậy sao giỏi được?';

String _buildPrompt({
  required String userType,
  required Map<String, dynamic> aiMemory,
  String conversationStyle = 'close_roast',
  String currentUserText = 'Hôm nay tao học từ mới nhé',
}) {
  const engine = CompanionPersonalityEngine();
  final result = engine.buildSystemPromptV2(
    learningMode: 'zh_vi',
    userType: userType,
    sessionMessages: 5,
    mistakes: const [],
    userFrustrated: false,
    aiMemory: aiMemory,
    nextAction: null,
    aiName: 'Yuki',
    aiGender: 'female',
    isVip: false,
    now: DateTime(2026, 8, 10, 15, 0), // Thu Hai — tranh nhieu "cuoi tuan"
    currentUserText: currentUserText,
    recentlySuggestedTrendPhraseIds: const {},
    conversationStyle: conversationStyle,
  );
  return result.prompt;
}

void main() {
  group('CompanionPersonalityEngine — conversation style "close_roast" (uu tien 3)', () {
    // ─────────────────────────────────────────────────────────
    // Dieu kien a: CHI student/adult, TUYET DOI khong kid/elder
    // ─────────────────────────────────────────────────────────
    test('a) userType=kid — style close_roast BI CHAN du da yeu cau, fallback ve styleRule kid mac dinh', () {
      final prompt = _buildPrompt(
        userType: 'kid',
        aiMemory: const {'relationship': 'bestfriend'}, // du dieu kien khac
      );
      expect(prompt.contains(_closeRoastHeading), isFalse);
      expect(prompt.contains(_closeRoastPhrase), isFalse);
      expect(prompt.contains('PERSONALITY — Trẻ em'), isTrue,
          reason: 'Phai fallback dung ve styleRule mac dinh cua kid');
    });

    test('a) userType=elder — style close_roast BI CHAN du da yeu cau, fallback ve styleRule elder mac dinh', () {
      final prompt = _buildPrompt(
        userType: 'elder',
        aiMemory: const {'relationship': 'bestfriend'},
      );
      expect(prompt.contains(_closeRoastHeading), isFalse);
      expect(prompt.contains('PERSONALITY — Người lớn tuổi'), isTrue);
    });

    test('a) userType=student — style close_roast DUOC PHEP (du dieu kien khac dat)', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
      expect(prompt.contains(_closeRoastPhrase), isTrue);
    });

    test('a) userType=adult — style close_roast DUOC PHEP (du dieu kien khac dat)', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        aiMemory: const {'relationship': 'friend'},
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
    });

    // ─────────────────────────────────────────────────────────
    // Dieu kien c: relationship level tu 'acquaintance' tro len
    // ─────────────────────────────────────────────────────────
    test('c) relationship=stranger (aiMemory rong) — style BI CHAN, chua du "Quen"', () {
      final prompt = _buildPrompt(userType: 'student', aiMemory: const {});
      expect(prompt.contains(_closeRoastHeading), isFalse);
      expect(prompt.contains('PERSONALITY — Sinh viên'), isTrue,
          reason: 'Fallback dung ve styleRule student mac dinh');
    });

    test('c) relationship=acquaintance (nguong toi thieu) — style DUOC PHEP', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'acquaintance'},
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
    });

    test('c) relationship=friend — style DUOC PHEP', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
    });

    test('c) relationship=bestfriend — style DUOC PHEP', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        aiMemory: const {'relationship': 'bestfriend'},
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
    });

    // ─────────────────────────────────────────────────────────
    // Dieu kien d: Safety Override kich hoat -> vo hieu hoa hoan toan,
    // dung LAI CHINH co che suppressTrending da co tu uu tien 1.
    // ─────────────────────────────────────────────────────────
    test('d) Safety Override kich hoat — style BI CHAN HOAN TOAN du userType/relationship du dieu kien', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'bestfriend'}, // du ca a va c
        currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá',
      );
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue,
          reason: 'Xac nhan Safety Override THAT SU kich hoat de test co y nghia');
      expect(prompt.contains(_closeRoastHeading), isFalse,
          reason: 'close_roast phai bi vo hieu hoa hoan toan khi Safety Override kich hoat');
      expect(prompt.contains(_closeRoastPhrase), isFalse);
      // TRENDING cung phai bi loai (da xac nhan o uu tien 1) — dung CHUNG 1 co che
      expect(prompt.contains('TRENDING 台灣用語'), isFalse);
    });

    // ─────────────────────────────────────────────────────────
    // Mac dinh KHONG tu ap dung khi khong duoc yeu cau (opt-in, khong phai opt-out)
    // ─────────────────────────────────────────────────────────
    test('conversationStyle mac dinh "default" — KHONG tu ap dung close_roast du du dieu kien a/c/d', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'bestfriend'},
        conversationStyle: 'default',
      );
      expect(prompt.contains(_closeRoastHeading), isFalse,
          reason: 'close_roast la opt-in — phai duoc yeu cau ro qua conversationStyle, khong tu bat');
      expect(prompt.contains('PERSONALITY — Sinh viên'), isTrue);
    });

    // ─────────────────────────────────────────────────────────
    // Test to hop (combination) — dung nhu yeu cau muc 9
    // ─────────────────────────────────────────────────────────
    test('to hop: student + friend + KHONG safety active -> style DUOC PHEP', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
        currentUserText: 'Hôm nay tao học từ mới nhé', // binh thuong, khong kich hoat safety
      );
      expect(prompt.contains(_closeRoastHeading), isTrue);
    });

    test('to hop: student + friend NHUNG safety active -> style BI CHAN du du dieu kien a/c', () {
      final prompt = _buildPrompt(
        userType: 'student',
        aiMemory: const {'relationship': 'friend'},
        currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá',
      );
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue);
      expect(prompt.contains(_closeRoastHeading), isFalse,
          reason: 'Dieu kien d (Safety Override) phai thang du a va c da du');
    });

    test('to hop: adult + stranger (chua du dieu kien c) + khong safety -> style BI CHAN', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        aiMemory: const {}, // stranger
      );
      expect(prompt.contains(_closeRoastHeading), isFalse);
    });

    test('to hop: kid + bestfriend + khong safety -> van BI CHAN vi dieu kien a khong dat (kid tuyet doi khong)', () {
      final prompt = _buildPrompt(
        userType: 'kid',
        aiMemory: const {'relationship': 'bestfriend'},
      );
      expect(prompt.contains(_closeRoastHeading), isFalse);
    });
  });
}
