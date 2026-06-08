import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;

// ─── Design System ────────────────────────────────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const yellow = Color(0xFFFFB300);
  static const yellowLight = Color(0xFFFFF8E1);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const red = Color(0xFFFF3D57);
  static const purple = Color(0xFF7C4DFF);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── Tool config ──────────────────────────────────────────────
class _ToolConfig {
  final String key, emoji, title, subtitle, system;
  final List<Color> gradient;
  final List<String> quickPrompts;
  final bool isPopular;
  final bool isEmergency;

  const _ToolConfig({
    required this.key, required this.emoji, required this.title,
    required this.subtitle, required this.system, required this.gradient,
    required this.quickPrompts, this.isPopular = false, this.isEmergency = false,
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
    key: 'tourism', emoji: '🗺️', title: 'Du lịch Đài Loan', subtitle: 'Địa điểm, ăn uống, di chuyển',
    gradient: [Color(0xFF00897B), Color(0xFF00695C)],
    quickPrompts: ['Đài Bắc có gì hay chơi?', 'Đi Jiufen cần chuẩn bị gì?', 'Ăn gì ở Đài Nam?', 'Cách đi MRT từ sân bay'],
    isPopular: false,
    system: '''Bạn là hướng dẫn viên du lịch Đài Loan chuyên nghiệp cho người Việt.

Khi user hỏi về địa điểm bất kỳ, hãy tư vấn CHI TIẾT:
1. 📍 Địa điểm nổi bật nhất (3-5 chỗ)
2. 🍜 Ăn gì đặc sản ở đó
3. 🚌 Cách di chuyển (MRT/bus/taxi)
4. 💰 Chi phí tham khảo (NT\$)
5. ⏰ Thời điểm tốt nhất để đi
6. 💡 Mẹo thực tế cho người Việt

Luôn kèm tiếng Trung tên địa điểm để user dễ tìm đường.
Trả lời bằng tiếng Việt, thực tế, cụ thể, không chung chung.
Nếu user hỏi từ vựng liên quan → dạy luôn.''',
  ),
];

const _englishTools = [
  _ToolConfig(
    key: 'en_pronunciation', emoji: '🗣️', title: 'Phát âm tiếng Anh', subtitle: 'AI sửa phát âm, luyện accent',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    quickPrompts: ['Phát âm "comfortable" đúng không?', 'Sửa lỗi phát âm "th" cho tôi', 'Accent Mỹ khác Anh thế nào?'],
    system: '''Bạn là giáo viên phát âm tiếng Anh chuyên nghiệp.
Khi user nhập từ/câu tiếng Anh, hãy:
1) Phiên âm IPA chính xác
2) Hướng dẫn phát âm chi tiết cho người Việt
3) Lỗi phát âm người Việt hay mắc
4) Câu ví dụ thực tế
Trả lời bằng tiếng Việt.''',
  ),
  _ToolConfig(
    key: 'en_grammar', emoji: '📝', title: 'Ngữ pháp tiếng Anh', subtitle: 'Giải thích grammar thực tế',
    gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    quickPrompts: ['Khi nào dùng "have been" vs "had been"?', 'Phân biệt "since" và "for"', 'Cách dùng conditional sentences'],
    system: '''Bạn là giáo viên ngữ pháp tiếng Anh cho người Việt.
Giải thích ngữ pháp rõ ràng, cho ví dụ thực tế, so sánh với tiếng Việt khi cần.
Trả lời bằng tiếng Việt.''',
  ),
  _ToolConfig(
    key: 'en_workplace', emoji: '💼', title: 'Tiếng Anh công sở', subtitle: 'Email, họp, thuyết trình',
    gradient: [Color(0xFF4527A0), Color(0xFF311B92)],
    quickPrompts: ['Soạn email xin nghỉ phép bằng tiếng Anh', 'Cách nói "tôi không đồng ý" lịch sự', 'Từ vựng trong cuộc họp'],
    isPopular: true,
    system: '''Bạn là chuyên gia tiếng Anh công sở cho người Việt.
Giúp soạn email chuyên nghiệp, giao tiếp trong cuộc họp, thuyết trình, đàm phán.
Luôn giải thích lý do dùng từ/cấu trúc đó.
Trả lời bằng tiếng Việt, kèm tiếng Anh.''',
  ),
  _ToolConfig(
    key: 'en_daily', emoji: '🎬', title: 'Tiếng Anh thực tế', subtitle: 'Slang, phim, nhạc, Gen Z',
    gradient: [Color(0xFFBF360C), Color(0xFF870000)],
    quickPrompts: ['"No cap" nghĩa là gì?', 'Slang Gen Z phổ biến 2024', 'Hiểu câu thoại phim này giúp tôi'],
    system: '''Bạn là chuyên gia tiếng Anh thực tế, slang, văn hóa pop cho người Việt.
Giải thích slang, idiom, cách nói tự nhiên của người bản xứ.
Thực tế, vui vẻ, dùng ví dụ từ phim/nhạc/mạng xã hội.
Trả lời bằng tiếng Việt.''',
  ),
];

// ─── Job sources data ──────────────────────────────────────────
class _JobSource {
  final String name, desc, emoji, url, tag;
  final Color color;
  final bool isVip;
  const _JobSource({
    required this.name, required this.desc, required this.emoji,
    required this.url, required this.tag, required this.color,
    this.isVip = false,
  });
}

const _jobSources = [
  _JobSource(
    name: '104人力銀行', desc: 'Trang tìm việc lớn nhất Đài Loan', emoji: '🏆',
    url: 'https://www.104.com.tw/jobs/search/?keyword=%E8%A6%96%E8%A8%8A&area=6001001000',
    tag: 'Phổ biến nhất', color: Color(0xFF2979FF),
  ),
  _JobSource(
    name: '1111人力銀行', desc: 'Lớn thứ 2, nhiều việc part-time', emoji: '⭐',
    url: 'https://www.1111.com.tw/',
    tag: 'Part-time', color: Color(0xFFFF6B35),
  ),
  _JobSource(
    name: 'Cake.me', desc: 'Việc tech, startup, creative', emoji: '🎂',
    url: 'https://www.cake.me/jobs',
    tag: 'Tech & Startup', color: Color(0xFF00C853),
  ),
  _JobSource(
    name: 'LinkedIn', desc: 'Việc văn phòng, công ty nước ngoài', emoji: '💼',
    url: 'https://www.linkedin.com/jobs/search/?location=Taiwan',
    tag: 'Văn phòng', color: Color(0xFF0A66C2),
  ),
  _JobSource(
    name: 'WDA - Lao động nước ngoài', desc: 'Cơ quan chính phủ hỗ trợ lao động nước ngoài hợp pháp',
    emoji: '🏛️', url: 'https://fw.wda.gov.tw/',
    tag: 'Chính thức', color: Color(0xFF7C4DFF),
  ),
  _JobSource(
    name: 'FB: Người Việt tìm việc Đài Loan', desc: 'Group Facebook cộng đồng người Việt',
    emoji: '👥', url: 'https://www.facebook.com/groups/nguoiviettaidailoan',
    tag: 'Cộng đồng', color: Color(0xFF1877F2),
  ),
  _JobSource(
    name: 'Yourator', desc: 'Startup, creative, môi trường trẻ', emoji: '🚀',
    url: 'https://www.yourator.co/',
    tag: 'Startup', color: Color(0xFFE91E8C),
  ),
];

// ─── Emergency phrases ─────────────────────────────────────────
const _emergencyPhrases = [
  {'vi': 'Tôi cần giúp đỡ!', 'zh': '我需要幫助！', 'note': 'Wǒ xūyào bāngzhù'},
  {'vi': 'Gọi cấp cứu!', 'zh': '叫救護車！', 'note': '119'},
  {'vi': 'Gọi cảnh sát!', 'zh': '叫警察！', 'note': '110'},
  {'vi': 'Tôi bị lạc', 'zh': '我迷路了', 'note': ''},
  {'vi': 'Tôi bị ốm', 'zh': '我生病了', 'note': ''},
  {'vi': 'Tôi bị tai nạn', 'zh': '我出車禍了', 'note': ''},
  {'vi': 'Bệnh viện ở đâu?', 'zh': '醫院在哪裡？', 'note': ''},
  {'vi': 'Tôi không hiểu tiếng Trung', 'zh': '我不懂中文', 'note': ''},
  {'vi': 'Có ai nói tiếng Anh không?', 'zh': '有人說英文嗎？', 'note': ''},
  {'vi': 'Xin gọi cho số này', 'zh': '請打這個電話', 'note': ''},
];

// ═══════════════════════════════════════════════════════════════
// TOOLS SCREEN
// ═══════════════════════════════════════════════════════════════
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildHeader(),
            _buildHeroBanner(),
            const SizedBox(height: 24),
            _buildSection('🧠 Học tiếng Trung', _tools.sublist(0, 3), context),
            const SizedBox(height: 24),
            _buildSection('🇹🇼 Sống ở Đài Loan', _tools.sublist(3, 9), context),
            const SizedBox(height: 24),
            _buildEnglishSection(context),
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

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(children: [
      const Text('Công cụ AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.textDark, letterSpacing: -0.5)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('⚡', style: TextStyle(fontSize: 14)),
          SizedBox(width: 4),
          Text('15 công cụ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.orange)),
        ]),
      ),
    ]),
  );

  Widget _buildHeroBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_DS.orange, Color(0xFFFFB300)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
            child: const Text('🤖 AI thông minh', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          const Text('15 công cụ\nhỗ trợ cuộc sống', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.3)),
          const SizedBox(height: 6),
          Text('Tiếng Trung + Tiếng Anh · Đài Loan', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
        ])),
        Column(children: [
          const Text('⚡', style: TextStyle(fontSize: 48)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Text('🇻🇳 × 🇹🇼', style: TextStyle(fontSize: 16)),
          ),
        ]),
      ]),
    ),
  );

  Widget _buildSection(String title, List<_ToolConfig> tools, BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
      ),
      const SizedBox(height: 14),
      Padding(
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
      ),
    ]);
  }

  Widget _buildEnglishSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35,
          ),
          itemCount: _englishTools.length,
          itemBuilder: (_, i) => _ToolCard(tool: _englishTools[i]),
        ),
      ),
    ]);
  }
  Widget _buildJobSection(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('💼 Tìm việc & Phát triển', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JobSearchPage())),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_DS.radius),
            boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
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
          gradient: const LinearGradient(colors: [Color(0xFFFF3D57), Color(0xFFB71C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
            Text('10 câu cần thiết nhất · Dùng được offline', style: TextStyle(fontSize: 12, color: Colors.white70)),
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
                ),
              ),
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

// ═══════════════════════════════════════════════════════════════
// JOB SEARCH PAGE
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
  int _freeAiLeft = 3; // free 3 lần hỏi AI

  static const _systemPrompt = '''Bạn là chuyên gia tư vấn việc làm cho người Việt tại Đài Loan.

Nhiệm vụ:
1. Tư vấn loại việc phù hợp theo trình độ tiếng Trung và kinh nghiệm
2. Giải thích yêu cầu tuyển dụng bằng tiếng Trung
3. Soạn CV tiếng Trung chuyên nghiệp (VIP)
4. Soạn thư xin việc tiếng Trung (VIP)
5. Tư vấn mức lương hợp lý theo ngành tại Đài Loan
6. Hướng dẫn cách phỏng vấn với sếp Đài Loan

Luôn trả lời bằng tiếng Việt, kèm tiếng Trung khi cần thiết.
Khi viết tiếng Trung: CHỈ dùng Phồn thể (繁體字).
Thực tế, cụ thể, không nói chung chung.''';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _checkVip();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkVip() async {
    // TODO: check VIP status from backend
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không mở được link. Vui lòng thử lại!')),
        );
      }
    }
  }

  Future<void> _sendAI({String? override}) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty) return;

    if (!_isVip && _freeAiLeft <= 0) {
      _showVipDialog();
      return;
    }

    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      if (!_isVip) _freeAiLeft--;
    });
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/chat',
        data: {
          'message': text,
          'system_prompt': _systemPrompt,
          'history': _messages.take(10).map((m) => {'role': m['role'], 'content': m['content']}).toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _messages.add({'role': 'assistant', 'content': response.data['reply'] ?? ''}));
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

  void _showVipDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_DS.orange, _DS.yellow]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('⭐', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            const Text('Nâng cấp VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text(
              'Hết lượt hỏi AI miễn phí!\nVIP mở khóa:\n✅ AI soạn CV tiếng Trung\n✅ AI soạn thư xin việc\n✅ Hỏi AI không giới hạn\n✅ Chat AI không giới hạn',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DS.textGrey, height: 1.6),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Text('Nâng cấp NT\$149/tháng',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau', style: TextStyle(color: _DS.textGrey)),
            ),
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
        centerTitle: false,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _DS.orange,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: '🌐 Nguồn tìm việc'),
            Tab(text: '🤖 AI tư vấn'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSourcesTab(),
          _buildAITab(),
        ],
      ),
    );
  }

  Widget _buildSourcesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
            borderRadius: BorderRadius.circular(_DS.radius),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡 Mẹo tìm việc tại Đài Loan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              '• Cần ARC hợp lệ mới làm việc được\n• Lương tối thiểu 2024: NT\$27,470/tháng\n• Part-time: max 20h/tuần với visa học\n• Bấm vào nguồn bên dưới để tìm việc',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85), height: 1.6),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        const Text('🌐 Các trang tìm việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
        const SizedBox(height: 12),

        ..._jobSources.map((source) => _buildSourceCard(source)),

        const SizedBox(height: 20),
        // Quick AI prompts
        const Text('🤖 Hỏi AI nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            '📝 Soạn CV tiếng Trung cho tôi',
            '💰 Lương ngành F&B ở Đài Loan',
            '🗣️ Cách phỏng vấn với sếp Đài Loan',
            '📋 Giải thích hợp đồng lao động',
            '🏭 Việc factory cần biết gì?',
            '🛍️ Tìm việc part-time convenience store',
          ].map((q) => GestureDetector(
            onTap: () {
              _tabCtrl.animateTo(1);
              Future.delayed(const Duration(milliseconds: 300), () => _sendAI(override: q));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _DS.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Text(q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildSourceCard(_JobSource source) => GestureDetector(
    onTap: () => _openUrl(source.url),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: source.color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: source.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(source.emoji, style: const TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(source.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: source.color)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: source.color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(source.tag, style: TextStyle(fontSize: 10, color: source.color, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(source.desc, style: const TextStyle(fontSize: 12, color: _DS.textGrey)),
        ])),
        Icon(Icons.open_in_new_rounded, color: source.color, size: 18),
      ]),
    ),
  );

  Widget _buildAITab() {
    return Column(children: [
      // Free quota warning
      if (!_isVip)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _freeAiLeft > 0 ? _DS.blueLight : _DS.yellowLight,
          child: Row(children: [
            Text(_freeAiLeft > 0 ? '🤖' : '⚠️', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              _freeAiLeft > 0
                  ? 'Còn $_freeAiLeft lượt hỏi AI miễn phí · VIP để hỏi không giới hạn'
                  : 'Hết lượt miễn phí · Nâng cấp VIP để tiếp tục',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _freeAiLeft > 0 ? _DS.blue : _DS.orange,
              ),
            )),
            if (_freeAiLeft <= 0)
              GestureDetector(
                onTap: _showVipDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('VIP', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),

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
                },
              ),
      ),
      _buildInputBar(),
    ]);
  }

  Widget _buildAIWelcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      Container(
        width: 90, height: 90,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: const Center(child: Text('🤖', style: TextStyle(fontSize: 40))),
      ),
      const SizedBox(height: 16),
      const Text('AI Tư vấn việc làm', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
      const SizedBox(height: 6),
      const Text('Hỏi bất cứ điều gì về tìm việc tại Đài Loan',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _DS.textGrey)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _DS.orangeLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _isVip ? '✅ VIP — Hỏi không giới hạn' : '🆓 Miễn phí $_freeAiLeft lượt · VIP để hỏi thêm',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.orange),
        ),
      ),
      const SizedBox(height: 28),
      const Align(alignment: Alignment.centerLeft,
          child: Text('Gợi ý:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey))),
      const SizedBox(height: 10),
      ...[
        '📝 Soạn CV tiếng Trung cho tôi — tôi làm nhà hàng 2 năm',
        '💰 Lương trung bình ngành logistics ở Đài Loan?',
        '🗣️ Cách giới thiệu bản thân khi phỏng vấn bằng tiếng Trung',
        '📋 Hợp đồng có điều khoản "試用期" là gì?',
        '🏭 Làm factory cần biết những từ tiếng Trung nào?',
      ].map((p) => GestureDetector(
        onTap: () => _sendAI(override: p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            border: Border.all(color: const Color(0xFF1A237E).withOpacity(0.2)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
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
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser ? const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]) : null,
              color: isUser ? null : _DS.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Text(message,
                style: TextStyle(
                  color: isUser ? Colors.white : _DS.textDark,
                  fontSize: 14, height: 1.6,
                )),
          ),
        ),
        if (isUser) const SizedBox(width: 8),
      ],
    ),
  );

  Widget _buildTyping() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(
        width: 36, height: 36,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('🤖', style: TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
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
    decoration: BoxDecoration(
      color: _DS.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
    ),
    child: Row(children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 3, minLines: 1,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Hỏi về việc làm, CV, phỏng vấn...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _sendAI(),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _isLoading ? null : _sendAI,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200])
                : const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
            shape: BoxShape.circle,
            boxShadow: [if (!_isLoading) const BoxShadow(color: Color(0x661A237E), blurRadius: 8, offset: Offset(0, 3))],
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
// EMERGENCY PAGE
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
                _EmergencyNumber(number: '1990', label: 'Lao động'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
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
                Text(p['vi']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textDark)),
                const SizedBox(height: 4),
                Text(p['zh']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.red)),
                if ((p['note'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(p['note']!, style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
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
                  decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.copy_rounded, size: 16, color: _DS.orange),
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
// AI TOOL PAGE
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

  Future<void> _send({String? override}) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _showCompletion = false;
    });
    _scrollToBottom();
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/chat',
        data: {
          'message': text,
          'system_prompt': widget.tool.system,
          'history': _messages.take(10).map((m) => {'role': m['role'], 'content': m['content']}).toList(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _messages.add({'role': 'assistant', 'content': response.data['reply'] ?? ''});
        _showCompletion = true;
      });
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

  void _copyAll() {
    final text = _messages.map((m) {
      final role = m['role'] == 'user' ? 'Tôi' : widget.tool.title;
      return '$role: ${m['content']}';
    }).join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Đã sao chép toàn bộ hội thoại!'),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _DS.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      appBar: AppBar(
        backgroundColor: _DS.white,
        foregroundColor: _DS.textDark,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.tool.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.tool.title, style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 16)),
        ]),
        centerTitle: false,
        actions: [
          if (_messages.isNotEmpty)
            GestureDetector(
              onTap: _copyAll,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy_rounded, size: 14, color: _DS.orange),
                  SizedBox(width: 4),
                  Text('Sao chép', style: TextStyle(fontSize: 12, color: _DS.orange, fontWeight: FontWeight.w700)),
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
                  },
                ),
        ),
        if (_showXp)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: _DS.greenLight,
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🎉 Vấn đề giải quyết xong! +5 XP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.green)),
            ]),
          ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildWelcome() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      const SizedBox(height: 20),
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.tool.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.tool.gradient[0].withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 40))),
      ),
      const SizedBox(height: 16),
      Text(widget.tool.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
      const SizedBox(height: 6),
      Text(widget.tool.subtitle, style: const TextStyle(fontSize: 14, color: _DS.textGrey)),
      const SizedBox(height: 28),
      Align(alignment: Alignment.centerLeft,
          child: Text('Câu hỏi phổ biến:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey))),
      const SizedBox(height: 10),
      ...widget.tool.quickPrompts.map((p) => GestureDetector(
        onTap: () => _send(override: p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            border: Border.all(color: widget.tool.gradient[0].withOpacity(0.25)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: widget.tool.gradient[0].withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 16))),
            ),
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
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(gradient: LinearGradient(colors: widget.tool.gradient), shape: BoxShape.circle),
        child: Center(child: Text(widget.tool.emoji, style: const TextStyle(fontSize: 18))),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
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
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: _DS.green.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        const Text('✅ Đã giải quyết vấn đề chưa?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () {
              setState(() { _showCompletion = false; _showXp = true; });
              Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showXp = false); });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(10)),
              child: const Text('✅ Xong rồi! +5 XP', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.green)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _showCompletion = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(10)),
              child: const Text('🙋 Hỏi thêm', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.orange)),
            ),
          )),
        ]),
      ]),
    ),
  );

  Widget _buildInputBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
    ),
    child: Row(children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _controller,
            maxLines: 3, minLines: 1,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: widget.tool.subtitle,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _isLoading ? null : _send,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200])
                : LinearGradient(colors: widget.tool.gradient),
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
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start),
          style: const TextStyle(color: _DS.textDark, fontSize: 14, height: 1.6)));
      spans.add(TextSpan(text: m.group(0),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, height: 1.6)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last),
        style: const TextStyle(color: _DS.textDark, fontSize: 14, height: 1.6)));
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
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(gradient: LinearGradient(colors: tool.gradient), shape: BoxShape.circle),
            child: Center(child: Text(tool.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isUser ? LinearGradient(colors: tool.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
              color: isUser ? null : _DS.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: isUser
                ? Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6))
                : _buildHighlight(message, tool.gradient[0]),
          ),
        ),
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
// IMAGE TRANSLATE PAGE — Dịch ảnh với AI giải thích
// ═══════════════════════════════════════════════════════════════
class ImageTranslatePage extends StatefulWidget {
  const ImageTranslatePage({super.key});
  @override
  State<ImageTranslatePage> createState() => _ImageTranslatePageState();
}

class _ImageTranslatePageState extends State<ImageTranslatePage> {
  final _storage = const FlutterSecureStorage();
  String? _imageBase64;
  String _imageType = 'general'; // general, contract, menu, sign
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
      case 'contract':
        return 'Đây là hợp đồng lao động. Hãy: 1) Dịch toàn bộ nội dung, 2) Giải thích các điều khoản quan trọng, 3) Cảnh báo điều khoản bất lợi nếu có.';
      case 'menu':
        return 'Đây là menu nhà hàng. Hãy: 1) Dịch tên món ăn, 2) Mô tả nguyên liệu chính, 3) Gợi ý món phù hợp người Việt.';
      case 'sign':
        return 'Đây là biển báo/thông báo. Hãy dịch chính xác và giải thích ý nghĩa thực tế.';
      default:
        return 'Dịch toàn bộ văn bản trong ảnh và giải thích ngắn gọn.';
    }
  }

  void _pickImage() {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    input.onChange.listen((e) {
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final img = html.ImageElement();
        img.src = reader.result as String;
        img.onLoad.listen((_) {
          double ratio = 1.0;
          if (img.width! > 1600 || img.height! > 1200) {
            ratio = img.width! > img.height! ? 1600 / img.width! : 1200 / img.height!;
          }
          final w = (img.width! * ratio).toInt();
          final h = (img.height! * ratio).toInt();
          final canvas = html.CanvasElement(width: w, height: h);
          canvas.context2D.drawImageScaled(img, 0, 0, w, h);
          final compressed = canvas.toDataUrl('image/jpeg', 0.92);
          setState(() {
            _imageBase64 = compressed.split(',')[1];
            _result = ''; _explanation = ''; _extractedText = '';
          });
        });
      });
    });
  }

  Future<void> _translate() async {
    if (_imageBase64 == null) return;
    if (!_isVip && _freeLeft <= 0) { _showVipDialog(); return; }

    setState(() { _isLoading = true; _result = ''; _explanation = ''; _extractedText = ''; });
    if (!_isVip) setState(() => _freeLeft--);

    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/image',
        data: {'image_base64': _imageBase64, 'target_lang': 'vi', 'context': _systemContext},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _extractedText = response.data['extracted_text'] ?? '';
        _result = response.data['translated'] ?? '';
        _explanation = response.data['explanation'] ?? '';
      });
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
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_DS.orange, _DS.yellow]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('⭐', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            const Text('Nâng cấp VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text(
              'Hết lượt dịch ảnh miễn phí!\nVIP mở khóa:\n✅ Dịch ảnh không giới hạn\n✅ AI giải thích chi tiết hơn\n✅ Lưu lịch sử dịch ảnh',
              textAlign: TextAlign.center,
              style: TextStyle(color: _DS.textGrey, height: 1.6),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Text('Nâng cấp NT\$149/tháng',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Để sau', style: TextStyle(color: _DS.textGrey))),
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
        backgroundColor: _DS.white,
        foregroundColor: _DS.textDark,
        elevation: 0,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('📷', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Dịch ảnh AI', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 16)),
        ]),
        actions: [
          if (!_isVip)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('📷', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('$_freeLeft', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.orange)),
              ]),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Free quota bar
          if (!_isVip)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _freeLeft > 0 ? _DS.blueLight : _DS.yellowLight,
                borderRadius: BorderRadius.circular(_DS.radiusSm),
              ),
              child: Row(children: [
                Text(_freeLeft > 0 ? '📷 Còn $_freeLeft lượt miễn phí hôm nay' : '⚠️ Hết lượt miễn phí',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _freeLeft > 0 ? _DS.blue : _DS.orange)),
                const Spacer(),
                if (_freeLeft <= 0)
                  GestureDetector(
                    onTap: _showVipDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('VIP', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),

          // Image type selector
          const Text('Loại ảnh:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
          const SizedBox(height: 10),
          Row(
            children: _imageTypes.map((t) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: t == _imageTypes.last ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _imageType = t['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _imageType == t['key'] ? _DS.orangeLight : _DS.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _imageType == t['key'] ? _DS.orange : Colors.grey.shade200,
                        width: _imageType == t['key'] ? 2 : 1,
                      ),
                    ),
                    child: Column(children: [
                      Text(t['emoji']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(t['label']!, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: _imageType == t['key'] ? _DS.orange : _DS.textGrey,
                      )),
                    ]),
                  ),
                ),
              ),
            )).toList(),
          ),

          const SizedBox(height: 16),

          // Image picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity, height: 220,
              decoration: BoxDecoration(
                color: _DS.white,
                borderRadius: BorderRadius.circular(_DS.radius),
                border: Border.all(
                  color: _imageBase64 != null ? _DS.orange.withOpacity(0.5) : Colors.grey.shade200,
                  width: _imageBase64 != null ? 2 : 1,
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: _imageBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.contain),
                    )
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(color: _DS.orangeLight, shape: BoxShape.circle),
                        child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: _DS.orange),
                      ),
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
            Expanded(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _DS.white,
                    borderRadius: BorderRadius.circular(_DS.radiusSm),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_library_rounded, size: 18, color: _DS.textDark),
                    SizedBox(width: 8),
                    Text('Chọn ảnh khác', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textDark, fontSize: 13)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: (_imageBase64 != null && !_isLoading) ? _translate : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _imageBase64 != null
                        ? const LinearGradient(colors: [_DS.orange, _DS.yellow])
                        : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]),
                    borderRadius: BorderRadius.circular(_DS.radiusSm),
                    boxShadow: _imageBase64 != null
                        ? [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.translate_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(_isLoading ? 'Đang dịch...' : 'Dịch ảnh',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // Result
          if (_extractedText.isNotEmpty || _result.isNotEmpty) ...[
            // Extracted text
            if (_extractedText.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _DS.white,
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.text_fields_rounded, size: 14, color: _DS.textGrey),
                    SizedBox(width: 6),
                    Text('Văn bản nhận diện được:', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(_extractedText, style: const TextStyle(fontSize: 14, color: _DS.textDark, height: 1.5)),
                ]),
              ),

            // Translation result
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _DS.white,
                borderRadius: BorderRadius.circular(_DS.radius),
                border: Border.all(color: _DS.orange.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.translate_rounded, size: 14, color: _DS.orange),
                  SizedBox(width: 6),
                  Text('Bản dịch:', style: TextStyle(fontSize: 12, color: _DS.orange, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                Text(_result, style: const TextStyle(fontSize: 16, color: _DS.textDark, height: 1.6, fontWeight: FontWeight.w600)),
                if (_explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('💡 Giải thích:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textGrey)),
                      const SizedBox(height: 6),
                      Text(_explanation, style: const TextStyle(fontSize: 13, color: _DS.textGrey, height: 1.5)),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _result));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Đã sao chép!'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 1),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.copy_rounded, size: 14, color: _DS.textGrey),
                        SizedBox(width: 6),
                        Text('Sao chép', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}