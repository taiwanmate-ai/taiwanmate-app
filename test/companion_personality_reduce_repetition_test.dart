import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';

const _mandatoryQuestionRuleOriginal = 'Luôn kết thúc bằng câu hỏi hoặc challenge nhỏ';
const _mandatoryQuestionRuleConditional = 'KHÔNG bắt buộc kết thúc bằng câu hỏi';

({String prompt, String? usedTrendPhraseId}) _buildResult({
  required String currentUserText,
  String userType = 'student',
  Map<String, dynamic> aiMemory = const {'relationship': 'friend'},
}) {
  const engine = CompanionPersonalityEngine();
  return engine.buildSystemPromptV2(
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
  );
}

String _buildPrompt({
  required String currentUserText,
  String userType = 'student',
  Map<String, dynamic> aiMemory = const {'relationship': 'friend'},
}) {
  return _buildResult(currentUserText: currentUserText, userType: userType, aiMemory: aiMemory).prompt;
}

void main() {
  group('CompanionPersonalityEngine — giam lap template (uu tien 4)', () {
    // ─────────────────────────────────────────────────────────
    // Muc 10: TRENDING xoay vong/chon ngau nhien, khong con tinh 100%
    // ─────────────────────────────────────────────────────────
    test('goi buildSystemPromptV2 nhieu lan lien tiep voi CUNG input -> khoi TRENDING co bien thien that (khong luon 1 ket qua co dinh)', () {
      const engine = CompanionPersonalityEngine();
      final variants = <String>{};
      for (var i = 0; i < 25; i++) {
        final result = engine.buildSystemPromptV2(
          learningMode: 'zh_vi',
          userType: 'student',
          sessionMessages: 5,
          mistakes: const [],
          userFrustrated: false,
          aiMemory: const {'relationship': 'friend'},
          nextAction: null,
          aiName: 'Yuki',
          aiGender: 'female',
          isVip: false,
          now: DateTime(2026, 8, 10, 15, 0),
          currentUserText: 'Hôm nay tao học từ mới nhé',
          recentlySuggestedTrendPhraseIds: const {},
        );
        final start = result.prompt.indexOf('TRENDING 台灣用語');
        final end = result.prompt.indexOf('RULES BẮT BUỘC');
        expect(start, greaterThanOrEqualTo(0));
        expect(end, greaterThan(start));
        variants.add(result.prompt.substring(start, end));
      }
      expect(variants.length, greaterThan(1),
          reason: 'Goi 25 lan voi CUNG input (cung userType/relationship/now/currentUserText) '
              'phai cho it nhat 2 bien the khac nhau cua khoi TRENDING — neu chi co 1, '
              'nghia la van dang tinh nhu cu, chua thuc su xoay vong');
    });

    test('khoi TRENDING sau xoay vong van giu dung SO LUONG dong va cau truc tieu de (khong pha noi dung/dinh dang)', () {
      final prompt = _buildPrompt(currentUserText: 'Hôm nay tao học từ mới nhé');
      expect(prompt.contains('TRENDING 台灣用語 (dùng tự nhiên khi phù hợp):'), isTrue);
      expect(prompt.contains('Chửi vui khi SAI HỌC TẬP (KHÔNG chửi chuyện đời tư):'), isTrue);
      expect(prompt.contains('Khen khi ĐÚNG:'), isTrue);
      expect(prompt.contains('Kể chuyện cá nhân tự nhiên (1/5 lần):'), isTrue);
      // Chi con 2 dong moi nhom (thay vi toan bo 4/3/4 dong nhu truoc) —
      // dem so dong bat dau bang "- " hoac "  - " trong doan TRENDING.
      final start = prompt.indexOf('TRENDING 台灣用語');
      final end = prompt.indexOf('RULES BẮT BUỘC');
      final section = prompt.substring(start, end);
      final bulletCount = RegExp(r'^\s*-\s', multiLine: true).allMatches(section).length;
      expect(bulletCount, equals(6), reason: '2 chửi vui + 2 khen + 2 kể chuyện = 6 dòng, không phải 4+3+4=11 như trước');
    });

    // ─────────────────────────────────────────────────────────
    // Muc 11: rule "luon hoi lai cuoi cau" co dieu kien
    // ─────────────────────────────────────────────────────────
    test('user vua hoi 1 cau ro rang -> rule "luon hoi lai" KHONG con bat buoc', () {
      final prompt = _buildPrompt(currentUserText: '了 và 過 khác nhau như thế nào?');
      expect(prompt.contains(_mandatoryQuestionRuleOriginal), isFalse);
      expect(prompt.contains(_mandatoryQuestionRuleConditional), isTrue);
    });

    test('user hoi bang tieng Anh (ket thuc dau ?) -> rule "luon hoi lai" KHONG con bat buoc', () {
      final prompt = _buildPrompt(currentUserText: 'What does this word mean?');
      expect(prompt.contains(_mandatoryQuestionRuleOriginal), isFalse);
    });

    test('Safety Override kich hoat -> rule "luon hoi lai" KHONG con bat buoc', () {
      final prompt = _buildPrompt(currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá');
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue,
          reason: 'Xac nhan Safety Override THAT SU kich hoat de test co y nghia');
      expect(prompt.contains(_mandatoryQuestionRuleOriginal), isFalse);
      expect(prompt.contains(_mandatoryQuestionRuleConditional), isTrue);
    });

    test('truong hop binh thuong (khong phai cau hoi, khong safety) -> rule "luon hoi lai" VAN xuat hien nhu cu (khong regression)', () {
      final prompt = _buildPrompt(currentUserText: 'Hôm nay tao học từ mới nhé');
      expect(prompt.contains(_mandatoryQuestionRuleOriginal), isTrue);
      expect(prompt.contains(_mandatoryQuestionRuleConditional), isFalse);
    });

    test('rule van giu dung vi tri so "4." de khong pha tham chieu "quy tắc số 4" cua rule VIP Socrates', () {
      final promptNormal = _buildPrompt(currentUserText: 'Hôm nay tao học từ mới nhé');
      expect(RegExp(r'^4\.\s').hasMatch(
          promptNormal.split('\n').firstWhere((l) => l.contains(_mandatoryQuestionRuleOriginal))), isTrue);

      final promptQuestion = _buildPrompt(currentUserText: '了 và 過 khác nhau như thế nào?');
      expect(RegExp(r'^4\.\s').hasMatch(
          promptQuestion.split('\n').firstWhere((l) => l.contains(_mandatoryQuestionRuleConditional))), isTrue);
    });
  });
}
