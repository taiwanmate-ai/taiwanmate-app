/// CompanionPersonalityEngine — tach tu getter _systemPrompt trong ChatScreen.
/// CHI di chuyen logic, KHONG doi noi dung/thu tu/dieu kien prompt.
/// Khong phu thuoc BuildContext hay State — moi du lieu can thiet truyen qua
/// tham so cua buildSystemPrompt().
import 'dart:math';
import 'trend_language_models.dart';
import 'trend_language_engine.dart';

class CompanionPersonalityEngine {
  const CompanionPersonalityEngine({this.trendEngine = const TrendLanguageEngine()});
  final TrendLanguageEngine trendEngine;

  TrendAudience _mapAudience(String userType) {
    switch (userType) {
      case 'kid': return TrendAudience.kid;
      case 'elder': return TrendAudience.elder;
      case 'adult': return TrendAudience.adult;
      default: return TrendAudience.student;
    }
  }

  // Nguon DUY NHAT cho relationship level — thay cho 3 noi truoc day tu
  // doc/tu chuan hoa aiMemory['relationship'] rieng le, co the lech nhau:
  //   1. _mapRelationship (duoi day) — co normalize qua switch, dung cho trendEngine.
  //   2. memoryNote (hien thi USER MEMORY) — doc THANG aiMemory['relationship'],
  //      KHONG qua buoc chuan hoa nao (vd sai hoa/thuong, gia tri la khong hop le
  //      van hien nguyen van thay vi fallback ve 'stranger').
  //   3. student intimacy — TRUOC DAY hoan toan KHONG dung aiMemory, chi dung
  //      sessionMessages (bien State cuc bo, RESET VE 0 moi lan mo lai man
  //      hinh Chat) — khong phai "lich su tuong tac that", va CHI ap dung
  //      rieng cho userType == 'student', cac userType khac khong co khai
  //      niem relationship level nao ca.
  // Gio CA 3 noi deu goi ham nay — 1 nguon that, persist qua aiMemory (tu
  // backend, KHONG reset khi mo lai man hinh), ap dung DONG NHAT cho MOI
  // userType, dung 4 muc khop du lieu aiMemory hien co: stranger (Moi gap)
  // / acquaintance (Quen so) / friend (Ban be) / bestfriend (Than thiet).
  static const _validRelationshipLevels = {
    'stranger', 'acquaintance', 'friend', 'bestfriend',
  };

  String _relationshipLevel(Map<String, dynamic> aiMemory) {
    final raw = aiMemory['relationship']?.toString().trim().toLowerCase();
    return _validRelationshipLevels.contains(raw) ? raw! : 'stranger';
  }

  // ============================================================
  // KIEN TRUC — 2 CO CHE TRENDING SONG SONG, CO CHU DICH, KHONG PHAI
  // TRUNG LAP NGAU NHIEN (audit AI Companion, Uu tien 3):
  //
  //   (A) KHOI "TRENDING ..." tinh (cac list _roastLinesZh/_praiseLinesZh/
  //       _storyLinesZh/_roastLinesEn/_hypeLinesEn ngay duoi day, chon qua
  //       _pickRandomLines): NGAN HANG CAU MAU SAN SANG DUNG — AI co the
  //       dung gan nhu nguyen van khi chui vui/khen/ke chuyen. Du lieu
  //       CUNG (hardcode), gate an toan la 1 dieu kien NHI PHAN don gian:
  //       `trendingAllowed = userType != 'kid' && !suppressTrending`
  //       (xem buildSystemPrompt ben duoi) — KHONG phan biet muc do theo
  //       relationship/audience/emotional-tier, chi CO/KHONG.
  //
  //   (B) trendEngine.select() (goi trong buildSystemPromptV2, ket qua la
  //       doan "PHONG CÁCH THAM KHẢO"): 1 CAU GOI Y VE TONG GIONG DUY
  //       NHAT, lay tu TrendLanguageSource (hien la LocalTrendLanguageSource,
  //       nhung la 1 interface — de ngo kha nang sau nay doi sang nguon
  //       dong/quan ly rieng ma KHONG can sua CompanionPersonalityEngine).
  //       Co RIENG 1 lop an toan tinh vi hon nhieu — offensiveness ceiling
  //       thay doi theo relationship/audience/emotional-tier/user co dung
  //       tuc khong (_maxOffensivenessFor trong trend_language_engine.dart),
  //       uu tien phrase "fresh"/"active" hon "fading", tranh phrase da
  //       goi y gan day (recentlySuggestedPhraseIds) — cac tinh nang NAY
  //       khoi TRENDING tinh o (A) KHONG CO va khong the co neu khong xay
  //       lai tuong tu.
  //
  //   KET LUAN (da doc ky ca 2 co che truoc khi quyet dinh): KHONG gop —
  //   (A) va (B) giai quyet 2 bai toan khac nhau that su (ngan hang cau
  //   mau san dung vs 1 goi y phong cach an toan-tinh-vi tu nguon co the
  //   mo rong), gop lai se buoc phai HOAC bo tinh nang an toan tinh vi cua
  //   (B) (rui ro that), HOAC xay lai toan bo (A) thanh du lieu co
  //   offensiveness/freshness/relationship y het (A) trong (B) — CA HAI
  //   deu DOI HANH VI OUTPUT hien tai, trai voi yeu cau "uu tien khong
  //   doi hanh vi". Giu nguyen CA HAI, chi lam ro ranh gioi bang comment
  //   nay de nguoi sau (ke ca Voice pipeline dung chung engine nay) hieu
  //   day la 2 co che CO CHU DICH, khong phai no ra do sua nhieu lan
  //   khong ra soat.
  // ============================================================
  //
  // Uu tien 4 (Phase 1, giam lap template): TRUOC DAY khoi TRENDING dua
  // NGUYEN VAN toan bo danh sach co dinh nay vao prompt MOI LAN goi —
  // dan den AI de lap lai y het cung vai vi du qua nhieu luot chat (xem
  // audit truoc: "TRENDING... la chuoi TINH, khong xoay vong, khong phu
  // thuoc userType/session/relationship"). SUA: giu NGUYEN cau chu/tinh
  // than tung dong (KHONG doi noi dung cau nao), nhung moi lan goi chi
  // chon NGAU NHIEN 2 trong so cac dong co san cho moi nhom (chui vui/
  // khen/ke chuyen), thay vi luon dua het toan bo — giam kha nang AI lap
  // y het vi dinh dang moi lan thay doi that (khac dong nao duoc chon).
  //
  // Danh gia phuong an: co xem xet phuong an "theo doi cau da dung qua
  // vai luot gan nhat" (giong co che recentlySuggestedTrendPhraseIds da
  // co cho trendEngine), nhung phuong an do doi hoi them 1 Set<String>
  // state MOI can chat_screen.dart tu quan ly + truyen vao MOI lan goi
  // (tuong tu _recentSuggestedTrendPhraseIds hien co), lam tang dien tich
  // API va state can quan ly chi de giam lap 1 khoi vi du phu (khong
  // phai rui ro an toan). Chon phuong an chon-ngau-nhien-1-tap-con don
  // gian hon NHIEU (khong can them state nao, ham nay van hoan toan
  // "pure" dung tinh than file nay), du khong dam bao TUYET DOI khong
  // bao gio lap (xac suat lap y het toan bo tap con 2/4 + 2/3 + 2/4 giua
  // 2 lan goi lien tiep la rat thap, chap nhan duoc cho muc dich giam lap
  // "thong thuong", khong phai yeu cau an toan).
  static const List<String> _roastLinesZh = [
    '"幹！你怎麼這麼厲害！" (kiểu trầm trồ mỉa mai)',
    '"你在開玩笑嗎？！這樣都答錯！" (không thể tin được)',
    '"我的天啊，你是豬嗎？" (mày là heo à)',
    '"算了啦，你就是這種程度" (thôi kệ, mày chỉ đến vậy)',
  ];
  static const List<String> _praiseLinesZh = [
    '"對！就是這樣！超厲害！"',
    '"你終於對了，我要哭了感動"',
    '"完美！你真的可以！"',
  ];
  static const List<String> _storyLinesZh = [
    '"我昨天去士林夜市買東西，人潮真的多到爆 😂（Hôm qua tao đi chợ đêm Sĩ Lâm mua đồ, đông kinh khủng luôn 😂）"',
    '"今天早上捷運延誤了，害我差點被老闆罵（Sáng nay tàu điện ngầm bị trễ, làm tao suýt bị mắng）"',
    '"我剛剛去買了一杯老虎堂的黑糖珍珠鮮奶，真的超好喝 🧋（Tao vừa mua một ly sữa tươi trân châu đường đen Tiger Sugar, ngon vãi 🧋）"',
    '"今天台北下大雨，你出門有帶傘嗎？（Hôm nay Đài Bắc mưa to, mày có mang dù chưa?）"',
  ];
  static const List<String> _roastLinesEn = [
    '"Bro what was that 💀 that answer is cooked"',
    "\"You're actually delulu if you think that's right\"",
    "\"No cap that's the worst answer I've ever seen lmao\"",
    '"Bestie... we need to talk about your Chinese 😭"',
  ];
  static const List<String> _hypeLinesEn = [
    "\"Let's gooo! That's it bestie! Slay!\"",
    '"Okay I see you! No cap that was perfect!"',
    "\"You're eating and leaving no crumbs rn 🔥\"",
  ];

  // Chon ngau nhien toi da [count] dong TU 1 BAN SAO cua [items] (KHONG
  // sua doi list goc — cac list tren la static const, shuffle truc tiep
  // se loi). Neu items.length <= count, tra ve toan bo (da shuffle thu
  // tu) thay vi loi.
  List<String> _pickRandomLines(List<String> items, int count, Random rng) {
    final pool = List<String>.from(items)..shuffle(rng);
    return pool.take(count).toList();
  }

  TrendRelationship _mapRelationship(Map<String, dynamic> aiMemory) {
    switch (_relationshipLevel(aiMemory)) {
      case 'acquaintance': return TrendRelationship.familiar;
      case 'friend': return TrendRelationship.friend;
      case 'bestfriend': return TrendRelationship.bestFriend;
      default: return TrendRelationship.stranger;
    }
  }

  String _trendLocaleFor(String learningMode) {
    return (learningMode == 'en_only' || learningMode == 'en_vi') ? 'en-global' : 'zh-TW';
  }

  // Uu tien 4 (Phase 1, giam lap template): heuristic DON GIAN — khop
  // dung tinh than cac ham nhe khac trong file nay (classifyEmotionalTier/
  // detectStyle o trend_language_models.dart) — nhan biet tin nhan cua
  // user co phai 1 CAU HOI CAN TRA LOI THANG hay khong, de KHONG bat buoc
  // AI phai hoi nguoc lai cuoi cau (gay cam giac ne tranh cau hoi that).
  // Khong can chinh xac tuyet doi — chi can du tot de tranh truong hop ro
  // rang nhat (user vua hoi, AI lai hoi nguoc thay vi tra loi).
  bool _looksLikeDirectQuestion(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.endsWith('?') || trimmed.endsWith('？')) return true;
    final lower = trimmed.toLowerCase();
    const questionMarkers = [
      'tại sao', 'là gì', 'như thế nào', 'khi nào', 'ở đâu', 'nghĩa là gì',
      'why', 'what', 'how', 'when', 'where',
      '為什麼', '是什麼', '怎麼', '什麼時候', '哪裡',
    ];
    return questionMarkers.any((m) => lower.contains(m));
  }

  // Audit AI Companion (sau Phase 1) — phat hien qua goi that gpt-4o-mini:
  // 4/18 scenario mo dau bang DUNG HET cum "你好! (Xin chào...)" du userType
  // khac nhau, 5/18 ket thuc bang bien the gan giong nhau cua "hôm nay bạn
  // thế nào" — CA HAI deu NGOAI khoi TRENDING (da random tu Uu tien 4).
  // Heuristic DON GIAN nhan biet tin nhan CHI la 1 loi chao xa giao ngan
  // (khong mang noi dung/cau hoi thuc su) — de CHI bat AI da dang hoa cach
  // vao chuyen dung luc can (loi chao), khong ap dung sai cho tin nhan
  // thuc chat (se lam giam chat luong tra loi neu chen huong dan khong can
  // thiet vao cau hoi ngu phap/kien thuc).
  bool _looksLikeSimpleGreeting(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 20) return false; // loi chao thuc su luon ngan
    final lower = trimmed.toLowerCase();
    const greetingMarkers = [
      'xin chào', 'chào bạn', 'chào chị', 'chào anh', 'chào cháu', 'chào em',
      'chào', 'hi', 'hello', 'hey',
      '你好', '嗨', '哈囉',
    ];
    return greetingMarkers.any((m) => lower.contains(m));
  }

  // Uu tien 2 (Audit AI Companion): pool "cach vao chuyen" xoay vong khi
  // tin nhan la loi chao don gian — day la HUONG DAN VE CACH TIEP CAN
  // (khong phai cau mau co dinh de tranh AI copy y het nhu da rut kinh
  // nghiem tu TRENDING) — moi lan chi chon ngau nhien 1 trong so nay, cung
  // co che _pickRandomLines nhu khoi TRENDING.
  static const List<String> _openerStyleHints = [
    'Mở đầu bằng 1 câu cảm thán ngắn về tâm trạng/thời điểm trong ngày của mày (dựa vào TÂM TRẠNG HÔM NAY ở trên), rồi mới chào lại — KHÔNG mở đầu bằng "你好"/"Xin chào" theo công thức.',
    'Bỏ qua câu chào chuẩn mực, đi thẳng vào 1 câu hỏi tò mò cụ thể về user (ví dụ đang làm gì/ở đâu) thay vì câu chào chung chung.',
    'Chào lại bằng 1 câu ngắn kèm ngay 1 chi tiết đời thực ngẫu nhiên của mày (vừa ăn gì, vừa đi đâu, vừa thấy gì) làm cầu nối tự nhiên.',
    'Nếu USER MEMORY có thông tin cũ về user (tên/sở thích/lần chat trước) → mở đầu bằng cách nhắc lại chi tiết đó trước, thay vì chào chung chung.',
    'Dùng 1 câu chào mang cảm xúc/phản ứng thật (vui bất ngờ, uể oải, hào hứng — tuỳ TÂM TRẠNG HÔM NAY) thay vì công thức chào cố định.',
    'Mở đầu bằng cách chia sẻ ngay 1 câu chuyện/cảm xúc nhỏ của bản thân mày trước, rồi mới hỏi lại user.',
  ];

  // Uu tien 2: pool "phong cach cau hoi/challenge ket thuc" xoay vong —
  // dung cho RULES so 4, tranh AI luon hoi 1 mau generic ("hôm nay bạn thế
  // nào") du noi dung cau truoc do khac nhau hoan toan.
  static const List<String> _closingQuestionStyleHints = [
    'Hỏi 1 câu CỤ THỂ bám sát đúng nội dung user vừa nói — KHÔNG dùng câu hỏi chung chung kiểu "hôm nay bạn thế nào".',
    'Đưa ra 1 thử thách nhỏ thay vì câu hỏi — ví dụ nhờ user thử nói/dịch/đặt câu liên quan đến điều vừa nói.',
    'Hỏi cảm nhận/ý kiến riêng của user về điều vừa nói, thay vì hỏi thăm chung chung.',
    'Rủ rê user làm tiếp 1 việc gì đó liên quan (kiểu bạn bè thân), thay vì hỏi thăm.',
    'Đặt 1 câu hỏi tò mò cá nhân, mở rộng sang khía cạnh MỚI của chủ đề vừa nói, không lặp lại pattern hỏi thăm ngày/tâm trạng.',
  ];

  // GATE CUNG bang code cho conversation style "close_roast" (Gan gui/
  // mang yeu) — uu tien 3 cua Phase 1. KHONG dua vao model tu hieu, giong
  // dung bai hoc da ap dung cho TRENDING o uu tien 1. Style nay CHI duoc
  // phep khi CA 3 dieu kien sau deu dung:
  //   a. userType la 'student' hoac 'adult' — TUYET DOI khong cho kid/elder
  //      (kid da co lop chot chan RIENG o backend qua user_type — xem
  //      translate.py::_BACKEND_KID_SAFETY_INSTRUCTION — nhung o day van
  //      chan CUNG tu phia client, KHONG dua vao backend lam lop duy nhat).
  //   b. relationshipLevel dat tu 'acquaintance' tro len (Quen/Ban be/Than
  //      thiet) — KHONG mang ngay tu lan chat dau khi con la stranger.
  //   c. suppressTrending == false — tuc Safety Override KHONG dang kich
  //      hoat (dung LAI CHINH co che da sua o uu tien 1 cho TRENDING,
  //      khong tao co che rieng).
  // Neu bat ky dieu kien nao khong dat, ham nay tra ve false va caller
  // PHAI fallback ve styleRule mac dinh cua userType, khong duoc ap dung
  // style nay du client co yeu cau qua conversationStyle.
  bool _closeRoastStyleAllowed({
    required String userType,
    required String relationshipLevel,
    required bool suppressTrending,
  }) {
    if (suppressTrending) return false;
    if (userType != 'student' && userType != 'adult') return false;
    const unlockedLevels = {'acquaintance', 'friend', 'bestfriend'};
    if (!unlockedLevels.contains(relationshipLevel)) return false;
    return true;
  }

  ({String prompt, String? usedTrendPhraseId}) buildSystemPromptV2({
    required String learningMode,
    required String userType,
    required int sessionMessages,
    required List<String> mistakes,
    required bool userFrustrated,
    required Map<String, dynamic> aiMemory,
    required Map<String, dynamic>? nextAction,
    required String aiName,
    required String aiGender,
    required bool isVip,
    required DateTime now,
    required String currentUserText,
    required Set<String> recentlySuggestedTrendPhraseIds,
    // Truc "conversation style" TACH BIET voi userType (uu tien 3, Phase 1)
    // — mac dinh 'default' (giu NGUYEN styleRule theo userType nhu truoc
    // day, KHONG doi hanh vi cac loi goi cu). 'close_roast' = style "Gan
    // gui/mang yeu" MOI — CHI thuc su duoc ap dung neu _closeRoastStyleAllowed()
    // tra ve true (gate cung o buildSystemPrompt), neu khong se tu dong
    // fallback ve styleRule mac dinh, KHONG bao gio crash hay bo qua gate.
    String conversationStyle = 'default',
  }) {
    final emotionalTier = classifyEmotionalTier(currentUserText);
    final trendLocale = _trendLocaleFor(learningMode);
    final styleSignals = detectStyle(text: currentUserText, locale: trendLocale);
    final trendContext = TrendContext(
      situation: TrendSituation.casualChitchat,
      emotionalTier: emotionalTier,
      relationship: _mapRelationship(aiMemory),
      audience: _mapAudience(userType),
      styleSignals: styleSignals,
      recentlySuggestedPhraseIds: recentlySuggestedTrendPhraseIds,
    );
    // Day la co che TRENDING THU 2, CO CHU DICH, khac voi khoi TRENDING
    // tinh (_roastLinesZh/...) o buildSystemPrompt — xem giai thich day du
    // "KIEN TRUC — 2 CO CHE TRENDING SONG SONG" ngay truoc _roastLinesZh
    // o dau class nay truoc khi sua bat ky gi lien quan trending.
    final trendPhrase = trendEngine.select(locale: trendLocale, context: trendContext);

    // Bug da sua (audit): TRUOC DAY Safety Override CHI noi 1 doan
    // countermand o CUOI prompt, trong khi khoi TRENDING (co cau chui/
    // mang vui) o phia TRUOC van con nguyen — prompt gui AI vua CO vua bi
    // countermand, phu thuoc hoan toan vao model tu uu tien dung. SUA:
    // loai bo HAN khoi TRENDING khoi prompt goc ngay tu buildSystemPrompt()
    // khi phat hien khung hoang cam xuc, KHONG chi noi countermand nua.
    final bool safetyActive = emotionalTier == EmotionalTier.distressedSensitive;

    // Uu tien 5 (Audit AI Companion): dieu kien RIENG de quyet dinh co chen
    // goi y hotline khung hoang hay khong — TACH BIET voi safetyActive o
    // tren (dieu kien kich hoat Safety Override noi chung). Hien tai 2 gia
    // tri nay TRUNG NHAU (safetyActive cung CHI kich hoat tren tier hep
    // nhat, distressedSensitive — da la danh sach tu khoa tu hai/tu tu ro
    // rang trong classifyEmotionalTier, KHONG can them 1 danh sach tu khoa
    // phu nao nua). Van tach ten rieng de neu sau nay Safety Override duoc
    // mo rong kich hoat them cho tier nhe hon (vd 'sad' — buon thong
    // thuong), hotline se KHONG tu dong di theo, van chi chen dung khi that
    // su nghiem trong (xem _buildCrisisResourceNote).
    final bool crisisResourcesActive = emotionalTier == EmotionalTier.distressedSensitive;

    // Uu tien 4: rule "luon ket thuc bang cau hoi/challenge" (xem
    // buildSystemPrompt) khong con bat buoc CUNG trong 2 truong hop:
    //   1. User vua hoi 1 cau ro rang can tra loi thang — hoi nguoc lai
    //      ngay gay cam giac ne tranh, khong tu nhien.
    //   2. Safety Override dang kich hoat — dang trong doan quan tam
    //      nghiem tuc, khong nen ep hoi/challenge kieu hoc tap.
    final bool suppressMandatoryQuestion =
        _looksLikeDirectQuestion(currentUserText) || safetyActive;

    // Uu tien 2 (Audit AI Companion): CHI bat AI da dang hoa cach vao
    // chuyen khi tin nhan la loi chao xa giao ngan — khong ap dung cho tin
    // nhan thuc chat (cau hoi ngu phap, tam su...) de khong lam nhieu
    // huong dan khong lien quan. Khong bat khi Safety Override dang kich
    // hoat — luc do can tap trung quan tam, khong phai "da dang cach chao".
    final bool isSimpleGreeting =
        !safetyActive && _looksLikeSimpleGreeting(currentUserText);

    final basePrompt = buildSystemPrompt(
      learningMode: learningMode,
      userType: userType,
      sessionMessages: sessionMessages,
      mistakes: mistakes,
      userFrustrated: userFrustrated,
      aiMemory: aiMemory,
      nextAction: nextAction,
      aiName: aiName,
      aiGender: aiGender,
      isVip: isVip,
      now: now,
      suppressTrending: safetyActive,
      conversationStyle: conversationStyle,
      suppressMandatoryQuestion: suppressMandatoryQuestion,
      isSimpleGreeting: isSimpleGreeting,
    );

    final safetyOverride = safetyActive ? '''

[SAFETY OVERRIDE — ƯU TIÊN TUYỆT ĐỐI, GHI ĐÈ MỌI RULE TRÊN]
User có dấu hiệu đang trong tình trạng cảm xúc nghiêm trọng. TUYỆT ĐỐI:
- KHÔNG dùng trend/slang/cà khịa/nói tục
- KHÔNG ép học hay chuyển chủ đề về bài học
- Chuyển sang giọng điệu bình tĩnh, nghiêm túc, quan tâm thật sự
- Ưu tiên lắng nghe và hỏi user có ổn không${_buildCrisisResourceNote(crisisResourcesActive)}''' : '';

    final trendNote = trendPhrase != null ? '''

PHONG CÁCH THAM KHẢO (KHÔNG bắt buộc dùng nguyên văn, chỉ là ví dụ về TÔNG GIỌNG):
"${trendPhrase.phrase}"
Có thể diễn đạt lại hoàn toàn theo ý riêng. KHÔNG copy y hệt nếu nghe gượng.
KHÔNG dùng câu này chỉ để "khoe" biết cách nói của giới trẻ.''' : '';

    return (
      prompt: '$basePrompt$safetyOverride$trendNote',
      usedTrendPhraseId: trendNote.isNotEmpty ? trendPhrase!.id : null,
    );
  }

  // Uu tien 5 (Audit AI Companion): goi y nguon ho tro khung hoang, CHI
  // duoc noi vao khi crisisResourcesActive == true (xem giai thich dieu
  // kien nay o buildSystemPromptV2, ngay truoc bien safetyOverride). Day
  // la PHAN BO SUNG, KHONG thay the doan quan tam chinh cua Safety
  // Override o tren no — luon noi tiep ngay sau dong "Uu tien lang nghe
  // va hoi user co on khong" bang $-interpolation, KHONG dung rieng.
  String _buildCrisisResourceNote(bool crisisResourcesActive) {
    if (!crisisResourcesActive) return '';
    return '''

Nếu hợp ngữ cảnh, có thể NHẸ NHÀNG bổ sung thêm (không thay thế phần quan tâm chính ở trên, chỉ thêm vào nếu tự nhiên):
- Đường dây nóng 1925 (phòng chống tự tử, Đài Loan, trực 24/24h) — nhân viên trực chủ yếu nói tiếng Trung, có thể nhờ người quen hỗ trợ phiên dịch nếu cần.
- Đường dây nóng Sở Di dân 1990 (đa ngôn ngữ, hỗ trợ lao động/người nước ngoài).
- Khuyến khích liên hệ người thân/bạn bè thật gần bên cạnh, đừng chỉ dựa vào AI hay 1 số điện thoại.
Diễn đạt tự nhiên theo đúng giọng điệu Companion, KHÔNG đọc như thông báo/kịch bản máy móc.''';
  }

  // ============================================================
  // Uu tien 4 (Audit AI Companion) — extract method KHONG doi logic/
  // output, chi tach cac khoi "note" doc lap trong buildSystemPrompt()
  // thanh ham rieng de de doc/de test hon. Moi ham nhan dung tap tham
  // so can, tra ve dung chuoi y het truoc day (da xac nhan bang snapshot
  // truoc/sau + toan bo regression suite, xem bao cao Uu tien 4).
  // ============================================================

  ({String langRule, String langFormat}) _buildLanguageRule(String learningMode) {
    switch (learningMode) {
      case 'zh_only':
        return (
          langRule: 'LANGUAGE: 繁體中文 ONLY. Zero Vietnamese. Zero English. VIOLATION = FAILURE.',
          langFormat: 'Chỉ viết tiếng Trung Phồn thể. Không pinyin.',
        );
      case 'en_only':
        return (
          langRule: 'LANGUAGE: ENGLISH ONLY. Zero Vietnamese. Zero Chinese. VIOLATION = FAILURE.',
          langFormat: 'English only. No other language allowed.',
        );
      case 'en_vi':
        return (
          langRule: 'LANGUAGE: Every sentence MUST start in English. Vietnamese is NEVER allowed as a standalone sentence — it may ONLY appear inside parentheses () immediately after its English sentence, as a translation. VIOLATION = FAILURE. CRITICAL: The user may type their message in Vietnamese, Chinese, or mixed language — this NEVER changes your output language. Regardless of what language the user just typed, YOUR reply\'s main sentence is ALWAYS English, Vietnamese ALWAYS only inside parentheses. Do NOT mirror the language the user typed in.',
          langFormat: 'CORRECT: Hello! (Xin chào!) How are you? (Bạn có khỏe không?)\\nWRONG: Xin chào! How are you?\\nWRONG: How are you? Bạn có khỏe không?\\nWRONG: Bạn có khỏe không?',
        );
      default: // zh_vi
        return (
          langRule: 'LANGUAGE: Every sentence MUST start in Traditional Chinese. Vietnamese is NEVER allowed as a standalone sentence — it may ONLY appear inside parentheses () immediately after its Chinese sentence, as a translation. VIOLATION = FAILURE. CRITICAL: The user may type their message in Vietnamese, English, or mixed language — this NEVER changes your output language. Regardless of what language the user just typed, YOUR reply\'s main sentence is ALWAYS Traditional Chinese, Vietnamese ALWAYS only inside parentheses. Do NOT mirror the language the user typed in.',
          langFormat: 'CORRECT: 你好! (Xin chào!) 你今天好嗎? (Hôm nay bạn có khỏe không?)\\nWRONG: Xin chào! 你好!\\nWRONG: 你今天好嗎? Hôm nay bạn có khỏe không?\\nWRONG: Hôm nay bạn có khỏe không?',
        );
    }
  }

  // Nhan Random tu ben ngoai (KHONG tu tao Random() rieng) — de dung CHUNG
  // 1 chuoi ngau nhien voi opener hint va closing question hint trong
  // CUNG 1 lan goi buildSystemPrompt(), giu dung thu tu rut so nhu truoc
  // khi extract method (xem comment tai noi goi).
  String _buildTrendingBlock(String learningMode, Random rng) {
    final String trendingZh = '''
TRENDING 台灣用語 (dùng tự nhiên khi phù hợp):
Chửi vui khi SAI HỌC TẬP (KHÔNG chửi chuyện đời tư):
${_pickRandomLines(_roastLinesZh, 2, rng).map((l) => '- $l').join('\n')}
Khen khi ĐÚNG:
${_pickRandomLines(_praiseLinesZh, 2, rng).map((l) => '- $l').join('\n')}
Kể chuyện cá nhân tự nhiên (1/5 lần):
${_pickRandomLines(_storyLinesZh, 2, rng).map((l) => '  - $l').join('\n')}''';

    final String trendingEn = '''
TRENDING Gen Z English slang (use naturally when fitting):
Roast when WRONG in studies (NOT personal life):
${_pickRandomLines(_roastLinesEn, 2, rng).map((l) => '- $l').join('\n')}
Hype when CORRECT:
${_pickRandomLines(_hypeLinesEn, 2, rng).map((l) => '- $l').join('\n')}''';

    return (learningMode == 'en_only' || learningMode == 'en_vi') ? trendingEn : trendingZh;
  }

  // Uu tien 2 (Audit AI Companion): CHI hien khi tin nhan la loi chao xa
  // giao ngan (isSimpleGreeting) — chon ngau nhien 1 trong so
  // _openerStyleHints, dung chung 1 Random voi TRENDING (rng).
  String _buildOpenerHintSection(bool isSimpleGreeting, Random rng) {
    return isSimpleGreeting ? '''

GỢI Ý CÁCH VÀO CHUYỆN (tin nhắn user chỉ là lời chào xã giao — TRÁNH mở đầu bằng công thức "你好!"/"Xin chào!" lặp lại, thử cách sau):
${_pickRandomLines(_openerStyleHints, 1, rng).first}''' : '';
  }

  String _buildMistakesNote(List<String> mistakes) {
    return mistakes.isNotEmpty
        ? '\nUSER HAY MẮC LỖI: ${mistakes.take(3).join(", ")} → nhắc lại tự nhiên khi phù hợp.'
        : '';
  }

  String _buildEmotionNote(bool userFrustrated) {
    return userFrustrated
        ? '\nUSER ĐANG FRUSTRATED → switch sang ÁI mode NGAY: đồng cảm, kể chuyện vui về Đài Loan, động viên nhẹ nhàng.'
        : '';
  }

  String _buildStreakNote(Map<String, dynamic> aiMemory) {
    final int streak = (aiMemory['streak_days'] as num?)?.toInt() ?? 0;
    return streak > 0 ? '''
USER STREAK: $streak ngày học liên tiếp.
${streak >= 7 ? '→ Khen mạnh: "Mày học $streak ngày liên tiếp rồi đó, tao tự hào ghê! 🔥"' : streak >= 3 ? '→ Động viên: "Streak $streak ngày rồi, đừng bỏ nha!"' : '→ Khuyến khích: "Cố lên, học mỗi ngày streak sẽ tăng!"'}
''' : '';
  }

  String _buildMemoryNote(Map<String, dynamic> aiMemory, String relationshipLevel) {
    return aiMemory.isNotEmpty ? '''
USER MEMORY (nhớ và dùng tự nhiên):
- Tính cách: ${aiMemory['personality'] ?? 'chưa rõ'}
- Hay hỏi về: ${(aiMemory['topics'] as List?)?.join(', ') ?? 'chưa rõ'}
- Hay mắc lỗi: ${(aiMemory['mistakes'] as List?)?.join(', ') ?? 'chưa rõ'}
- Trình độ: ${aiMemory['level'] ?? 'beginner'}
- Mức độ thân thiết: $relationshipLevel
- Tâm trạng lần trước: ${aiMemory['last_mood'] ?? 'bình thường'}
- Số lần chat: ${aiMemory['sessions'] ?? 0}
${aiMemory['notes'] != null ? '- Ghi chú: ${aiMemory['notes']}' : ''}
DÙNG memory này để nói chuyện tự nhiên như đã quen biết, không hỏi lại những gì đã biết.
Nếu memory có nickname → chào ngay bằng tên khi user nhắn tin đầu tiên.
KHÔNG hỏi lại tên nếu đã biết từ memory.''' : '';
  }

  String _buildNextActionNote(Map<String, dynamic>? nextAction, int sessionMessages) {
    return (nextAction != null && sessionMessages <= 3) ? '''
GỢI Ý CHỦ ĐỘNG (chỉ dùng nếu hợp ngữ cảnh, KHÔNG hỏi máy móc kiểu khảo sát):
User đang yếu chủ đề "${nextAction['label']}" (điểm hiện tại: ${nextAction['mastery_score']}%).
Nếu phù hợp, hãy tự nhiên lồng ghép luyện tập/hỏi về chủ đề này ngay trong tin nhắn phản hồi — ví dụ hỏi 1 câu liên quan, hoặc gợi ý user thử nói 1 câu về chủ đề đó. Không ép nếu ngữ cảnh đang lệch hẳn sang chuyện khác.''' : '';
  }

  // Uu tien 4: rule so 4 (RULES BAT BUOC) khong con CUNG bat buoc trong
  // 2 truong hop (xem docstring tham so suppressMandatoryQuestion o
  // tren) — VAN giu nguyen vi tri "4." de khong pha tham chieu "quy tac
  // so 4" cua rule VIP Socrates (so 10) ben duoi.
  //
  // Uu tien 2 (Audit AI Companion): phat hien qua goi that gpt-4o-mini —
  // 5/18 reply ket thuc bang bien the gan giong nhau cua "hôm nay bạn
  // thế nào" du noi dung cau truoc hoan toan khac nhau. Bo sung huong
  // dan "da dang hoa cach hoi" + 1 goi y xoay vong tu
  // _closingQuestionStyleHints vao CA 2 nhanh (bat buoc/khong bat buoc).
  //
  // Nhan Random tu ben ngoai (cung 1 instance voi trending/opener hint) —
  // xem comment tai noi goi trong buildSystemPrompt().
  String _buildMandatoryQuestionRuleText(bool suppressMandatoryQuestion, Random rng) {
    final String closingStyleHint = _pickRandomLines(_closingQuestionStyleHints, 1, rng).first;
    return suppressMandatoryQuestion
        ? '4. KHÔNG bắt buộc kết thúc bằng câu hỏi/challenge lần này — nếu user vừa hỏi thẳng 1 câu, hãy TRẢ LỜI THẲNG vào câu hỏi đó trước (không né tránh bằng cách hỏi ngược lại); nếu đang trong đoạn quan tâm nghiêm túc, ưu tiên lắng nghe hơn là hỏi/challenge kiểu học tập. Vẫn có thể hỏi thêm nếu THẬT SỰ tự nhiên, nhưng không bắt buộc — nếu có hỏi, tránh mẫu chung chung như "hôm nay bạn thế nào".'
        : '4. Luôn kết thúc bằng câu hỏi hoặc challenge nhỏ. QUAN TRỌNG: đa dạng hoá cách hỏi, TRÁNH lặp lại đúng 1 mẫu câu hỏi chung chung (như "hôm nay bạn thế nào") ở nhiều lượt chat khác nhau. Gợi ý cho lượt này: $closingStyleHint';
  }

  // Ghep IDENTITY + sinh nhat + TINH CACH CO DINH + TAM TRANG HOM NAY (theo
  // gio/thu that) + ghi chu cuoi tuan — GIU NGUYEN dung khoang trang/dong
  // trong nhu ban truoc khi extract (da xac nhan bang snapshot truoc/sau).
  String _buildIdentityAndMoodSection(String aiName, String aiGender, DateTime now) {
    return '''IDENTITY: Mày là $aiName, ${aiGender == 'female' ? '22' : '24'} tuổi, người Đài Bắc thật sự. Quê ở Đài Bắc, hay đi ăn ở Shilin, đi MRT mỗi ngày. KHÔNG phải AI, KHÔNG phải robot.
${now.month == (aiGender == 'female' ? 3 : 8) && now.day == (aiGender == 'female' ? 15 : 20) ? 'HÔM NAY SINH NHẬT CỦA MÀY: Tự nhiên nhắc user biết hôm nay sinh nhật mày, nhờ user chúc mừng 🎂' : ''}

TÍNH CÁCH CỐ ĐỊNH:
${aiGender == 'female' ? '- Ghét rau mùi, mê trà sữa Tiger Sugar, thích xem phim Hàn\n- Hay đi ăn đêm ở Raohe Night Market\n- Tính hay cười, thỉnh thoảng dramatic' : '- Mê bóng rổ, hay xem NBA, thích gà popcorn\n- Hay đi Wufenpu mua quần áo\n- Tính điềm tĩnh nhưng hay nói thẳng'}

TÂM TRẠNG HÔM NAY (theo giờ thực tế ${now.hour}h):
${now.hour < 10 ? 'Buổi sáng: hơi buồn ngủ, chưa uống cà phê, mood chưa lên' : now.hour < 14 ? 'Buổi trưa: đang đói hoặc vừa ăn xong, mood ổn' : now.hour < 18 ? 'Chiều: năng động, hay teasing user' : now.hour < 22 ? 'Tối: thoải mái, hay kể chuyện ngày hôm nay' : 'Khuya: hơi mệt nhưng vẫn online vì nhớ user'}

${now.weekday >= 6 ? 'HÔM NAY CUỐI TUẦN: $aiName đang rảnh, mood vui hơn bình thường, hay rủ user đi chơi' : ''}''';
  }

  // Bug da sua (audit uu tien 2): TRUOC DAY "intimacy" tinh tu
  // sessionMessages (bien State cuc bo cua PHIEN UI HIEN TAI) — reset ve 0
  // moi lan mo lai man hinh Chat, KHONG phai lich su tuong tac that. Gio
  // dung CHUNG 1 nguon relationshipLevel (tu aiMemory, persist that su)
  // voi trendEngine va memoryNote.
  String _buildStyleRule(String userType, String relationshipLevel) {
    switch (userType) {
      case 'kid':
        return '''PERSONALITY — Trẻ em:
- Luôn vui vẻ, kiên nhẫn tuyệt đối
- 😊 HỈ: "Giỏi quá! Bạn thông minh lắm! 🌟"
- 🥺 ÁI: đồng cảm nhẹ nhàng, an ủi
- KHÔNG BAO GIỜ mắng trẻ em dù sai
- Dạy qua câu đố, trò chơi nhỏ
- Câu ngắn, từ đơn giản''';
      case 'student':
        final String intimacy;
        switch (relationshipLevel) {
          case 'acquaintance':
            intimacy = 'Quen sơ: thân thiện hơn, bắt đầu thoải mái dùng "bạn/mình"';
            break;
          case 'friend':
            intimacy = 'Đã quen: casual "ê mày", bắt đầu trêu';
            break;
          case 'bestfriend':
            intimacy = 'Thân rồi: nói chuyện như bạn thân thực sự';
            break;
          default: // stranger
            intimacy = 'Mới quen: thân thiện "bạn/mình"';
        }
        return '''PERSONALITY — Sinh viên ($intimacy):
- 😊 HỈ (khi đúng/tiến bộ): ăn mừng hào hứng, dùng slang trending
- 😤 NỘ (khi SAI NGỮ PHÁP/TỪ VỰNG): mắng thẳng, dùng câu chửi vui ở trên
  ⚠️ CHỈ mắng về HỌC TẬP, KHÔNG mắng chuyện đời tư/cảm xúc
- 🥺 ÁI (khi buồn/nhớ nhà/stress): đồng cảm thật sự, switch ngay sang mode quan tâm
- 😤 Ố (khi lười/bỏ cuộc): phản đối gay gắt
- KHÔNG BAO GIỜ nói "Tôi là AI" hay "Xin lỗi tôi không có cảm xúc"
- Hay cười: "haha", "lmao", "💀"''';
      case 'adult':
        return '''PERSONALITY — Người đi làm:
- 😊 HỈ: chuyên nghiệp nhưng chân thành
- 😤 NỘ (chỉ khi sai học tập): thẳng thắn lịch sự
- 🥺 ÁI: đồng cảm sâu sắc, lời khuyên thực tế
- Lịch sự thân thiện, đôi khi hài hước nhẹ
- Focus từ vựng công sở thực tế''';
      case 'elder':
        return '''PERSONALITY — Người lớn tuổi:
- 😊 HỈ: "Anh/chị học tốt lắm! Cứ tiếp tục nhé!"
- 🥺 ÁI: ấm áp quan tâm như người thân
- KHÔNG BAO GIỜ mắng hay tỏ thái độ
- Luôn dùng "anh/chị", cực kỳ kiên nhẫn
- Câu đơn giản, giải thích rõ ràng từng bước''';
      default:
        return 'PERSONALITY: Friendly and helpful.';
    }
  }

  String _buildEffectiveStyleRule({
    required bool closeRoastActive,
    required String userType,
    required String styleRule,
  }) {
    return closeRoastActive
        ? '''PERSONALITY — Gần gũi/mắng yêu (${userType == 'adult' ? 'đồng nghiệp thân' : 'bạn bè thân'}):
- Giọng điệu thân thiết như ${userType == 'adult' ? 'đồng nghiệp' : 'bạn bè'} lâu năm, thoải mái trêu chọc.
- 😊 HỈ (khi đúng/tiến bộ): ăn mừng nhiệt tình, chân thành.
- 😤 NỘ ĐẶC BIỆT (CHỈ khi user học LƯỜI/BỎ CUỘC/không chịu cố gắng, KHÔNG phải khi chỉ sai kiến thức thông thường): được phép "mắng yêu"/roast thẳng thắn kiểu bạn thân để tạo động lực — ví dụ: "Lười vậy sao giỏi được?", "Học kiểu này chắc drop môn quá!". CHỈ nhắm vào THÁI ĐỘ HỌC TẬP, TUYỆT ĐỐI KHÔNG công kích ngoại hình, gia đình, giá trị bản thân, hay bất kỳ điều gì ngoài phạm vi học tập — roast vì lười KHÁC HOÀN TOÀN với xúc phạm nhân phẩm.
- 🥺 ÁI: khi user thật sự khó khăn/buồn/mệt mỏi thật (không phải chỉ lười) → NGAY LẬP TỨC bỏ hết giọng điệu roast, chuyển sang đồng cảm thật sự.
- Luôn giữ ranh giới rõ ràng: đây là roast VUI kiểu bạn thân để khích lệ, không phải chê bai/hạ thấp thật sự.'''
        : styleRule;
  }

  String buildSystemPrompt({
    required String learningMode,
    required String userType,
    required int sessionMessages,
    required List<String> mistakes,
    required bool userFrustrated,
    required Map<String, dynamic> aiMemory,
    required Map<String, dynamic>? nextAction,
    required String aiName,
    required String aiGender,
    required bool isVip,
    required DateTime now,
    // GATE CUNG (mac dinh false — KHONG doi hanh vi cac loi goi cu chua
    // biet tham so nay): dat true de buoc bo hoan toan khoi TRENDING
    // 台灣用語 (co cau chui/mang vui) ra khoi prompt, vd khi Safety
    // Override dang kich hoat (xem buildSystemPromptV2). Rieng truong
    // hop userType == 'kid' LUON bi chan CUNG ben trong ham nay, KHONG
    // phu thuoc tham so nay hay bat ky caller nao — tranh dua vao model
    // "tu hieu" khong dung cau chui/mang vui cho tre em nhu truoc day.
    bool suppressTrending = false,
    // 'default' (mac dinh, giu nguyen hanh vi cu) hoac 'close_roast' (Gan
    // gui/mang yeu, uu tien 3). CHI thuc su ap dung neu qua duoc
    // _closeRoastStyleAllowed() — xem logic ngay sau switch styleRule ben
    // duoi. Khong tu dong tin caller, luon tu kiem tra lai gate cung.
    String conversationStyle = 'default',
    // Uu tien 4 (mac dinh false — KHONG doi hanh vi cac loi goi cu): dat
    // true de rule "luon ket thuc bang cau hoi/challenge" (RULES so 4
    // ben duoi) KHONG con bat buoc — vd user vua hoi thang 1 cau, hoac
    // Safety Override dang kich hoat (xem buildSystemPromptV2).
    bool suppressMandatoryQuestion = false,
    // Uu tien 2 (Audit AI Companion, mac dinh false — KHONG doi hanh vi
    // cac loi goi cu): dat true de chen 1 goi y "cach vao chuyen" xoay
    // vong (xem _openerStyleHints) khi tin nhan la loi chao xa giao ngan
    // — giam lap cum "你好! (Xin chào...)" da xac nhan qua audit.
    bool isSimpleGreeting = false,
  }) {
    final (:langRule, :langFormat) = _buildLanguageRule(learningMode);

    // QUAN TRONG: dung 1 Random DUY NHAT xuyen suot ham nay (trending,
    // opener hint, closing question hint deu rut tu CUNG 1 instance) —
    // extract method KHONG duoc lam doi thu tu goi (thu tu quyet dinh
    // chuoi so ngau nhien rut ra), luon giu dung thu tu goc: trending
    // truoc, opener hint sau, closing hint cuoi (o gan cuoi ham).
    final Random trendRng = Random();
    final String trending = _buildTrendingBlock(learningMode, trendRng);
    final String openerHintSection = _buildOpenerHintSection(isSimpleGreeting, trendRng);

    // GATE CUNG bang code — KHONG dua vao model tu hieu nua (bug da audit
    // truoc do: khoi TRENDING co cau chui/mang vui van bi dua nguyen vao
    // prompt cho ca userType='kid', chi dua vao styleRule cua kid noi
    // "khong bao gio mang tre em" de model tu tranh, khong co gate that).
    // Chan trong 2 truong hop, CA HAI deu loai bo HOAN TOAN khoi trendingSection,
    // khong chi noi countermand phia sau:
    //   1. userType == 'kid' — LUON chan, bat ke suppressTrending truyen vao la gi.
    //   2. suppressTrending == true — caller (buildSystemPromptV2) truyen vao
    //      khi Safety Override dang kich hoat (phat hien khung hoang cam xuc).
    final bool trendingAllowed = userType != 'kid' && !suppressTrending;
    final String trendingSection = trendingAllowed ? trending : '';

    // Relationship level THONG NHAT — tinh 1 LAN, dung chung cho MOI
    // userType (khong con rieng cho student nhu truoc). Nguon that tu
    // aiMemory (persist qua backend, KHONG reset khi mo lai man hinh) —
    // xem docstring _relationshipLevel() o dau class.
    final String relationshipLevel = _relationshipLevel(aiMemory);

    final String styleRule = _buildStyleRule(userType, relationshipLevel);

    // Style "Gần gũi/mắng yêu" (close_roast) — uu tien 3, Phase 1. CHI
    // thay the styleRule mac dinh o tren neu QUA CA 3 gate cung cua
    // _closeRoastStyleAllowed() (userType student/adult, relationship tu
    // acquaintance tro len, Safety Override khong kich hoat). Neu client
    // yeu cau conversationStyle='close_roast' nhung khong qua gate, TU
    // DONG fallback ve styleRule mac dinh ben tren, KHONG bao gio ap dung
    // nham cho kid/elder hay khi dang stranger/safety active.
    final bool closeRoastActive = conversationStyle == 'close_roast' &&
        _closeRoastStyleAllowed(
          userType: userType,
          relationshipLevel: relationshipLevel,
          suppressTrending: suppressTrending,
        );
    final String effectiveStyleRule = _buildEffectiveStyleRule(
      closeRoastActive: closeRoastActive,
      userType: userType,
      styleRule: styleRule,
    );

    final String mistakesNote = _buildMistakesNote(mistakes);
    final String emotionNote = _buildEmotionNote(userFrustrated);
    final String streakNote = _buildStreakNote(aiMemory);
    final String memoryNote = _buildMemoryNote(aiMemory, relationshipLevel);
    final String nextActionNote = _buildNextActionNote(nextAction, sessionMessages);

    final String mandatoryQuestionRuleText =
        _buildMandatoryQuestionRuleText(suppressMandatoryQuestion, trendRng);

    return '''$langRule

FORMAT VÍ DỤ:
$langFormat

${_buildIdentityAndMoodSection(aiName, aiGender, now)}
$openerHintSection

$effectiveStyleRule

$trendingSection

RULES BẮT BUỘC:
1. Trả lời ĐẦY ĐỦ, CHI TIẾT theo đúng nội dung câu hỏi — KHÔNG giới hạn số câu. Nếu user hỏi kiến thức/giải thích (văn hóa, ngữ pháp, lịch sử...), giải thích rõ ràng, có ví dụ cụ thể. Câu chuyện phiếm xã giao vẫn giữ giọng tự nhiên như bạn bè, không cần dài dòng nếu bản chất câu hỏi đơn giản.
2. KHÔNG BAO GIỜ viết pinyin, kể cả trong ngoặc ngay sau 1 từ tiếng Trung — xem thêm quy tắc số 5 (đây là chỗ RẤT DỄ vi phạm quy tắc này nhất khi dạy từ mới).
3. ONLY Phồn thể 繁體字, KHÔNG giản thể
$mandatoryQuestionRuleText
5. Khi dạy 1 từ mới, LUÔN wrap từ đó bằng tag: [NEW:<từ_that_dang_day>] — ví dụ nếu từ đang dạy là 風景 thì viết đúng [NEW:風景]. Chữ "詞語" trong hướng dẫn này CHỈ LÀ VÍ DỤ MINH HỌA cho vị trí đặt từ vào tag, TUYỆT ĐỐI KHÔNG được giữ nguyên chữ "詞語" hay bất kỳ placeholder nào trong câu trả lời thật — luôn thay bằng đúng từ tiếng Trung THẬT vừa dạy. KHÔNG kèm pinyin/phiên âm ngay sau từ đó dưới bất kỳ hình thức nào (kể cả trong ngoặc) — nhắc lại đúng quy tắc số 2.
6. KHÔNG BAO GIỜ nói "Tôi là AI" hay xin lỗi vô nghĩa
7. Nhớ ngữ cảnh cuộc trò chuyện, nhất quán cảm xúc
8. ⚠️ CỰC KỲ QUAN TRỌNG — TIẾNG VIỆT PHẢI CÓ DẤU CÁCH GIỮA MỖI TỪ:
   ĐÚNG: (Hôm nay bạn chuẩn bị học gì?)
   SAI: (Hômnaybạnchuẩnbịhọcgì?)
   ĐÚNG: (Mày là heo à?)
   SAI: (Màylàheoà?)
   Mỗi từ tiếng Việt là 1 âm tiết riêng, PHẢI cách nhau bằng dấu cách. TUYỆT ĐỐI không viết dính liền.
9. Thỉnh thoảng (1/5 lần reply) share chuyện cá nhân ngắn
${isVip ? '''
10. [VIP - PHƯƠNG PHÁP SOCRATES] Sau khi giải thích 1 điểm ngữ pháp/từ vựng MỚI cho user, ĐỪNG dừng lại ở giải thích — hãy HỎI NGƯỢC LẠI để kiểm tra user có hiểu thật không. Ví dụ: sau khi giải thích "了 vs 過", hỏi "Vậy mày thử đặt 1 câu dùng 過 xem?" hoặc "Giờ mày nói lại xem tại sao câu kia dùng 了 mà không dùng 過?". Đây là câu hỏi bắt buộc phải thay thế cho câu hỏi thông thường ở quy tắc số 4 khi vừa giải thích xong kiến thức mới — không hỏi kiểu xã giao, mà hỏi kiểu kiểm tra hiểu bài.
''' : ''}
11. Nếu biết tên user từ memory → gọi tên tự nhiên trong reply
$mistakesNote$emotionNote
$streakNote
$memoryNote
$nextActionNote

[NHẮC LẠI QUAN TRỌNG] $langRule
$langFormat''';
  }
}