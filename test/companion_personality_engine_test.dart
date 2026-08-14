import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';

// Cau dac trung, chi xuat hien trong khoi TRENDING 台灣用語 (mobile/lib/
// features/chat/engines/companion_personality_engine.dart) — dung de xac
// nhan khoi nay CO/KHONG co mat trong prompt, khong dua vao suy doan.
const _trendingHeadingZh = 'TRENDING 台灣用語';
const _trendingHeadingEn = 'TRENDING Gen Z English slang';
const _trendingProfanityPhraseZh = '你是豬嗎'; // cau "may la heo a" trong khoi chui vui
const _trendingProfanityPhraseEn = 'that answer is cooked';

String _buildPrompt({
  required String userType,
  String currentUserText = 'Hôm nay tao học từ mới nhé',
  String learningMode = 'zh_vi',
  Map<String, dynamic> aiMemory = const {},
  String? chineseLevel,
}) {
  const engine = CompanionPersonalityEngine();
  final result = engine.buildSystemPromptV2(
    learningMode: learningMode,
    userType: userType,
    sessionMessages: 5,
    mistakes: const [],
    userFrustrated: false,
    aiMemory: aiMemory,
    nextAction: null,
    aiName: 'Yuki',
    aiGender: 'female',
    isVip: false,
    now: DateTime(2026, 8, 10, 15, 0), // Thu Hai — tranh nhanh "cuoi tuan" gay nhieu khi doc ket qua
    currentUserText: currentUserText,
    recentlySuggestedTrendPhraseIds: const {},
    chineseLevel: chineseLevel,
  );
  return result.prompt;
}

void main() {
  group('CompanionPersonalityEngine — gate cung TRENDING (uu tien 1)', () {
    test('userType=kid — prompt KHONG duoc chua khoi TRENDING (zh)', () {
      final prompt = _buildPrompt(userType: 'kid');
      expect(prompt.contains(_trendingHeadingZh), isFalse,
          reason: 'Khoi TRENDING (co cau chui/mang vui) khong duoc xuat hien voi userType=kid');
      expect(prompt.contains(_trendingProfanityPhraseZh), isFalse,
          reason: 'Cau chui/mang vui cu the khong duoc xuat hien voi userType=kid');
    });

    test('userType=kid — prompt KHONG duoc chua khoi TRENDING (en)', () {
      final prompt = _buildPrompt(userType: 'kid', learningMode: 'en_vi');
      expect(prompt.contains(_trendingHeadingEn), isFalse);
      expect(prompt.contains(_trendingProfanityPhraseEn), isFalse);
    });

    test('userType=kid — cac phan khac cua prompt (styleRule, identity) van con nguyen', () {
      final prompt = _buildPrompt(userType: 'kid');
      expect(prompt.contains('PERSONALITY — Trẻ em'), isTrue,
          reason: 'Chi gate rieng khoi TRENDING, KHONG duoc xoa nham phan khac');
      expect(prompt.contains('KHÔNG BAO GIỜ mắng trẻ em dù sai'), isTrue);
    });

    test('userType=student (khong khung hoang) — TRENDING VAN xuat hien binh thuong (khong regression)', () {
      final prompt = _buildPrompt(userType: 'student');
      expect(prompt.contains(_trendingHeadingZh), isTrue,
          reason: 'Truong hop binh thuong (khong phai kid, khong khung hoang) phai giu nguyen hanh vi cu');
    });

    test('userType=adult (khong khung hoang) — TRENDING van xuat hien binh thuong', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt.contains(_trendingHeadingZh), isTrue);
    });

    test('userType=elder (khong khung hoang) — TRENDING van xuat hien binh thuong', () {
      final prompt = _buildPrompt(userType: 'elder');
      expect(prompt.contains(_trendingHeadingZh), isTrue);
    });

    test('Safety Override kich hoat (userType=student) — TRENDING PHAI bi loai bo hoan toan, khong chi bi countermand', () {
      final prompt = _buildPrompt(
        userType: 'student',
        currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá',
      );
      // Xac nhan Safety Override THAT SU kich hoat (dung tien de test)
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue,
          reason: 'Cau input phai kich hoat duoc Safety Override de test nay co y nghia');
      // Xac nhan khoi TRENDING bi loai bo HOAN TOAN khoi prompt, khong
      // chi bi noi countermand phia sau trong khi van con ton tai o tren.
      expect(prompt.contains(_trendingHeadingZh), isFalse,
          reason: 'Khi Safety Override kich hoat, TRENDING phai bi loai bo khoi prompt, khong chi bi countermand');
      expect(prompt.contains(_trendingProfanityPhraseZh), isFalse);
    });

    test('Safety Override kich hoat (userType=adult) — TRENDING van bi loai bo, bat ke userType', () {
      final prompt = _buildPrompt(
        userType: 'adult',
        currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá',
      );
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue);
      expect(prompt.contains(_trendingHeadingZh), isFalse);
    });

    test('Safety Override kich hoat + userType=kid cung luc — van bi loai bo (2 dieu kien trung nhau khong xung dot)', () {
      final prompt = _buildPrompt(
        userType: 'kid',
        currentUserText: 'Tao không muốn sống nữa, mọi thứ vô nghĩa quá',
      );
      expect(prompt.contains(_trendingHeadingZh), isFalse);
    });

    test('Safety Override KHONG kich hoat voi tin nhan binh thuong — TRENDING khong bi anh huong', () {
      final prompt = _buildPrompt(userType: 'student', currentUserText: 'Hôm nay tao học từ mới nhé');
      expect(prompt.contains('SAFETY OVERRIDE'), isFalse);
      expect(prompt.contains(_trendingHeadingZh), isTrue);
    });
  });

  group('Audit AI Companion — Uu tien 1: sua bug [NEW:詞語] placeholder leak + vi pham pinyin', () {
    // Boi canh: audit phat hien qua goi that gpt-4o-mini — khi day tu moi,
    // model co luc giu nguyen van placeholder "[NEW:詞語]" tu RULE TEXT
    // (thay vi thay bang tu that dang day) VA dong thoi viet pinyin du
    // RULE #2 cam tuyet doi. Da sua rule 5 (tag NEW) noi ro "詞語 CHI LA VI
    // DU MINH HOA" + nhac lai cam pinyin ngay tai vi tri de vi pham nhat.
    // Test nay CHI kiem tra rule TEXT trong prompt co duoc cung co dung
    // nhu mo ta — hanh vi THAT cua model da xac nhan rieng qua 5 lan goi
    // that gpt-4o-mini (0/5 vi pham, xem bao cao Uu tien 1).
    test('Rule 5 (tag NEW) phai canh bao ro "詞語" chi la vi du minh hoa, khong duoc giu nguyen', () {
      final prompt = _buildPrompt(userType: 'student');
      expect(prompt, contains('CHỈ LÀ VÍ DỤ MINH HỌA'));
      expect(prompt, contains('TUYỆT ĐỐI KHÔNG được giữ nguyên chữ "詞語"'));
    });

    test('Rule 5 phai nhac lai cam pinyin ngay tai vi tri day tu moi', () {
      final prompt = _buildPrompt(userType: 'student');
      // Doan rule 5 (tag NEW) phai tu no nhac lai cam pinyin, khong chi
      // dua vao rule 2 o xa phia tren.
      final rule5Start = prompt.indexOf('5. Khi dạy 1 từ mới');
      expect(rule5Start, greaterThanOrEqualTo(0));
      // Buoc 4 muc G: rule 5 duoc mo rong them 1 mo dau ve truong hop user
      // chu dong hoi nghia 1 tu cu the (dai hon truoc ~90 ky tu) — noi
      // rong cua so tim kiem tuong ung, khong doi ban chat dieu test.
      final rule5Text = prompt.substring(rule5Start, rule5Start + 500);
      expect(rule5Text, contains('KHÔNG kèm pinyin'));
    });

    test('Rule 2 (cam pinyin) van con nguyen, chi bo sung tham chieu cheo sang rule 5', () {
      final prompt = _buildPrompt(userType: 'student');
      expect(prompt, contains('2. KHÔNG BAO GIỜ viết pinyin'));
    });
  });

  group('Audit AI Companion — Uu tien 2: da dang hoa cau mo dau / cau hoi ket thuc', () {
    // Boi canh: audit phat hien qua goi that gpt-4o-mini — 4/18 scenario
    // mo dau bang DUNG HET cum "你好! (Xin chào...)" du userType khac nhau,
    // 5/18 ket thuc bang bien the gan giong nhau cua "hôm nay bạn thế
    // nào". Da them pool _openerStyleHints (chi hien khi tin nhan la loi
    // chao ngan) + tang cuong rule 4 voi huong dan da dang hoa + pool
    // _closingQuestionStyleHints. Hanh vi THAT cua model da xac nhan rieng
    // qua 10 lan goi that gpt-4o-mini (0/10 con lap "你好!", xem bao cao
    // Uu tien 2).
    test('Tin nhan la loi chao don gian -> prompt co GOI Y CACH VAO CHUYEN', () {
      final prompt = _buildPrompt(userType: 'student', currentUserText: 'Xin chào');
      expect(prompt, contains('GỢI Ý CÁCH VÀO CHUYỆN'));
    });

    test('Tin nhan KHONG phai loi chao (cau hoi ngu phap) -> KHONG chen goi y vao chuyen', () {
      final prompt = _buildPrompt(userType: 'student', currentUserText: '了 và 過 khác nhau thế nào?');
      expect(prompt, isNot(contains('GỢI Ý CÁCH VÀO CHUYỆN')));
    });

    test('Safety Override kich hoat + tin nhan trong nhu loi chao -> VAN KHONG chen goi y vao chuyen', () {
      // vd edge case "Chào mày, tao buồn quá, tao không muốn sống nữa" —
      // uu tien quan tam nghiem tuc, khong phai da dang hoa cach chao.
      final prompt = _buildPrompt(
        userType: 'student',
        currentUserText: 'Chào mày, tao buồn quá, tao không muốn sống nữa',
      );
      expect(prompt.contains('SAFETY OVERRIDE'), isTrue);
      expect(prompt, isNot(contains('GỢI Ý CÁCH VÀO CHUYỆN')));
    });

    test('Goi lien tiep voi CUNG 1 loi chao -> goi y vao chuyen co bien thien that (khong luon 1 ket qua)', () {
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final prompt = _buildPrompt(userType: 'student', currentUserText: 'Xin chào');
        final start = prompt.indexOf('GỢI Ý CÁCH VÀO CHUYỆN');
        final section = prompt.substring(start, start + 250);
        seen.add(section);
      }
      expect(seen.length, greaterThan(1), reason: 'Goi y vao chuyen phai xoay vong, khong duoc luon giong het nhau');
    });

    test('Rule 4 (bat buoc) phai co huong dan da dang hoa + tranh mau "hôm nay bạn thế nào"', () {
      final prompt = _buildPrompt(userType: 'student', currentUserText: 'Hôm nay tao học từ mới nhé');
      final rule4Start = prompt.indexOf('4. Luôn kết thúc');
      expect(rule4Start, greaterThanOrEqualTo(0));
      final rule4Text = prompt.substring(rule4Start, rule4Start + 400);
      expect(rule4Text, contains('đa dạng hoá cách hỏi'));
      expect(rule4Text, contains('Gợi ý cho lượt này:'));
    });

    test('Rule 4 goi y xoay vong qua nhieu lan goi (khong luon 1 goi y co dinh)', () {
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        final prompt = _buildPrompt(userType: 'student', currentUserText: 'Hôm nay tao học từ mới nhé');
        final rule4Start = prompt.indexOf('Gợi ý cho lượt này:');
        seen.add(prompt.substring(rule4Start, rule4Start + 150));
      }
      expect(seen.length, greaterThan(1));
    });

    test('Rule 4 (khong bat buoc, vd user vua hoi thang) van giu nguyen hanh vi cu, chi bo sung nhac nho nhe', () {
      final prompt = _buildPrompt(userType: 'student', currentUserText: '了 và 過 khác nhau thế nào?');
      expect(prompt, contains('KHÔNG bắt buộc kết thúc bằng câu hỏi'));
      expect(prompt, contains('tránh mẫu chung chung'));
    });
  });

  group('Audit AI Companion — Buoc 4 muc A: truyen chinese_level vao engine (plumbing)', () {
    // Luu y (sau khi them muc C/rule 13): rule 13 (dieu chinh do kho) LUON
    // xuat hien va TU NO co nhac cum "Trình độ tiếng Trung hiện tại của
    // user" (khong kem "theo hồ sơ:") + tu "beginner" nhu 1 phan huong dan
    // chung, KHONG phu thuoc chineseLevel co duoc truyen hay khong. Vi vay
    // cac test nay phai kiem tra dung CHUOI DAY DU cua _buildLevelContextNote
    // (co "theo hồ sơ:") de khong bi nham voi rule 13.
    test('chineseLevel null (mac dinh, loi goi cu) — prompt KHONG chua dong ghi chu trinh do tu ho so', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt.contains('Trình độ tiếng Trung hiện tại của user theo hồ sơ:'), isFalse,
          reason: 'Loi goi cu chua biet tham so nay khong duoc doi hanh vi prompt');
    });

    test('chineseLevel rong ("") — coi nhu chua co, KHONG chua dong ghi chu trinh do tu ho so', () {
      final prompt = _buildPrompt(userType: 'adult', chineseLevel: '');
      expect(prompt.contains('Trình độ tiếng Trung hiện tại của user theo hồ sơ:'), isFalse);
    });

    test('chineseLevel="beginner" — prompt PHAI chua dung gia tri nay', () {
      final prompt = _buildPrompt(userType: 'adult', chineseLevel: 'beginner');
      expect(prompt.contains('Trình độ tiếng Trung hiện tại của user theo hồ sơ: beginner'), isTrue);
    });

    test('chineseLevel="intermediate" — prompt PHAI chua dung gia tri nay (khong hard-code beginner)', () {
      final prompt = _buildPrompt(userType: 'adult', chineseLevel: 'intermediate');
      expect(prompt.contains('Trình độ tiếng Trung hiện tại của user theo hồ sơ: intermediate'), isTrue);
      expect(prompt.contains('theo hồ sơ: beginner'), isFalse);
    });

    test('chineseLevel khong lam mat cac phan tinh khac cua prompt (RULES, IDENTITY van con nguyen)', () {
      // Luu y: buildSystemPrompt co ngau nhien rieng (TRENDING/opener hint/
      // closing hint tu Random() moi lan goi) nen KHONG so sanh byte-exact
      // 2 lan goi khac nhau — chi xac nhan cac phan TINH (khong ngau nhien)
      // van con nguyen khi co chineseLevel.
      final prompt = _buildPrompt(userType: 'adult', chineseLevel: 'beginner');
      expect(prompt.contains('IDENTITY: Mày là'), isTrue);
      expect(prompt.contains('RULES BẮT BUỘC:'), isTrue);
      expect(prompt.contains('TÍNH CÁCH CỐ ĐỊNH:'), isTrue);
      // Dong trinh do phai nam NGAY SAU khoi IDENTITY/mood, TRUOC RULES
      final levelIdx = prompt.indexOf('Trình độ tiếng Trung hiện tại');
      final rulesIdx = prompt.indexOf('RULES BẮT BUỘC:');
      expect(levelIdx, greaterThan(0));
      expect(levelIdx, lessThan(rulesIdx));
    });
  });

  group('Audit AI Companion — Buoc 4 muc B: van hoa/ngu canh thuc te (rule 12)', () {
    test('Rule 12 xuat hien, yeu cau dao sau van hoa/ap luc ngam/cach ung xu', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('12. Khi giải thích 1 từ/cụm từ/câu liên quan đến TÌNH HUỐNG THỰC TẾ'));
      expect(prompt, contains('sắc thái văn hóa'));
      expect(prompt, contains('áp lực/kỳ vọng ngầm'));
      expect(prompt, contains('cách ứng xử/phản hồi phù hợp'));
    });

    test('Rule 12 luon xuat hien bat ke userType (khong bi gate nham nhu TRENDING)', () {
      for (final userType in ['kid', 'student', 'adult', 'elder']) {
        final prompt = _buildPrompt(userType: userType);
        expect(prompt.contains('12. Khi giải thích'), isTrue, reason: 'userType=$userType phai co rule 12');
      }
    });
  });

  group('Audit AI Companion — Buoc 4 muc C: dieu chinh do kho theo trinh do (rule 13)', () {
    test('Rule 13 xuat hien, nhac ca 2 nguon tin hieu (ho so + cau hoi hien tai)', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('13. TRƯỚC KHI giải thích 1 cấu trúc ngữ pháp/khái niệm NÂNG CAO'));
      expect(prompt, contains('mình mới học'));
      expect(prompt, contains('đơn giản hóa cách giải thích'));
    });

    test('Rule 13 xuat hien du chineseLevel null (dua vao tin hieu cau hoi hien tai)', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt.contains('13. TRƯỚC KHI giải thích'), isTrue);
    });
  });

  group('Audit AI Companion — Buoc 4 muc D: sua loi phai giai thich (rule 14)', () {
    test('Rule 14 xuat hien, yeu cau giai thich ly do sai + nhac gian-phon the', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('14. Khi user tự viết 1 câu'));
      expect(prompt, contains('LUÔN giải thích NGẮN GỌN lý do câu gốc sai'));
      expect(prompt, contains('giản thể (简体字)'));
    });
  });

  group('Audit AI Companion — Buoc 4 muc E: cau hoi mo ho/rong (rule 15)', () {
    test('Rule 15 xuat hien, yeu cau hoi lai hoac tong quan co to chuc', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('15. Khi user hỏi 1 câu RỘNG'));
      expect(prompt, contains('hỏi lại 1 câu ngắn để thu hẹp phạm vi'));
      expect(prompt, contains('TỔNG QUAN CÓ TỔ CHỨC'));
    });
  });

  group('Audit AI Companion — Buoc 4 muc F: luyen tap/quiz co the cham (rule 16)', () {
    test('Rule 16 xuat hien, yeu cau bai tap that (dien khuyet/trac nghiem), khong chi liet ke', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('16. Khi user yêu cầu LUYỆN TẬP/QUIZ/đố'));
      expect(prompt, contains('điền vào chỗ trống'));
      expect(prompt, contains('trắc nghiệm ngắn'));
    });
  });

  group('Audit AI Companion — Buoc 4 muc G: tag [NEW:] khi hoi nghia tu cu the (rule 5 mo rong)', () {
    test('Rule 5 ap dung ro CA khi user chu dong hoi nghia 1 tu cu the', () {
      final prompt = _buildPrompt(userType: 'adult');
      expect(prompt, contains('HOẶC khi user chủ động hỏi nghĩa 1 từ tiếng Trung cụ thể'));
    });
  });
}
