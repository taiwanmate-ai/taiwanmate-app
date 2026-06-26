// ═══════════════════════════════════════════════════════════════
// JOURNEY TAB — Lộ trình 30 ngày sinh tồn tiếng Trung tại Đài Loan
// File: lib/features/learn/presentation/widgets/journey.dart
// Song ngữ: Trung (phồn thể) + pinyin + Việt + Anh
// Lưu tiến độ hoàn thành bằng flutter_secure_storage
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Design System (đồng bộ với learn_screen / learning_path) ──
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── Một mục từ/câu trong ngày ────────────────────────────────
class _Phrase {
  final String zh;   // Trung phồn thể
  final String py;   // pinyin
  final String vi;   // tiếng Việt
  final String en;   // tiếng Anh
  const _Phrase(this.zh, this.py, this.vi, this.en);
}

// ─── Một ngày trong lộ trình ──────────────────────────────────
class _Day {
  final int day;
  final String emoji;
  final String titleVi;
  final String titleEn;
  final List<_Phrase> phrases;
  const _Day({
    required this.day,
    required this.emoji,
    required this.titleVi,
    required this.titleEn,
    required this.phrases,
  });
}

// ─── DỮ LIỆU 30 NGÀY ──────────────────────────────────────────
const List<_Day> _journey = [
  _Day(day: 1, emoji: '👋', titleVi: 'Chào hỏi cơ bản', titleEn: 'Basic Greetings', phrases: [
    _Phrase('你好', 'nǐ hǎo', 'Xin chào', 'Hello'),
    _Phrase('謝謝', 'xiè xie', 'Cảm ơn', 'Thank you'),
    _Phrase('再見', 'zài jiàn', 'Tạm biệt', 'Goodbye'),
    _Phrase('對不起', 'duì bù qǐ', 'Xin lỗi', 'Sorry'),
    _Phrase('沒關係', 'méi guān xi', 'Không sao', "It's okay"),
  ]),
  _Day(day: 2, emoji: '🔢', titleVi: 'Số đếm', titleEn: 'Numbers', phrases: [
    _Phrase('一', 'yī', 'Một', 'One'),
    _Phrase('二', 'èr', 'Hai', 'Two'),
    _Phrase('三', 'sān', 'Ba', 'Three'),
    _Phrase('十', 'shí', 'Mười', 'Ten'),
    _Phrase('一百', 'yì bǎi', 'Một trăm', 'One hundred'),
  ]),
  _Day(day: 3, emoji: '🙋', titleVi: 'Giới thiệu bản thân', titleEn: 'Self Introduction', phrases: [
    _Phrase('我叫', 'wǒ jiào', 'Tôi tên là', 'My name is'),
    _Phrase('我是越南人', 'wǒ shì yuè nán rén', 'Tôi là người Việt Nam', 'I am Vietnamese'),
    _Phrase('我來自越南', 'wǒ lái zì yuè nán', 'Tôi đến từ Việt Nam', 'I come from Vietnam'),
    _Phrase('認識你很高興', 'rèn shi nǐ hěn gāo xìng', 'Rất vui được gặp bạn', 'Nice to meet you'),
    _Phrase('你叫什麼名字', 'nǐ jiào shén me míng zì', 'Bạn tên gì?', "What's your name?"),
  ]),
  _Day(day: 4, emoji: '🛒', titleVi: 'Mua sắm', titleEn: 'Shopping', phrases: [
    _Phrase('多少錢', 'duō shǎo qián', 'Bao nhiêu tiền?', 'How much?'),
    _Phrase('太貴了', 'tài guì le', 'Đắt quá', 'Too expensive'),
    _Phrase('便宜一點', 'pián yí yì diǎn', 'Rẻ hơn chút đi', 'Cheaper please'),
    _Phrase('我要這個', 'wǒ yào zhè ge', 'Tôi muốn cái này', 'I want this'),
    _Phrase('可以刷卡嗎', 'kě yǐ shuā kǎ ma', 'Quẹt thẻ được không?', 'Can I pay by card?'),
  ]),
  _Day(day: 5, emoji: '🍜', titleVi: 'Ăn uống', titleEn: 'Food & Dining', phrases: [
    _Phrase('我餓了', 'wǒ è le', 'Tôi đói rồi', "I'm hungry"),
    _Phrase('好吃', 'hǎo chī', 'Ngon', 'Delicious'),
    _Phrase('我要一碗麵', 'wǒ yào yì wǎn miàn', 'Cho tôi một tô mì', 'One bowl of noodles'),
    _Phrase('不要辣', 'bú yào là', 'Không cay', 'Not spicy'),
    _Phrase('買單', 'mǎi dān', 'Tính tiền', 'Check please'),
  ]),
  _Day(day: 6, emoji: '🚇', titleVi: 'Đi lại', titleEn: 'Transportation', phrases: [
    _Phrase('捷運站在哪裡', 'jié yùn zhàn zài nǎ lǐ', 'Ga MRT ở đâu?', 'Where is the MRT?'),
    _Phrase('我要去', 'wǒ yào qù', 'Tôi muốn đi', 'I want to go to'),
    _Phrase('多遠', 'duō yuǎn', 'Bao xa?', 'How far?'),
    _Phrase('停這裡', 'tíng zhè lǐ', 'Dừng ở đây', 'Stop here'),
    _Phrase('悠遊卡', 'yōu yóu kǎ', 'Thẻ EasyCard', 'EasyCard'),
  ]),
  _Day(day: 7, emoji: '🏥', titleVi: 'Bệnh viện', titleEn: 'Hospital', phrases: [
    _Phrase('我生病了', 'wǒ shēng bìng le', 'Tôi bị bệnh', "I'm sick"),
    _Phrase('我頭痛', 'wǒ tóu tòng', 'Tôi đau đầu', 'I have a headache'),
    _Phrase('我要看醫生', 'wǒ yào kàn yī shēng', 'Tôi cần gặp bác sĩ', 'I need a doctor'),
    _Phrase('健保卡', 'jiàn bǎo kǎ', 'Thẻ bảo hiểm y tế', 'Health insurance card'),
    _Phrase('藥局在哪', 'yào jú zài nǎ', 'Nhà thuốc ở đâu?', 'Where is the pharmacy?'),
  ]),
  _Day(day: 8, emoji: '💼', titleVi: 'Công việc', titleEn: 'Work', phrases: [
    _Phrase('我在工廠工作', 'wǒ zài gōng chǎng gōng zuò', 'Tôi làm ở nhà máy', 'I work in a factory'),
    _Phrase('加班', 'jiā bān', 'Tăng ca', 'Overtime'),
    _Phrase('休息', 'xiū xi', 'Nghỉ ngơi', 'Rest'),
    _Phrase('薪水', 'xīn shuǐ', 'Lương', 'Salary'),
    _Phrase('請假', 'qǐng jià', 'Xin nghỉ phép', 'Take leave'),
  ]),
  _Day(day: 9, emoji: '🏠', titleVi: 'Nhà ở', titleEn: 'Housing', phrases: [
    _Phrase('租房子', 'zū fáng zi', 'Thuê nhà', 'Rent a house'),
    _Phrase('房租多少', 'fáng zū duō shǎo', 'Tiền thuê bao nhiêu?', 'How much is the rent?'),
    _Phrase('押金', 'yā jīn', 'Tiền đặt cọc', 'Deposit'),
    _Phrase('水電費', 'shuǐ diàn fèi', 'Tiền điện nước', 'Utility bills'),
    _Phrase('房東', 'fáng dōng', 'Chủ nhà', 'Landlord'),
  ]),
  _Day(day: 10, emoji: '🏦', titleVi: 'Ngân hàng', titleEn: 'Bank', phrases: [
    _Phrase('開戶', 'kāi hù', 'Mở tài khoản', 'Open an account'),
    _Phrase('提款', 'tí kuǎn', 'Rút tiền', 'Withdraw money'),
    _Phrase('匯款', 'huì kuǎn', 'Chuyển tiền', 'Transfer money'),
    _Phrase('寄錢回越南', 'jì qián huí yuè nán', 'Gửi tiền về Việt Nam', 'Send money to Vietnam'),
    _Phrase('提款機', 'tí kuǎn jī', 'Máy ATM', 'ATM'),
  ]),
  _Day(day: 11, emoji: '📱', titleVi: 'Điện thoại & SIM', titleEn: 'Phone & SIM', phrases: [
    _Phrase('我要辦門號', 'wǒ yào bàn mén hào', 'Tôi muốn đăng ký SIM', 'I want a phone number'),
    _Phrase('上網', 'shàng wǎng', 'Lên mạng', 'Internet'),
    _Phrase('充值', 'chōng zhí', 'Nạp tiền', 'Top up'),
    _Phrase('沒有訊號', 'méi yǒu xùn hào', 'Không có sóng', 'No signal'),
    _Phrase('無線網路', 'wú xiàn wǎng lù', 'Wifi', 'Wifi'),
  ]),
  _Day(day: 12, emoji: '🆘', titleVi: 'Khẩn cấp', titleEn: 'Emergency', phrases: [
    _Phrase('救命', 'jiù mìng', 'Cứu với', 'Help'),
    _Phrase('報警', 'bào jǐng', 'Báo cảnh sát', 'Call the police'),
    _Phrase('叫救護車', 'jiào jiù hù chē', 'Gọi xe cứu thương', 'Call an ambulance'),
    _Phrase('我需要幫助', 'wǒ xū yào bāng zhù', 'Tôi cần giúp đỡ', 'I need help'),
    _Phrase('失火了', 'shī huǒ le', 'Cháy rồi', 'Fire'),
  ]),
  _Day(day: 13, emoji: '⏰', titleVi: 'Thời gian', titleEn: 'Time', phrases: [
    _Phrase('現在幾點', 'xiàn zài jǐ diǎn', 'Mấy giờ rồi?', 'What time is it?'),
    _Phrase('今天', 'jīn tiān', 'Hôm nay', 'Today'),
    _Phrase('明天', 'míng tiān', 'Ngày mai', 'Tomorrow'),
    _Phrase('昨天', 'zuó tiān', 'Hôm qua', 'Yesterday'),
    _Phrase('星期幾', 'xīng qí jǐ', 'Thứ mấy?', 'What day?'),
  ]),
  _Day(day: 14, emoji: '🌤️', titleVi: 'Thời tiết', titleEn: 'Weather', phrases: [
    _Phrase('天氣很好', 'tiān qì hěn hǎo', 'Thời tiết đẹp', 'Nice weather'),
    _Phrase('下雨', 'xià yǔ', 'Trời mưa', 'Raining'),
    _Phrase('很熱', 'hěn rè', 'Rất nóng', 'Very hot'),
    _Phrase('很冷', 'hěn lěng', 'Rất lạnh', 'Very cold'),
    _Phrase('颱風', 'tái fēng', 'Bão', 'Typhoon'),
  ]),
  _Day(day: 15, emoji: '🧭', titleVi: 'Hỏi đường', titleEn: 'Directions', phrases: [
    _Phrase('怎麼走', 'zěn me zǒu', 'Đi thế nào?', 'How to get there?'),
    _Phrase('左轉', 'zuǒ zhuǎn', 'Rẽ trái', 'Turn left'),
    _Phrase('右轉', 'yòu zhuǎn', 'Rẽ phải', 'Turn right'),
    _Phrase('直走', 'zhí zǒu', 'Đi thẳng', 'Go straight'),
    _Phrase('在哪裡', 'zài nǎ lǐ', 'Ở đâu?', 'Where?'),
  ]),
  _Day(day: 16, emoji: '🛂', titleVi: 'Giấy tờ & visa', titleEn: 'Documents & Visa', phrases: [
    _Phrase('居留證', 'jū liú zhèng', 'Thẻ cư trú (ARC)', 'Residence card'),
    _Phrase('護照', 'hù zhào', 'Hộ chiếu', 'Passport'),
    _Phrase('簽證', 'qiān zhèng', 'Visa', 'Visa'),
    _Phrase('延長', 'yán cháng', 'Gia hạn', 'Extend'),
    _Phrase('移民署', 'yí mín shǔ', 'Sở di trú', 'Immigration office'),
  ]),
  _Day(day: 17, emoji: '👥', titleVi: 'Gia đình', titleEn: 'Family', phrases: [
    _Phrase('家人', 'jiā rén', 'Người nhà', 'Family'),
    _Phrase('爸爸', 'bà ba', 'Bố', 'Father'),
    _Phrase('媽媽', 'mā ma', 'Mẹ', 'Mother'),
    _Phrase('孩子', 'hái zi', 'Con cái', 'Children'),
    _Phrase('我想家', 'wǒ xiǎng jiā', 'Tôi nhớ nhà', 'I miss home'),
  ]),
  _Day(day: 18, emoji: '💬', titleVi: 'Giao tiếp hàng ngày', titleEn: 'Daily Talk', phrases: [
    _Phrase('你好嗎', 'nǐ hǎo ma', 'Bạn khỏe không?', 'How are you?'),
    _Phrase('我很好', 'wǒ hěn hǎo', 'Tôi khỏe', "I'm fine"),
    _Phrase('什麼意思', 'shén me yì si', 'Nghĩa là gì?', 'What does it mean?'),
    _Phrase('我不懂', 'wǒ bù dǒng', 'Tôi không hiểu', "I don't understand"),
    _Phrase('請再說一次', 'qǐng zài shuō yí cì', 'Nói lại lần nữa', 'Say it again please'),
  ]),
  _Day(day: 19, emoji: '🏪', titleVi: 'Siêu thị tiện lợi', titleEn: 'Convenience Store', phrases: [
    _Phrase('便利商店', 'biàn lì shāng diàn', 'Cửa hàng tiện lợi', 'Convenience store'),
    _Phrase('袋子', 'dài zi', 'Túi', 'Bag'),
    _Phrase('要袋子嗎', 'yào dài zi ma', 'Cần túi không?', 'Need a bag?'),
    _Phrase('收據', 'shōu jù', 'Hóa đơn', 'Receipt'),
    _Phrase('微波', 'wéi bō', 'Hâm nóng', 'Microwave'),
  ]),
  _Day(day: 20, emoji: '✉️', titleVi: 'Bưu điện', titleEn: 'Post Office', phrases: [
    _Phrase('郵局', 'yóu jú', 'Bưu điện', 'Post office'),
    _Phrase('寄包裹', 'jì bāo guǒ', 'Gửi bưu kiện', 'Send a package'),
    _Phrase('郵票', 'yóu piào', 'Tem', 'Stamp'),
    _Phrase('地址', 'dì zhǐ', 'Địa chỉ', 'Address'),
    _Phrase('多久會到', 'duō jiǔ huì dào', 'Bao lâu thì tới?', 'How long to arrive?'),
  ]),
  _Day(day: 21, emoji: '🧑‍⚖️', titleVi: 'Quyền lao động', titleEn: 'Labor Rights', phrases: [
    _Phrase('勞工', 'láo gōng', 'Người lao động', 'Worker'),
    _Phrase('合約', 'hé yuē', 'Hợp đồng', 'Contract'),
    _Phrase('勞保', 'láo bǎo', 'Bảo hiểm lao động', 'Labor insurance'),
    _Phrase('仲介', 'zhòng jiè', 'Môi giới', 'Broker'),
    _Phrase('我的權利', 'wǒ de quán lì', 'Quyền lợi của tôi', 'My rights'),
  ]),
  _Day(day: 22, emoji: '🎌', titleVi: 'Văn hóa Đài Loan', titleEn: 'Taiwan Culture', phrases: [
    _Phrase('夜市', 'yè shì', 'Chợ đêm', 'Night market'),
    _Phrase('珍珠奶茶', 'zhēn zhū nǎi chá', 'Trà sữa trân châu', 'Bubble tea'),
    _Phrase('過年', 'guò nián', 'Tết', 'New Year'),
    _Phrase('紅包', 'hóng bāo', 'Lì xì', 'Red envelope'),
    _Phrase('拜拜', 'bài bài', 'Cúng bái', 'Worship'),
  ]),
  _Day(day: 23, emoji: '💳', titleVi: 'Thanh toán', titleEn: 'Payment', phrases: [
    _Phrase('現金', 'xiàn jīn', 'Tiền mặt', 'Cash'),
    _Phrase('找錢', 'zhǎo qián', 'Tiền thối', 'Change'),
    _Phrase('發票', 'fā piào', 'Hóa đơn (xổ số)', 'Invoice'),
    _Phrase('行動支付', 'xíng dòng zhī fù', 'Thanh toán di động', 'Mobile payment'),
    _Phrase('刷卡', 'shuā kǎ', 'Quẹt thẻ', 'Pay by card'),
  ]),
  _Day(day: 24, emoji: '🩺', titleVi: 'Triệu chứng bệnh', titleEn: 'Symptoms', phrases: [
    _Phrase('發燒', 'fā shāo', 'Sốt', 'Fever'),
    _Phrase('咳嗽', 'ké sòu', 'Ho', 'Cough'),
    _Phrase('肚子痛', 'dù zi tòng', 'Đau bụng', 'Stomachache'),
    _Phrase('受傷', 'shòu shāng', 'Bị thương', 'Injured'),
    _Phrase('過敏', 'guò mǐn', 'Dị ứng', 'Allergy'),
  ]),
  _Day(day: 25, emoji: '🔧', titleVi: 'Sửa chữa & sự cố', titleEn: 'Repairs & Issues', phrases: [
    _Phrase('壞了', 'huài le', 'Hỏng rồi', "It's broken"),
    _Phrase('修理', 'xiū lǐ', 'Sửa chữa', 'Repair'),
    _Phrase('沒有電', 'méi yǒu diàn', 'Mất điện', 'No electricity'),
    _Phrase('沒有水', 'méi yǒu shuǐ', 'Mất nước', 'No water'),
    _Phrase('幫我修', 'bāng wǒ xiū', 'Sửa giúp tôi', 'Fix it for me'),
  ]),
  _Day(day: 26, emoji: '🗣️', titleVi: 'Cảm xúc', titleEn: 'Emotions', phrases: [
    _Phrase('開心', 'kāi xīn', 'Vui', 'Happy'),
    _Phrase('難過', 'nán guò', 'Buồn', 'Sad'),
    _Phrase('生氣', 'shēng qì', 'Tức giận', 'Angry'),
    _Phrase('累', 'lèi', 'Mệt', 'Tired'),
    _Phrase('擔心', 'dān xīn', 'Lo lắng', 'Worried'),
  ]),
  _Day(day: 27, emoji: '🤝', titleVi: 'Lịch sự & nhờ vả', titleEn: 'Politeness & Requests', phrases: [
    _Phrase('請', 'qǐng', 'Xin mời / làm ơn', 'Please'),
    _Phrase('可以幫我嗎', 'kě yǐ bāng wǒ ma', 'Giúp tôi được không?', 'Can you help me?'),
    _Phrase('麻煩你了', 'má fan nǐ le', 'Phiền bạn rồi', 'Sorry to trouble you'),
    _Phrase('沒問題', 'méi wèn tí', 'Không vấn đề gì', 'No problem'),
    _Phrase('當然', 'dāng rán', 'Tất nhiên', 'Of course'),
  ]),
  _Day(day: 28, emoji: '📋', titleVi: 'Phỏng vấn việc làm', titleEn: 'Job Interview', phrases: [
    _Phrase('找工作', 'zhǎo gōng zuò', 'Tìm việc', 'Looking for a job'),
    _Phrase('面試', 'miàn shì', 'Phỏng vấn', 'Interview'),
    _Phrase('我有經驗', 'wǒ yǒu jīng yàn', 'Tôi có kinh nghiệm', 'I have experience'),
    _Phrase('什麼時候上班', 'shén me shí hòu shàng bān', 'Khi nào đi làm?', 'When do I start?'),
    _Phrase('工作時間', 'gōng zuò shí jiān', 'Giờ làm việc', 'Working hours'),
  ]),
  _Day(day: 29, emoji: '🛡️', titleVi: 'An toàn & lừa đảo', titleEn: 'Safety & Scams', phrases: [
    _Phrase('小心', 'xiǎo xīn', 'Cẩn thận', 'Be careful'),
    _Phrase('騙人', 'piàn rén', 'Lừa đảo', 'Scam'),
    _Phrase('不要相信', 'bú yào xiāng xìn', 'Đừng tin', "Don't trust"),
    _Phrase('危險', 'wéi xiǎn', 'Nguy hiểm', 'Dangerous'),
    _Phrase('我要報警', 'wǒ yào bào jǐng', 'Tôi sẽ báo cảnh sát', 'I will call the police'),
  ]),
  _Day(day: 30, emoji: '🎓', titleVi: 'Tổng ôn & tự tin', titleEn: 'Review & Confidence', phrases: [
    _Phrase('我會說中文', 'wǒ huì shuō zhōng wén', 'Tôi biết nói tiếng Trung', 'I can speak Chinese'),
    _Phrase('我學了三十天', 'wǒ xué le sān shí tiān', 'Tôi đã học 30 ngày', 'I studied for 30 days'),
    _Phrase('我很努力', 'wǒ hěn nǔ lì', 'Tôi rất cố gắng', 'I work hard'),
    _Phrase('謝謝你的幫助', 'xiè xie nǐ de bāng zhù', 'Cảm ơn sự giúp đỡ', 'Thanks for your help'),
    _Phrase('我可以的', 'wǒ kě yǐ de', 'Tôi làm được', 'I can do it'),
  ]),
];

// ═══════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════
class JourneyTab extends StatefulWidget {
  final String lang; // 'zh' hoặc 'en' — quyết định hiển thị nghĩa Việt hay Anh
  const JourneyTab({super.key, required this.lang});

  @override
  State<JourneyTab> createState() => _JourneyTabState();
}

class _JourneyTabState extends State<JourneyTab> {
  final _storage = const FlutterSecureStorage();
  static const _key = 'journey_completed_days';
  Set<int> _completed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        _completed = raw.split(',').where((e) => e.isNotEmpty).map(int.parse).toSet();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleDay(int day) async {
    setState(() {
      if (_completed.contains(day)) {
        _completed.remove(day);
      } else {
        _completed.add(day);
      }
    });
    try {
      await _storage.write(key: _key, value: _completed.join(','));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _DS.orange));
    }
    final done = _completed.length;
    final progress = done / _journey.length;

    return Column(children: [
      // Thanh tiến độ tổng
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]),
          borderRadius: BorderRadius.circular(_DS.radius),
          boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🗺️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('Lộ trình 30 ngày',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text('$done/${_journey.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ]),
      ),
      // Danh sách 30 ngày
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _journey.length,
          itemBuilder: (context, i) => _buildDayCard(_journey[i]),
        ),
      ),
    ]);
  }

  Widget _buildDayCard(_Day d) {
    final isDone = _completed.contains(d.day);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radius),
        border: Border.all(color: isDone ? _DS.green.withOpacity(0.4) : Colors.transparent, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isDone ? _DS.greenLight : _DS.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(d.emoji, style: const TextStyle(fontSize: 22))),
          ),
          title: Text('Ngày ${d.day}: ${d.titleVi}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 15)),
          subtitle: Text(d.titleEn, style: const TextStyle(color: _DS.textGrey, fontSize: 12)),
          trailing: GestureDetector(
            onTap: () => _toggleDay(d.day),
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isDone ? _DS.green : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isDone ? _DS.green : _DS.textGrey.withOpacity(0.4), width: 2),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          children: d.phrases.map((p) => _buildPhrase(p)).toList(),
        ),
      ),
    );
  }

  Widget _buildPhrase(_Phrase p) {
    final meaning = widget.lang == 'en' ? p.en : p.vi;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(_DS.radiusSm)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(p.zh, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(p.py, style: const TextStyle(fontSize: 13, color: _DS.orange, fontStyle: FontStyle.italic)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(meaning, style: const TextStyle(fontSize: 14, color: _DS.textDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(widget.lang == 'en' ? p.vi : p.en,
            style: const TextStyle(fontSize: 12, color: _DS.textGrey)),
      ]),
    );
  }
}