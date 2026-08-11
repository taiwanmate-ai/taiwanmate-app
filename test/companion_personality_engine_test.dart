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
      final rule5Text = prompt.substring(rule5Start, rule5Start + 400);
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
}
