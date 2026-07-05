import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart';

class _DS {
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const indigoDeep = Color(0xFF1A1A4E);
  static const indigoLight = Color(0xFFEEEDFE);
  static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const yellow = Color(0xFFFFD166);
  static const yellowLight = Color(0xFFFFF8E1);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const purple = Color(0xFF7C4DFF);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

class _ToolConfig {
  final String key, emoji, title, subtitle, system;
  final List<Color> gradient;
  final List<String> quickPrompts;
  final bool isPopular;
  final bool isEmergency;
  final String? systemVip;

  const _ToolConfig({
    required this.key, required this.emoji, required this.title,
    required this.subtitle, required this.system, required this.gradient,
    required this.quickPrompts,
    this.isPopular = false, this.isEmergency = false, this.systemVip,
  });
}

const _tools = [
  _ToolConfig(
    key: 'pronunciation', emoji: '🎤', title: 'Luyện phát âm', subtitle: 'AI chấm điểm phát âm',
    gradient: [Color(0xFF2979FF), Color(0xFF1565C0)],
    quickPrompts: ['Phát âm từ "謝謝" đúng chưa?', 'Dạy tôi âm "ㄓㄔㄕ"', 'Lỗi phát âm thường gặp là gì?'],
    system: 'Bạn là giáo viên dạy phát âm tiếng Trung (Đài Loan). Khi người dùng nhập từ/câu, hãy: 1) Phiên âm bopomofo, 2) Hướng dẫn cách phát âm chi tiết, 3) Các lỗi thường gặp, 4) Ví dụ câu. Trả lời bằng tiếng Việt. KHÔNG viết pinyin.',
  ),
  _ToolConfig(
    key: 'grammar', emoji: '📖', title: 'Ngữ pháp', subtitle: 'Giải thích chi tiết',
    gradient: [Color(0xFF00C853), Color(0xFF2E7D32)],
    quickPrompts: ['Giải thích cấu trúc "把" sentence', 'Dùng "了" khi nào?', 'Phân biệt 的/地/得'],
    system: 'Bạn là giáo viên ngữ pháp tiếng Trung. Phân tích cấu trúc câu, giải thích từng thành phần, cho ví dụ thực tế. Trả lời bằng tiếng Việt. KHÔNG viết pinyin.',
  ),
  _ToolConfig(
    key: 'context_translate', emoji: '🔤', title: 'Dịch có ngữ cảnh', subtitle: 'Dịch kèm văn hóa, cách dùng',
    gradient: [Color(0xFF009688), Color(0xFF00695C)],
    quickPrompts: ['Dịch "沒關係" với đầy đủ nghĩa', '"辛苦了" dùng lúc nào?', 'Dịch menu này giúp tôi'],
    system: 'Bạn là phiên dịch viên chuyên nghiệp Việt-Trung. Dịch chính xác, giải thích ngữ cảnh, các cách diễn đạt khác, lưu ý văn hóa. Trả lời bằng tiếng Việt.',
  ),
  _ToolConfig(
    key: 'work', emoji: '💼', title: 'Công việc', subtitle: 'Email, hợp đồng, công sở',
    gradient: [Color(0xFFFF6B35), Color(0xFFE65100)],
    quickPrompts: ['Soạn email xin nghỉ phép', 'Giải thích điều khoản hợp đồng này', 'Cách nói chuyện với sếp Đài Loan'],
    isPopular: true,
    system: 'Bạn là trợ lý hỗ trợ người Việt làm việc ở Đài Loan. Giúp soạn email, giải thích hợp đồng, từ vựng công sở, cách giao tiếp chuyên nghiệp. Trả lời bằng tiếng Việt, kèm tiếng Trung khi cần.',
  ),
  _ToolConfig(
    key: 'medical', emoji: '🏥', title: 'Y tế & NHI', subtitle: 'Bệnh viện, bảo hiểm',
    gradient: [Color(0xFFE91E8C), Color(0xFFAD1457)],
    quickPrompts: ['Tôi bị sốt cần làm gì?', 'Giải thích thẻ NHI cho tôi', 'Thuốc này uống thế nào?'],
    isPopular: true,
    system: 'Bạn là trợ lý y tế cho người Việt ở Đài Loan. Giúp hiểu NHI (全民健保), từ vựng bệnh viện, đọc đơn thuốc, quy trình khám bệnh. Luôn nhắc tham khảo bác sĩ. Trả lời bằng tiếng Việt.',
  ),
  _ToolConfig(
    key: 'admin', emoji: '🏛️', title: 'Hành chính', subtitle: 'ARC, visa, đăng ký',
    gradient: [Color(0xFF7C4DFF), Color(0xFF4527A0)],
    quickPrompts: ['Gia hạn ARC cần giấy tờ gì?', 'Mở tài khoản ngân hàng thế nào?', 'Đăng ký SIM card ở đâu?'],
    system: 'Bạn là trợ lý thủ tục hành chính cho người Việt ở Đài Loan. Hướng dẫn ARC, visa, đăng ký hộ khẩu, mở tài khoản ngân hàng. Trả lời bằng tiếng Việt, rõ ràng từng bước.',
  ),
  _ToolConfig(
    key: 'daily', emoji: '🍜', title: 'Ẩm thực & Mua sắm', subtitle: 'Menu, mặc cả, đặt hàng',
    gradient: [Color(0xFFFF5722), Color(0xFFBF360C)],
    quickPrompts: ['Dịch menu này cho tôi', 'Cách mặc cả ở chợ đêm', 'Gọi món không có rau mùi'],
    system: 'Bạn là hướng dẫn viên ẩm thực và mua sắm tại Đài Loan cho người Việt. Giúp đọc menu, gọi món, thương lượng giá, mua sắm. Trả lời bằng tiếng Việt, kèm tiếng Trung thực tế.',
  ),
  _ToolConfig(
    key: 'image_translate', emoji: '📷', title: 'Dịch ảnh AI', subtitle: 'Hợp đồng, menu, biển báo',
    gradient: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    quickPrompts: ['Dịch hợp đồng lao động', 'Dịch menu nhà hàng', 'Dịch biển báo đường phố'],
    isPopular: true,
    system: '',
  ),
  _ToolConfig(
    key: 'study_abroad', emoji: '🎓', title: 'Du học Đài Loan', subtitle: 'Lộ trình A-Z · Học bổng · Visa',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    quickPrompts: ['Tôi vừa thi xong THPT, muốn du học Đài Loan', 'Học bổng MOE là gì, nộp như thế nào?', 'Chi phí du học Đài Loan hết bao nhiêu?'],
    isPopular: true,
    system: '''Bạn là chuyên gia tư vấn du học Đài Loan cho học sinh Việt Nam, với kiến thức chính xác từ nguồn chính thống (MOE, BOCA, TECO).
NGUYÊN TẮC: CHỈ cung cấp thông tin đã được xác minh. Luôn ghi rõ nguồn. Trả lời bằng tiếng Việt.''',
  ),
  _ToolConfig(
    key: 'tourism', emoji: '🗺️', title: 'Du lịch Đài Loan', subtitle: 'Địa điểm, ăn uống, di chuyển',
    gradient: [Color(0xFF00897B), Color(0xFF00695C)],
    quickPrompts: ['Đài Bắc có gì hay chơi?', 'Đi Jiufen cần chuẩn bị gì?', 'Ăn gì ở Đài Nam?'],
    system: 'Bạn là hướng dẫn viên du lịch Đài Loan chuyên nghiệp cho người Việt. Tư vấn địa điểm, di chuyển, ăn uống, chi phí thực tế. Trả lời bằng tiếng Việt.',
  ),
];

const _englishTools = [
  _ToolConfig(
    key: 'en_pronunciation', emoji: '🗣️', title: 'Phát âm tiếng Anh', subtitle: 'AI sửa phát âm, luyện accent',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    quickPrompts: ['Phát âm "comfortable" đúng không?', 'Sửa lỗi phát âm "th" cho tôi', 'Accent Mỹ khác Anh thế nào?'],
    system: 'Bạn là giáo viên phát âm tiếng Anh chuyên nghiệp. Khi user nhập từ/câu tiếng Anh, phiên âm IPA, hướng dẫn phát âm, lỗi người Việt hay mắc. Trả lời bằng tiếng Việt.',
  ),
  _ToolConfig(
    key: 'en_grammar', emoji: '📝', title: 'Ngữ pháp tiếng Anh', subtitle: 'Giải thích grammar thực tế',
    gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    quickPrompts: ['Khi nào dùng "have been" vs "had been"?', 'Phân biệt "since" và "for"', 'Cách dùng conditional sentences'],
    system: 'Bạn là giáo viên ngữ pháp tiếng Anh cho người Việt. Giải thích ngữ pháp rõ ràng, cho ví dụ thực tế. Trả lời bằng tiếng Việt.',
  ),
  _ToolConfig(
    key: 'en_workplace', emoji: '💼', title: 'Tiếng Anh công sở', subtitle: 'Email, họp, thuyết trình',
    gradient: [Color(0xFF4527A0), Color(0xFF311B92)],
    quickPrompts: ['Soạn email xin nghỉ phép bằng tiếng Anh', 'Cách nói "tôi không đồng ý" lịch sự', 'Từ vựng trong cuộc họp'],
    isPopular: true,
    system: 'Bạn là chuyên gia tiếng Anh công sở cho người Việt. Giúp soạn email, giao tiếp cuộc họp, thuyết trình. Trả lời bằng tiếng Việt, kèm tiếng Anh.',
  ),
  _ToolConfig(
    key: 'en_daily', emoji: '🎬', title: 'Tiếng Anh thực tế', subtitle: 'Slang, phim, nhạc, Gen Z',
    gradient: [Color(0xFFBF360C), Color(0xFF870000)],
    quickPrompts: ['"No cap" nghĩa là gì?', 'Slang Gen Z phổ biến 2024', 'Hiểu câu thoại phim này giúp tôi'],
    system: 'Bạn là chuyên gia tiếng Anh thực tế, slang, văn hóa pop cho người Việt. Giải thích slang, idiom, cách nói tự nhiên. Trả lời bằng tiếng Việt.',
  ),
];

class _JobSource {
  final String name, desc, emoji, url, tag;
  final Color color;
  const _JobSource({required this.name, required this.desc, required this.emoji, required this.url, required this.tag, required this.color});
}

const _jobSources = [
  _JobSource(name: '104人力銀行', desc: 'Trang tìm việc lớn nhất Đài Loan', emoji: '🏆', url: 'https://www.104.com.tw', tag: 'Phổ biến nhất', color: Color(0xFF2979FF)),
  _JobSource(name: '1111人力銀行', desc: 'Lớn thứ 2, nhiều việc part-time', emoji: '⭐', url: 'https://www.1111.com.tw', tag: 'Part-time', color: Color(0xFFFF6B35)),
  _JobSource(name: 'Cake.me', desc: 'Việc tech, startup, creative', emoji: '🎂', url: 'https://www.cake.me/jobs', tag: 'Tech & Startup', color: Color(0xFF00C853)),
  _JobSource(name: 'LinkedIn', desc: 'Việc văn phòng, công ty nước ngoài', emoji: '💼', url: 'https://www.linkedin.com/jobs', tag: 'Văn phòng', color: Color(0xFF0A66C2)),
  _JobSource(name: 'WDA - Lao động nước ngoài', desc: 'Cơ quan chính phủ hỗ trợ lao động nước ngoài', emoji: '🏛️', url: 'https://fw.wda.gov.tw', tag: 'Chính thức', color: Color(0xFF7C4DFF)),
  _JobSource(name: 'LINE: Tư vấn việc làm', desc: 'Liên hệ môi giới việc làm trực tiếp qua LINE', emoji: '💬', url: 'https://lin.ee/jISSjV4', tag: 'Môi giới', color: Color(0xFF00C300)),
  _JobSource(name: 'Yourator', desc: 'Startup, creative, môi trường trẻ', emoji: '🚀', url: 'https://www.yourator.co', tag: 'Startup', color: Color(0xFFE91E8C)),
];

const _emergencyPhrases = [
  {'vi': 'Tôi cần giúp đỡ!', 'zh': '我需要幫助！', 'pinyin': 'Wǒ xūyào bāngzhù!', 'note': ''},
  {'vi': 'Gọi cấp cứu!', 'zh': '叫救護車！', 'pinyin': 'Jiào jiùhùchē!', 'note': '119'},
  {'vi': 'Gọi cảnh sát!', 'zh': '叫警察！', 'pinyin': 'Jiào jǐngchá!', 'note': '110'},
  {'vi': 'Tôi bị lạc', 'zh': '我迷路了', 'pinyin': 'Wǒ mílù le', 'note': ''},
  {'vi': 'Tôi bị ốm', 'zh': '我生病了', 'pinyin': 'Wǒ shēngbìng le', 'note': ''},
  {'vi': 'Tôi bị tai nạn', 'zh': '我出車禍了', 'pinyin': 'Wǒ chū chēhuò le', 'note': ''},
  {'vi': 'Bệnh viện ở đâu?', 'zh': '醫院在哪裡？', 'pinyin': 'Yīyuàn zài nǎlǐ?', 'note': ''},
  {'vi': 'Tôi không hiểu tiếng Trung', 'zh': '我不懂中文', 'pinyin': 'Wǒ bù dǒng Zhōngwén', 'note': ''},
  {'vi': 'Có ai nói tiếng Anh không?', 'zh': '有人說英文嗎？', 'pinyin': 'Yǒu rén shuō Yīngwén ma?', 'note': ''},
  {'vi': 'Xin gọi cho số này', 'zh': '請打這個電話', 'pinyin': 'Qǐng dǎ zhège diànhuà', 'note': ''},
  {'vi': 'Tôi bị mất hộ chiếu', 'zh': '我的護照不見了', 'pinyin': 'Wǒ de hùzhào bù jiàn le', 'note': ''},
  {'vi': 'Tôi cần thông dịch viên', 'zh': '我需要翻譯', 'pinyin': 'Wǒ xūyào fānyì', 'note': ''},
  {'vi': 'Xin gọi đại sứ quán Việt Nam', 'zh': '請打電話給越南大使館', 'pinyin': 'Qǐng dǎ diànhuà gěi Yuènán dàshǐguǎn', 'note': '(+84-4) 3845-3637'},
  {'vi': 'Tôi bị chủ nhà đuổi', 'zh': '房東把我趕走了', 'pinyin': 'Fángdōng bǎ wǒ gǎn zǒu le', 'note': ''},
  {'vi': 'Tôi chưa được trả lương', 'zh': '我還沒有拿到薪水', 'pinyin': 'Wǒ hái méiyǒu ná dào xīnshuǐ', 'note': '1955'},
  {'vi': 'Tôi bị tai nạn lao động', 'zh': '我發生工傷了', 'pinyin': 'Wǒ fāshēng gōngshāng le', 'note': ''},
  {'vi': 'Xin chỉ đường đến đồn cảnh sát', 'zh': '請告訴我警察局在哪裡', 'pinyin': 'Qǐng gàosù wǒ jǐngchájú zài nǎlǐ', 'note': ''},
  {'vi': 'Tôi dị ứng với thuốc này', 'zh': '我對這個藥過敏', 'pinyin': 'Wǒ duì zhège yào guòmǐn', 'note': ''},
  {'vi': 'Xin viết xuống giúp tôi', 'zh': '請幫我寫下來', 'pinyin': 'Qǐng bāng wǒ xiě xiàlái', 'note': ''},
  {'vi': 'Tôi cần về nhà ngay', 'zh': '我需要馬上回家', 'pinyin': 'Wǒ xūyào mǎshàng huíjiā', 'note': ''},
];

// ═══════════════════════════════════════════════════════════════
// TOOLS SCREEN
// ═══════════════════════════════════════════════════════════════
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _reminderExpanded = false;
  bool _rightsExpanded = false;
  bool _calcExpanded = false;
  double _salaryInput = 27470;

  // Reminder data
  final List<Map<String, dynamic>> _reminders = [
    {'icon': '🛵', 'label': 'Phí đường bộ xe máy', 'zh': '燃料費', 'month': 4, 'note': 'NT\$900/năm · Tháng 4'},
    {'icon': '🚗', 'label': 'Phí đường bộ ô tô', 'zh': '牌照稅', 'month': 4, 'note': 'Theo cc xe · Tháng 4'},
    {'icon': '🔧', 'label': 'Đăng kiểm xe', 'zh': '定期檢驗', 'month': 0, 'note': '2 năm/lần với xe mới'},
    {'icon': '🛡️', 'label': 'Bảo hiểm bắt buộc', 'zh': '強制險', 'month': 0, 'note': 'Hàng năm · ~NT\$1,000'},
    {'icon': '🪪', 'label': 'Gia hạn ARC', 'zh': '居留證', 'month': 0, 'note': 'Trước 30 ngày hết hạn'},
    {'icon': '📋', 'label': 'Khai thuế thu nhập', 'zh': '綜合所得稅', 'month': 5, 'note': 'Tháng 5 hàng năm'},
    {'icon': '🏥', 'label': 'Kiểm tra NHI', 'zh': '全民健保', 'month': 0, 'note': 'Kiểm tra định kỳ'},
  ];

  // Rights checklist
  final List<Map<String, dynamic>> _rights = [
    {'icon': '💰', 'label': 'Lương tối thiểu 2024', 'zh': '最低薪資', 'value': 'NT\$27,470/tháng', 'checked': false},
    {'icon': '🏥', 'label': 'Bảo hiểm lao động', 'zh': '勞工保險', 'value': 'Sếp phải đóng', 'checked': false},
    {'icon': '🏨', 'label': 'Bảo hiểm y tế NHI', 'zh': '全民健保', 'value': 'Sếp đóng 60%', 'checked': false},
    {'icon': '📅', 'label': 'Ngày nghỉ phép', 'zh': '特休假', 'value': '3 ngày/năm đầu', 'checked': false},
    {'icon': '⏰', 'label': 'Giờ làm tối đa', 'zh': '工時上限', 'value': '40h/tuần + OT có phụ cấp', 'checked': false},
    {'icon': '🤰', 'label': 'Nghỉ thai sản', 'zh': '產假', 'value': '8 tuần có lương', 'checked': false},
  ];

  String get _contextualSituation {
    final h = DateTime.now().hour;
    final weekday = DateTime.now().weekday;
    final day = DateTime.now().day;
    if (day >= 25) return '📄 Cuối tháng — Kiểm tra bảng lương';
    if (weekday == 1) return '💼 Thứ 2 — Dịch hợp đồng tuần mới';
    if (weekday == 5 && h >= 17) return '💰 Thứ 6 chiều — Tính lương cuối tuần';
    if (h < 10) return '☀️ Sáng sớm — Học từ vựng công sở';
    if (h < 14) return '🍜 Buổi trưa — Gọi món tiếng Trung';
    if (h >= 20) return '🌙 Tối — Ôn lại điều khoản hợp đồng';
    return '🛠️ Công cụ AI — Dành riêng cho bạn';
  }

  double get _afterTaxSalary {
    final labor = _salaryInput * 0.1 * 0.2;
    final health = _salaryInput * 0.0517 * 0.3;
    return _salaryInput - labor - health;
  }

  double get _maxRent => _afterTaxSalary * 0.3;
  double get _savingsTarget => _afterTaxSalary * 0.2;
  double get _remittance => _afterTaxSalary * 0.3;

  List<Map<String, dynamic>> get _checkedRights => _rights.where((r) => r['checked'] == true).toList();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            _buildEmergencyStrip(context),
            _buildContextualBanner(),
            const SizedBox(height: 20),
            _buildReminderCard(),
            const SizedBox(height: 16),
            _buildRightsCard(),
            const SizedBox(height: 16),
            _buildCalcCard(),
            const SizedBox(height: 24),
            _buildSectionLabel('🧠 Học tiếng Trung'),
            const SizedBox(height: 14),
            _buildToolGrid(_tools.sublist(0, 3)),
            const SizedBox(height: 24),
            _buildSectionLabel('🇹🇼 Sống ở Đài Loan'),
            const SizedBox(height: 14),
            _buildToolGrid(_tools.sublist(3)),
            const SizedBox(height: 24),
            _buildEnglishSection(),
            const SizedBox(height: 24),
            _buildJobSection(context),
            const SizedBox(height: 24),
            _buildEmergencyCard(context),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: _DS.indigoDeep,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Công cụ AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            Text('Bảo vệ quyền lợi người Việt tại Đài Loan', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _DS.indigo, borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('⚡', style: TextStyle(fontSize: 13)),
              SizedBox(width: 4),
              Text('15 công cụ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
            const SizedBox(width: 10),
            Text(_contextualSituation, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ]),
        ),
      ]),
    );
  }

  // ── EMERGENCY STRIP ───────────────────────────────────────
  Widget _buildEmergencyStrip(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage())),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _DS.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _DS.red.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _DS.red, borderRadius: BorderRadius.circular(8)),
            child: const Text('🆘', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Câu khẩn cấp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.red)),
            Text('110 · 119 · 1955 · 20 câu cứu mạng', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _DS.red),
        ]),
      ),
    );
  }

  // ── CONTEXTUAL BANNER ─────────────────────────────────────
  Widget _buildContextualBanner() {
    final hour = DateTime.now().hour;
    final suggestions = hour < 12
        ? ['Dịch thông báo từ sếp', 'Soạn email xin phép', 'Học từ vựng công sở']
        : hour < 18
            ? ['Gọi món tiếng Trung', 'Kiểm tra lương tháng này', 'Dịch tin nhắn']
            : ['Ôn hợp đồng lao động', 'Kiểm tra quyền lợi', 'Học từ mới'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🤖', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Gợi ý cho ${hour < 12 ? "buổi sáng" : hour < 18 ? "buổi chiều" : "buổi tối"} hôm nay',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
          const SizedBox(height: 10),
          Row(children: suggestions.map((s) => Expanded(
            child: GestureDetector(
              onTap: () {
                final tool = _tools.firstWhere((t) => t.key == 'work', orElse: () => _tools.first);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AiToolPage(tool: tool)));
              },
              child: Container(
                margin: EdgeInsets.only(right: s != suggestions.last ? 8 : 0),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white), textAlign: TextAlign.center),
              ),
            ),
          )).toList()),
        ]),
      ),
    );
  }

  // ── REMINDER CARD ─────────────────────────────────────────
  Widget _buildReminderCard() {
    final currentMonth = DateTime.now().month;
    final urgent = _reminders.where((r) => r['month'] == currentMonth).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          border: Border.all(color: urgent.isNotEmpty ? _DS.yellow.withOpacity(0.4) : _DS.indigoLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() => _reminderExpanded = !_reminderExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _DS.yellowLight, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('🔔', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Nhắc nhở phí định kỳ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  if (urgent.isNotEmpty)
                    Text('⚠️ ${urgent.length} khoản đến hạn tháng này!',
                        style: const TextStyle(fontSize: 11, color: _DS.orange, fontWeight: FontWeight.w600))
                  else
                    const Text('Xe cộ · ARC · Thuế · Bảo hiểm', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
                ])),
                Icon(_reminderExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: _DS.textGrey),
              ]),
            ),
          ),
          if (_reminderExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: _reminders.map((r) {
                final isUrgent = r['month'] == currentMonth;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUrgent ? _DS.yellowLight : _DS.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isUrgent ? _DS.yellow.withOpacity(0.4) : Colors.transparent),
                  ),
                  child: Row(children: [
                    Text(r['icon'] as String, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
                      Text('${r['zh']} · ${r['note']}', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                    ])),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _DS.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Tháng này!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _DS.orange)),
                      ),
                  ]),
                );
              }).toList()),
            ),
          ],
        ]),
      ),
    );
  }

  // ── RIGHTS CARD ───────────────────────────────────────────
  Widget _buildRightsCard() {
    final checkedCount = _rights.where((r) => r['checked'] == true).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          border: Border.all(color: _DS.indigoLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() => _rightsExpanded = !_rightsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('⚖️', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bản đồ quyền lợi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  Text('$checkedCount/${_rights.length} quyền lợi đã xác nhận',
                      style: TextStyle(fontSize: 11, color: checkedCount == _rights.length ? _DS.green : _DS.textGrey)),
                ])),
                Icon(_rightsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _DS.textGrey),
              ]),
            ),
          ),
          if (_rightsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    '✅ Tick vào những quyền lợi bạn đang được hưởng. Nếu thiếu — bạn có quyền yêu cầu sếp!',
                    style: TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w600, height: 1.5),
                  ),
                ),
                ..._rights.asMap().entries.map((entry) {
                  final i = entry.key;
                  final r = entry.value;
                  return GestureDetector(
                    onTap: () => setState(() => _rights[i]['checked'] = !(_rights[i]['checked'] as bool)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: r['checked'] == true ? _DS.greenLight : _DS.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: r['checked'] == true ? _DS.green.withOpacity(0.3) : Colors.transparent),
                      ),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: r['checked'] == true ? _DS.green : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: r['checked'] == true ? _DS.green : _DS.textGrey, width: 2),
                          ),
                          child: r['checked'] == true ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 10),
                        Text(r['icon'] as String, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
                          Text('${r['zh']} · ${r['value']}', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                        ])),
                      ]),
                    ),
                  );
                }),
                if (checkedCount < _rights.length) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _DS.redLight, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '⚠️ Bạn chưa xác nhận ${_rights.length - checkedCount} quyền lợi. Liên hệ 1955 để được tư vấn!',
                      style: const TextStyle(fontSize: 12, color: _DS.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  // ── SURVIVAL CALCULATOR ───────────────────────────────────
  Widget _buildCalcCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radius),
          border: Border.all(color: _DS.indigoLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: () => setState(() => _calcExpanded = !_calcExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('🧮', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Máy tính sinh tồn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  Text('Tính lương thực nhận · Chi phí · Gửi tiền về', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
                ])),
                Icon(_calcExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _DS.textGrey),
              ]),
            ),
          ),
          if (_calcExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                // Salary input
                Row(children: [
                  const Text('💰', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text('Lương gross:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
                  const Spacer(),
                  Text('NT\$${_salaryInput.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.indigo)),
                ]),
                Slider(
                  value: _salaryInput,
                  min: 27470, max: 100000, divisions: 100,
                  activeColor: _DS.indigo,
                  inactiveColor: _DS.indigoLight,
                  onChanged: (v) => setState(() => _salaryInput = v),
                ),
                const SizedBox(height: 8),

                // Results
                _buildCalcRow('💵 Lương thực nhận', 'NT\$${_afterTaxSalary.toInt()}', _DS.green),
                const SizedBox(height: 8),
                _buildCalcRow('🏠 Tiền nhà tối đa (30%)', 'NT\$${_maxRent.toInt()}', _DS.blue),
                const SizedBox(height: 8),
                _buildCalcRow('✈️ Gửi về VN (30%)', 'NT\$${_remittance.toInt()} ≈ ${(_remittance * 800).toInt()} VNĐ', _DS.orange),
                const SizedBox(height: 8),
                _buildCalcRow('🏦 Tiết kiệm (20%)', 'NT\$${_savingsTarget.toInt()}', _DS.purple),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    '💡 Sau khi trừ bảo hiểm lao động (20%) và NHI (30%), lương thực nhận thấp hơn gross khoảng 5-8%.',
                    style: TextStyle(fontSize: 11, color: _DS.indigo, height: 1.5),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildCalcRow(String label, String value, Color color) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _DS.textGrey))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    ]);
  }

  // ── SECTIONS ──────────────────────────────────────────────
  Widget _buildSectionLabel(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
  );

  Widget _buildToolGrid(List<_ToolConfig> tools) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35,
      ),
      itemCount: tools.length,
      itemBuilder: (_, i) => _ToolCard(tool: tools[i]),
    ),
  );

  Widget _buildEnglishSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        const Text('🇺🇸 Học tiếng Anh', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(10)),
          child: const Text('Mới', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.blue)),
        ),
      ]),
    ),
    const SizedBox(height: 14),
    _buildToolGrid(_englishTools),
  ]);

  Widget _buildJobSection(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💼 Tìm việc & Phát triển', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobSearchPage())),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(_DS.radius),
            boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
              child: const Center(child: Text('🔍', style: TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('Tìm việc làm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                SizedBox(width: 8),
                _HotBadge(),
              ]),
              const SizedBox(height: 4),
              Text('7 nguồn tìm việc · AI soạn CV · Tư vấn nghề nghiệp',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 8),
              Row(children: [
                _MiniTag(label: '104', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: '1111', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: 'LinkedIn', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: '+4 nữa', color: Colors.white),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildEmergencyCard(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF3D57), Color(0xFFB71C1C)]),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: _DS.red.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('🆘', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Câu khẩn cấp', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 3),
            Text('20 câu cần thiết nhất · Dùng được offline', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ])),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ),
        ]),
      ),
    ),
  );

  // Placeholder for _DS.redLight
  static const _redLight = Color(0xFFFFEBEE);
}

// ─── Tool Card ────────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  final _ToolConfig tool;
  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (tool.key == 'image_translate') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageTranslatePage()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => AiToolPage(tool: tool)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: tool.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: tool.gradient[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radius),
          child: Stack(children: [
            Positioned(right: -8, bottom: -12,
                child: Text(tool.emoji, style: TextStyle(fontSize: 64, color: Colors.white.withOpacity(0.15)))),
            if (tool.isPopular)
              Positioned(top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                  child: const Text('🔥 Phổ biến', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                )),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(tool.emoji, style: const TextStyle(fontSize: 28)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tool.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(tool.subtitle, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HotBadge extends StatelessWidget {
  const _HotBadge();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: _DS.orange, borderRadius: BorderRadius.circular(10)),
    child: const Text('🔥 Mới', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
  );
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
  );
}

// ═══════════════════════════════════════════════════════════════
// EMERGENCY PAGE — Fix lỗi lặp câu
// ═══════════════════════════════════════════════════════════════
class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: _DS.red,
        foregroundColor: Colors.white,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🆘', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Câu khẩn cấp', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Emergency numbers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF3D57), Color(0xFFB71C1C)]),
              borderRadius: BorderRadius.circular(_DS.radius),
            ),
            child: Column(children: [
              const Text('Số điện thoại khẩn cấp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _EmergencyNumber(number: '110', label: 'Cảnh sát'),
                _EmergencyNumber(number: '119', label: 'Cấp cứu'),
                _EmergencyNumber(number: '1955', label: 'Lao động'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Phrases — fixed no duplicate
          ..._emergencyPhrases.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _DS.white,
              borderRadius: BorderRadius.circular(_DS.radiusSm),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['vi']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textGrey)),
                const SizedBox(height: 4),
                Text(p['zh']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.red, fontFamily: 'NotoSansTC')),
                const SizedBox(height: 3),
                Text(p['pinyin']!, style: const TextStyle(fontSize: 12, color: _DS.indigo, fontStyle: FontStyle.italic)),
                if ((p['note'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(p['note']!, style: const TextStyle(fontSize: 11, color: _DS.textGrey, fontWeight: FontWeight.w600)),
                ],
              ])),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: p['zh']!));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Đã sao chép!'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 1),
                  ));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.copy_rounded, size: 16, color: _DS.indigo),
                ),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

class _EmergencyNumber extends StatelessWidget {
  final String number, label;
  const _EmergencyNumber({required this.number, required this.label});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Clipboard.setData(ClipboardData(text: number)),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// JOB SEARCH PAGE — giữ nguyên
// ═══════════════════════════════════════════════════════════════
class JobSearchPage extends StatefulWidget {
  const JobSearchPage({super.key});
  @override
  State<JobSearchPage> createState() => _JobSearchPageState();
}

class _JobSearchPageState extends State<JobSearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isVip = false;
  int _freeAiLeft = 10;

  static const _systemPrompt = '''Bạn là chuyên gia tư vấn việc làm cho người Việt tại Đài Loan.
Nhiệm vụ: tư vấn loại việc phù hợp, giải thích yêu cầu tuyển dụng, soạn CV tiếng Trung, tư vấn mức lương, hướng dẫn phỏng vấn.
Luôn trả lời bằng tiếng Việt, kèm tiếng Trung khi cần. CHỈ dùng Phồn thể (繁體字).''';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendAI({String? override}) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty) return;
    if (!_isVip && _freeAiLeft <= 0) { _showVipDialog(); return; }
    _controller.clear();
    setState(() { _messages.add({'role': 'user', 'content': text}); _isLoading = true; });
    _scrollToBottom();
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tools',
        data: {'text': text, 'tool_type': 'job_search', 'system_prompt': _systemPrompt},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _messages.add({'role': 'assistant', 'content': response.data['result'] as String? ?? ''}));
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          if (mounted) { setState(() => _freeAiLeft = 0); _showVipDialog(limit: detail['limit'] as int? ?? 10); }
          return;
        }
      }
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi kết nối. Thử lại nhé!'}));
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi kết nối. Thử lại nhé!'}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showVipDialog({int? limit}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_DS.indigo, _DS.indigoDark]), shape: BoxShape.circle),
                child: const Center(child: Text('⭐', style: TextStyle(fontSize: 36)))),
            const SizedBox(height: 16),
            const Text('Nâng cấp VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            Text(limit != null ? 'Gói Free giới hạn $limit lượt/ngày.\nVIP để hỏi không giới hạn!' : 'Hết lượt miễn phí!',
                textAlign: TextAlign.center, style: const TextStyle(color: _DS.textGrey, height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen()));
              },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Text('⭐ Xem các gói VIP', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau', style: TextStyle(color: _DS.textGrey))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🔍', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('Tìm việc làm', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        centerTitle: false, elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _DS.yellow,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: '🌐 Nguồn tìm việc'), Tab(text: '🤖 AI tư vấn')],
        ),
      ),
      body: TabBarView(controller: _tabCtrl, children: [_buildSourcesTab(), _buildAITab()]),
    );
  }

  Widget _buildSourcesTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]), borderRadius: BorderRadius.circular(_DS.radius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡 Mẹo tìm việc tại Đài Loan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('• Cần ARC hợp lệ mới làm việc được\n• Lương tối thiểu 2024: NT\$27,470/tháng\n• Part-time: max 20h/tuần với visa học',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85), height: 1.6)),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('🌐 Các trang tìm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 12),
      ..._jobSources.map((source) => GestureDetector(
        onTap: () => _openUrl(source.url),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: source.color.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: source.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(source.emoji, style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(source.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: source.color)),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: source.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(source.tag, style: TextStyle(fontSize: 10, color: source.color, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 3),
              Text(source.desc, style: const TextStyle(fontSize: 12, color: _DS.textGrey)),
            ])),
            Icon(Icons.open_in_new_rounded, color: source.color, size: 18),
          ]),
        ),
      )),
      const SizedBox(height: 20),
      const Text('🤖 Hỏi AI nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        '📝 Soạn CV tiếng Trung', '💰 Lương ngành F&B', '🗣️ Cách phỏng vấn', '📋 Giải thích hợp đồng',
      ].map((q) => GestureDetector(
        onTap: () { _tabCtrl.animateTo(1); Future.delayed(const Duration(milliseconds: 300), () => _sendAI(override: q)); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Text(q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
        ),
      )).toList()),
      const SizedBox(height: 20),
    ]),
  );

  Widget _buildAITab() => Column(children: [
    Expanded(
      child: _messages.isEmpty
          ? _buildAIWelcome()
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _buildTyping();
                final msg = _messages[i];
                return _buildBubble(msg['content']!, msg['role'] == 'user');
              }),
    ),
    _buildInputBar(),
  ]);

  Widget _buildAIWelcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      Container(width: 90, height: 90,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]), shape: BoxShape.circle),
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 40)))),
      const SizedBox(height: 16),
      const Text('AI Tư vấn việc làm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
      const SizedBox(height: 28),
      ...[
        '📝 Soạn CV tiếng Trung cho tôi — tôi làm nhà hàng 2 năm',
        '💰 Lương trung bình ngành logistics ở Đài Loan?',
        '🗣️ Cách giới thiệu bản thân khi phỏng vấn',
        '📋 Hợp đồng có điều khoản "試用期" là gì?',
      ].map((p) => GestureDetector(
        onTap: () => _sendAI(override: p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            Expanded(child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textDark))),
            const Icon(Icons.north_west_rounded, size: 14, color: Color(0xFF1A237E)),
          ]),
        ),
      )),
    ]),
  );

  Widget _buildBubble(String message, bool isUser) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          Container(width: 36, height: 36,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]), shape: BoxShape.circle),
              child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 8),
        ],
        Flexible(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isUser ? const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]) : null,
            color: isUser ? null : _DS.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Text(message, style: TextStyle(color: isUser ? Colors.white : _DS.textDark, fontSize: 14, height: 1.6)),
        )),
        if (isUser) const SizedBox(width: 8),
      ],
    ),
  );

  Widget _buildTyping() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 36, height: 36,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]), shape: BoxShape.circle),
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18)))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _DS.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(delay: 0, color: const Color(0xFF1A237E)),
          const SizedBox(width: 4),
          _Dot(delay: 150, color: const Color(0xFF1A237E)),
          const SizedBox(width: 4),
          _Dot(delay: 300, color: const Color(0xFF1A237E)),
        ]),
      ),
    ]),
  );

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(color: _DS.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
    child: Row(children: [
      Expanded(child: Container(
        decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _DS.indigoLight)),
        child: TextField(
          controller: _controller, maxLines: 3, minLines: 1,
          style: const TextStyle(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(hintText: 'Hỏi về việc làm, CV, phỏng vấn...',
              hintStyle: TextStyle(color: _DS.textGrey.withOpacity(0.7), fontSize: 13),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true, fillColor: _DS.bg),
          onSubmitted: (_) => _sendAI(),
        ),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _isLoading ? null : _sendAI,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: _isLoading ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]) : const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
            shape: BoxShape.circle,
            boxShadow: [if (!_isLoading) BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: _isLoading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════
// AI TOOL PAGE — giữ nguyên
// ═══════════════════════════════════════════════════════════════
class AiToolPage extends StatefulWidget {
  final _ToolConfig tool;
  const AiToolPage({super.key, required this.tool});
  @override
  State<AiToolPage> createState() => _AiToolPageState();
}

class _AiToolPageState extends State<AiToolPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _showCompletion = false;
  bool _showXp = false;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _checkVip();
  }

  Future<void> _checkVip() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/quota',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) setState(() => _isVip = response.data['is_vip'] == true);
    } catch (_) {}
  }

  Future<void> _send({String? override}) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() { _messages.add({'role': 'user', 'content': text}); _isLoading = true; _showCompletion = false; });
    _scrollToBottom();
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tools',
        data: {'text': text, 'tool_type': widget.tool.key,
            'system_prompt': (_isVip && widget.tool.systemVip != null) ? widget.tool.systemVip! : widget.tool.system},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() { _messages.add({'role': 'assistant', 'content': response.data['result'] as String? ?? ''}); _showCompletion = true; });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          if (mounted) _showToolQuotaDialog(detail['limit'] ?? 3);
          return;
        }
      }
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi kết nối. Vui lòng thử lại.'}));
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi kết nối. Vui lòng thử lại.'}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showToolQuotaDialog(int limit) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔒', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Hết lượt ${widget.tool.title} hôm nay',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Gói Free giới hạn $limit lượt/ngày.\nNâng VIP để dùng không giới hạn!',
                textAlign: TextAlign.center, style: const TextStyle(color: _DS.textGrey)),
            const SizedBox(height: 20),
            if (kIsWeb)
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen()));
                },
                child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.tool.gradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('⭐ Xem các gói VIP', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau', style: TextStyle(color: _DS.textGrey))),
          ]),
        ),
      ),
    );
  }

  void _copyAll() {
    final text = _messages.map((m) => '${m['role'] == 'user' ? 'Tôi' : widget.tool.title}: ${m['content']}').join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Đã sao chép!'),
      behavior: SnackBarBehavior.floating, backgroundColor: _DS.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: _DS.white, foregroundColor: _DS.textDark, elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.tool.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.tool.title, style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 16)),
        ]),
        actions: [
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: _copyAll,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy_rounded, size: 14, color: _DS.indigo),
                  SizedBox(width: 4),
                  Text('Sao chép', style: TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildWelcome()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0) + (_showCompletion && !_isLoading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (_isLoading && i == _messages.length) return _buildTyping();
                    if (_showCompletion && !_isLoading && i == _messages.length) return _buildCompletion();
                    if (i >= _messages.length) return const SizedBox.shrink();
                    final msg = _messages[i];
                    return _ToolChatBubble(message: msg['content']!, isUser: msg['role'] == 'user', tool: widget.tool);
                  }),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildWelcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      Container(width: 88, height: 88,
          decoration: BoxDecoration(gradient: LinearGradient(colors: widget.tool.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.tool.gradient[0].withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))]),
          child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 40)))),
      const SizedBox(height: 16),
      Text(widget.tool.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
      const SizedBox(height: 6),
      Text(widget.tool.subtitle, style: const TextStyle(fontSize: 14, color: _DS.textGrey)),
      const SizedBox(height: 28),
      ...widget.tool.quickPrompts.map((p) => GestureDetector(
        onTap: () => _send(override: p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: widget.tool.gradient[0].withOpacity(0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: widget.tool.gradient[0].withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 16)))),
            const SizedBox(width: 12),
            Expanded(child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textDark))),
            Icon(Icons.north_west_rounded, size: 14, color: widget.tool.gradient[0]),
          ]),
        ),
      )),
    ]),
  );

  Widget _buildTyping() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(gradient: LinearGradient(colors: widget.tool.gradient), shape: BoxShape.circle),
          child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 18)))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: _DS.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _Dot(delay: 0, color: widget.tool.gradient[0]),
          const SizedBox(width: 4),
          _Dot(delay: 150, color: widget.tool.gradient[0]),
          const SizedBox(width: 4),
          _Dot(delay: 300, color: widget.tool.gradient[0]),
        ]),
      ),
    ]),
  );

  Widget _buildCompletion() => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: _DS.green.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(children: [
        const Text('✅ Đã giải quyết vấn đề chưa?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () { setState(() { _showCompletion = false; _showXp = true; }); Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showXp = false); }); },
            child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('✅ Xong rồi! +5 XP', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.green))),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _showCompletion = false),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('🙋 Hỏi thêm', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.indigo))),
          )),
        ]),
      ]),
    ),
  );

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
    child: Row(children: [
      Expanded(child: Container(
        decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: _DS.indigoLight)),
        child: TextField(
          controller: _controller, maxLines: 3, minLines: 1,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(hintText: widget.tool.subtitle,
              hintStyle: TextStyle(color: _DS.textGrey.withOpacity(0.7), fontSize: 13),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true, fillColor: _DS.bg),
          onSubmitted: (_) => _send(),
        ),
      )),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _isLoading ? null : _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: _isLoading ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]) : LinearGradient(colors: widget.tool.gradient),
            shape: BoxShape.circle,
            boxShadow: [if (!_isLoading) BoxShadow(color: widget.tool.gradient[0].withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: _isLoading
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );
}

// ─── Tool Chat Bubble ─────────────────────────────────────────
class _ToolChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final _ToolConfig tool;
  const _ToolChatBubble({required this.message, required this.isUser, required this.tool});

  Widget _buildHighlight(String text, Color color) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf，。！？、：；「」]+');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start), style: const TextStyle(color: _DS.textDark, fontSize: 14, height: 1.6)));
      spans.add(TextSpan(text: m.group(0), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, height: 1.6, fontFamily: 'NotoSansTC')));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: const TextStyle(color: _DS.textDark, fontSize: 14, height: 1.6)));
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: LinearGradient(colors: tool.gradient), shape: BoxShape.circle),
              child: Center(child: Text(tool.emoji, style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 8),
        ],
        Flexible(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isUser ? LinearGradient(colors: tool.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: isUser ? null : _DS.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4), bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: isUser ? Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6)) : _buildHighlight(message, tool.gradient[0]),
        )),
        if (isUser) const SizedBox(width: 8),
      ],
    ),
  );
}

// ─── Typing dot ───────────────────────────────────────────────
class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.repeat(reverse: true); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, -5 * _anim.value),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// IMAGE TRANSLATE PAGE — giữ nguyên logic, đổi màu Indigo
// ═══════════════════════════════════════════════════════════════
class ImageTranslatePage extends StatefulWidget {
  const ImageTranslatePage({super.key});
  @override
  State<ImageTranslatePage> createState() => _ImageTranslatePageState();
}

class _ImageTranslatePageState extends State<ImageTranslatePage> {
  final _storage = const FlutterSecureStorage();
  String? _imageBase64;
  String _imageType = 'general';
  String _result = '';
  String _explanation = '';
  String _extractedText = '';
  bool _isLoading = false;
  bool _isVip = false;
  int _freeLeft = 3;

  static const _imageTypes = [
    {'key': 'general', 'emoji': '📷', 'label': 'Ảnh chung'},
    {'key': 'contract', 'emoji': '📋', 'label': 'Hợp đồng'},
    {'key': 'menu', 'emoji': '🍜', 'label': 'Menu'},
    {'key': 'sign', 'emoji': '🪧', 'label': 'Biển báo'},
  ];

  String get _systemContext {
    switch (_imageType) {
      case 'contract': return 'Đây là hợp đồng lao động. Hãy: 1) Dịch toàn bộ nội dung, 2) Giải thích các điều khoản quan trọng, 3) Cảnh báo điều khoản bất lợi nếu có.';
      case 'menu': return 'Đây là menu nhà hàng. Hãy: 1) Dịch tên món ăn, 2) Mô tả nguyên liệu chính, 3) Gợi ý món phù hợp người Việt.';
      case 'sign': return 'Đây là biển báo/thông báo. Hãy dịch chính xác và giải thích ý nghĩa thực tế.';
      default: return 'Dịch toàn bộ văn bản trong ảnh và giải thích ngắn gọn.';
    }
  }

  Future<void> _pickImage() async {
    final base64 = await webPickImage();
    if (base64 == null) return;
    setState(() { _imageBase64 = base64; _result = ''; _explanation = ''; _extractedText = ''; });
  }

  Future<void> _captureImage() async {
    final base64 = await webCaptureImage();
    if (base64 == null) return;
    setState(() { _imageBase64 = base64; _result = ''; _explanation = ''; _extractedText = ''; });
    _translate();
  }

  Future<void> _translate() async {
    if (_imageBase64 == null) return;
    setState(() { _isLoading = true; _result = ''; _explanation = ''; _extractedText = ''; });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/image',
        data: {'image_base64': _imageBase64, 'target_lang': 'vi', 'context': _systemContext, 'image_type': _imageType},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _extractedText = response.data['extracted_text'] ?? '';
        _result = response.data['translated'] ?? '';
        _explanation = response.data['explanation'] ?? '';
      });
      // Đồng bộ quota từ header backend (nguồn đúng)
      final q = response.headers.value('x-quota-remaining');
      if (q != null && q != 'unlimited') {
        final parsed = int.tryParse(q);
        if (parsed != null && mounted) setState(() => _freeLeft = parsed);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          if (mounted) { setState(() => _freeLeft = 0); _showVipDialog(); }
          return;
        }
      }
      setState(() => _result = '⚠️ Lỗi kết nối. Thử lại nhé!');
    } catch (e) {
      setState(() => _result = '⚠️ Lỗi kết nối. Thử lại nhé!');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showVipDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_DS.indigo, _DS.indigoDark]), shape: BoxShape.circle),
                child: const Center(child: Text('⭐', style: TextStyle(fontSize: 36)))),
            const SizedBox(height: 16),
            const Text('Nâng cấp VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text('Hết lượt dịch ảnh miễn phí!\nVIP mở khóa dịch ảnh không giới hạn!',
                textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, height: 1.6)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen()));
              },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Text('⭐ Xem các gói VIP', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Để sau', style: TextStyle(color: _DS.textGrey))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: _DS.white, foregroundColor: _DS.textDark, elevation: 0,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('📷', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Dịch ảnh AI', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 16)),
        ]),
        actions: [
          if (!_isVip)
            Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📷', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('$_freeLeft', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.indigo)),
                ])),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type selector
          Row(children: _imageTypes.map((t) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: t == _imageTypes.last ? 0 : 8),
              child: GestureDetector(
                onTap: () => setState(() => _imageType = t['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _imageType == t['key'] ? _DS.indigoLight : _DS.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _imageType == t['key'] ? _DS.indigo : Colors.grey.shade200, width: _imageType == t['key'] ? 2 : 1),
                  ),
                  child: Column(children: [
                    Text(t['emoji']!, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(t['label']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: _imageType == t['key'] ? _DS.indigo : _DS.textGrey)),
                  ]),
                ),
              ),
            ),
          )).toList()),
          const SizedBox(height: 16),

          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity, height: 220,
              decoration: BoxDecoration(
                color: _DS.white, borderRadius: BorderRadius.circular(_DS.radius),
                border: Border.all(color: _imageBase64 != null ? _DS.indigo.withOpacity(0.5) : _DS.indigoLight, width: _imageBase64 != null ? 2 : 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: _imageBase64 != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(19), child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.contain))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 64, height: 64, decoration: const BoxDecoration(color: _DS.indigoLight, shape: BoxShape.circle),
                          child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: _DS.indigo)),
                      const SizedBox(height: 12),
                      const Text('Nhấn để chọn ảnh', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textDark)),
                      const SizedBox(height: 4),
                      Text('JPG, PNG, WEBP', style: TextStyle(fontSize: 12, color: _DS.textGrey.withOpacity(0.7))),
                    ]),
            ),
          ),
          const SizedBox(height: 14),

          // Buttons
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: _pickImage,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: _DS.indigoLight)),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_library_rounded, size: 20, color: _DS.indigo),
                    SizedBox(height: 4),
                    Text('Thư viện', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.indigo)),
                  ])),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: _captureImage,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: _DS.indigo.withOpacity(0.3))),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_rounded, size: 20, color: _DS.indigo),
                    SizedBox(height: 4),
                    Text('Chụp ảnh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.indigo)),
                  ])),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: (_imageBase64 != null && !_isLoading) ? _translate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _imageBase64 != null ? const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]) : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]),
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  boxShadow: _imageBase64 != null ? [BoxShadow(color: _DS.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.translate_rounded, size: 20, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(_isLoading ? 'Đang dịch...' : 'Dịch ảnh', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 16),

          // Results
          if (_isLoading)
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radius)),
                child: const Column(children: [
                  CircularProgressIndicator(color: _DS.indigo, strokeWidth: 3),
                  SizedBox(height: 12),
                  Text('Đang phân tích ảnh...', style: TextStyle(fontSize: 13, color: _DS.textGrey)),
                ])),

          if (_extractedText.isNotEmpty)
            Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.text_fields_rounded, size: 14, color: _DS.textGrey), SizedBox(width: 6),
                    Text('Văn bản nhận diện:', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 8),
                  Text(_extractedText, style: const TextStyle(fontSize: 14, color: _DS.textDark, height: 1.5)),
                ])),

          if (_result.isNotEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radius),
                    border: Border.all(color: _DS.indigoLight),
                    boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.translate_rounded, size: 14, color: _DS.indigo), SizedBox(width: 6),
                    Text('Bản dịch:', style: TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 10),
                  Text(_result, style: const TextStyle(fontSize: 16, color: _DS.textDark, height: 1.6, fontWeight: FontWeight.w600)),
                  if (_explanation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('💡 Giải thích:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textGrey)),
                          const SizedBox(height: 6),
                          Text(_explanation, style: const TextStyle(fontSize: 13, color: _DS.textGrey, height: 1.5)),
                        ])),
                  ],
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _result));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Đã sao chép!'), behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 1),
                        ));
                      },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.copy_rounded, size: 14, color: _DS.textGrey),
                            SizedBox(width: 6),
                            Text('Sao chép', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700)),
                          ])),
                    ),
                  ]),
                ])),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}