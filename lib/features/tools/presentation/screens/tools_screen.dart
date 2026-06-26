import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'dart:convert';
import 'dart:math' as math;

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
    key: 'pronunciation', emoji: 'ðŸŽ¤', title: 'Luyá»‡n phÃ¡t Ã¢m', subtitle: 'AI cháº¥m Ä‘iá»ƒm phÃ¡t Ã¢m',
    gradient: [Color(0xFF2979FF), Color(0xFF1565C0)],
    quickPrompts: ['PhÃ¡t Ã¢m tá»« "è¬è¬" Ä‘Ãºng chÆ°a?', 'Dáº¡y tÃ´i Ã¢m "ã„“ã„”ã„•"', 'Lá»—i phÃ¡t Ã¢m thÆ°á»ng gáº·p lÃ  gÃ¬?'],
    system: 'Báº¡n lÃ  giÃ¡o viÃªn dáº¡y phÃ¡t Ã¢m tiáº¿ng Trung (ÄÃ i Loan). Khi ngÆ°á»i dÃ¹ng nháº­p tá»«/cÃ¢u, hÃ£y: 1) PhiÃªn Ã¢m bopomofo, 2) HÆ°á»›ng dáº«n cÃ¡ch phÃ¡t Ã¢m chi tiáº¿t, 3) CÃ¡c lá»—i thÆ°á»ng gáº·p, 4) VÃ­ dá»¥ cÃ¢u. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t. KHÃ”NG viáº¿t pinyin.',
  ),
  _ToolConfig(
    key: 'grammar', emoji: 'ðŸ“–', title: 'Ngá»¯ phÃ¡p', subtitle: 'Giáº£i thÃ­ch chi tiáº¿t',
    gradient: [Color(0xFF00C853), Color(0xFF2E7D32)],
    quickPrompts: ['Giáº£i thÃ­ch cáº¥u trÃºc "æŠŠ" sentence', 'DÃ¹ng "äº†" khi nÃ o?', 'PhÃ¢n biá»‡t çš„/åœ°/å¾—'],
    system: 'Báº¡n lÃ  giÃ¡o viÃªn ngá»¯ phÃ¡p tiáº¿ng Trung. PhÃ¢n tÃ­ch cáº¥u trÃºc cÃ¢u, giáº£i thÃ­ch tá»«ng thÃ nh pháº§n, cho vÃ­ dá»¥ thá»±c táº¿. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t. KHÃ”NG viáº¿t pinyin.',
  ),
  _ToolConfig(
    key: 'context_translate', emoji: 'ðŸ”¤', title: 'Dá»‹ch cÃ³ ngá»¯ cáº£nh', subtitle: 'Dá»‹ch kÃ¨m vÄƒn hÃ³a, cÃ¡ch dÃ¹ng',
    gradient: [Color(0xFF009688), Color(0xFF00695C)],
    quickPrompts: ['Dá»‹ch "æ²’é—œä¿‚" vá»›i Ä‘áº§y Ä‘á»§ nghÄ©a', '"è¾›è‹¦äº†" dÃ¹ng lÃºc nÃ o?', 'Dá»‹ch menu nÃ y giÃºp tÃ´i'],
    system: 'Báº¡n lÃ  phiÃªn dá»‹ch viÃªn chuyÃªn nghiá»‡p Viá»‡t-Trung. Dá»‹ch chÃ­nh xÃ¡c, giáº£i thÃ­ch ngá»¯ cáº£nh, cÃ¡c cÃ¡ch diá»…n Ä‘áº¡t khÃ¡c, lÆ°u Ã½ vÄƒn hÃ³a. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
  _ToolConfig(
    key: 'work', emoji: 'ðŸ’¼', title: 'CÃ´ng viá»‡c', subtitle: 'Email, há»£p Ä‘á»“ng, cÃ´ng sá»Ÿ',
    gradient: [Color(0xFFFF6B35), Color(0xFFE65100)],
    quickPrompts: ['Soáº¡n email xin nghá»‰ phÃ©p', 'Giáº£i thÃ­ch Ä‘iá»u khoáº£n há»£p Ä‘á»“ng nÃ y', 'CÃ¡ch nÃ³i chuyá»‡n vá»›i sáº¿p ÄÃ i Loan'],
    isPopular: true,
    system: 'Báº¡n lÃ  trá»£ lÃ½ há»— trá»£ ngÆ°á»i Viá»‡t lÃ m viá»‡c á»Ÿ ÄÃ i Loan. GiÃºp soáº¡n email, giáº£i thÃ­ch há»£p Ä‘á»“ng, tá»« vá»±ng cÃ´ng sá»Ÿ, cÃ¡ch giao tiáº¿p chuyÃªn nghiá»‡p. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t, kÃ¨m tiáº¿ng Trung khi cáº§n.',
  ),
  _ToolConfig(
    key: 'medical', emoji: 'ðŸ¥', title: 'Y táº¿ & NHI', subtitle: 'Bá»‡nh viá»‡n, báº£o hiá»ƒm',
    gradient: [Color(0xFFE91E8C), Color(0xFFAD1457)],
    quickPrompts: ['TÃ´i bá»‹ sá»‘t cáº§n lÃ m gÃ¬?', 'Giáº£i thÃ­ch tháº» NHI cho tÃ´i', 'Thuá»‘c nÃ y uá»‘ng tháº¿ nÃ o?'],
    isPopular: true,
    system: 'Báº¡n lÃ  trá»£ lÃ½ y táº¿ cho ngÆ°á»i Viá»‡t á»Ÿ ÄÃ i Loan. GiÃºp hiá»ƒu NHI (å…¨æ°‘å¥ä¿), tá»« vá»±ng bá»‡nh viá»‡n, Ä‘á»c Ä‘Æ¡n thuá»‘c, quy trÃ¬nh khÃ¡m bá»‡nh. LuÃ´n nháº¯c tham kháº£o bÃ¡c sÄ©. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
  _ToolConfig(
    key: 'admin', emoji: 'ðŸ›ï¸', title: 'HÃ nh chÃ­nh', subtitle: 'ARC, visa, Ä‘Äƒng kÃ½',
    gradient: [Color(0xFF7C4DFF), Color(0xFF4527A0)],
    quickPrompts: ['Gia háº¡n ARC cáº§n giáº¥y tá» gÃ¬?', 'Má»Ÿ tÃ i khoáº£n ngÃ¢n hÃ ng tháº¿ nÃ o?', 'ÄÄƒng kÃ½ SIM card á»Ÿ Ä‘Ã¢u?'],
    system: 'Báº¡n lÃ  trá»£ lÃ½ thá»§ tá»¥c hÃ nh chÃ­nh cho ngÆ°á»i Viá»‡t á»Ÿ ÄÃ i Loan. HÆ°á»›ng dáº«n ARC, visa, Ä‘Äƒng kÃ½ há»™ kháº©u, má»Ÿ tÃ i khoáº£n ngÃ¢n hÃ ng. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t, rÃµ rÃ ng tá»«ng bÆ°á»›c.',
  ),
  _ToolConfig(
    key: 'daily', emoji: 'ðŸœ', title: 'áº¨m thá»±c & Mua sáº¯m', subtitle: 'Menu, máº·c cáº£, Ä‘áº·t hÃ ng',
    gradient: [Color(0xFFFF5722), Color(0xFFBF360C)],
    quickPrompts: ['Dá»‹ch menu nÃ y cho tÃ´i', 'CÃ¡ch máº·c cáº£ á»Ÿ chá»£ Ä‘Ãªm', 'Gá»i mÃ³n khÃ´ng cÃ³ rau mÃ¹i'],
    system: 'Báº¡n lÃ  hÆ°á»›ng dáº«n viÃªn áº©m thá»±c vÃ  mua sáº¯m táº¡i ÄÃ i Loan cho ngÆ°á»i Viá»‡t. GiÃºp Ä‘á»c menu, gá»i mÃ³n, thÆ°Æ¡ng lÆ°á»£ng giÃ¡, mua sáº¯m. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t, kÃ¨m tiáº¿ng Trung thá»±c táº¿.',
  ),
  _ToolConfig(
    key: 'image_translate', emoji: 'ðŸ“·', title: 'Dá»‹ch áº£nh AI', subtitle: 'Há»£p Ä‘á»“ng, menu, biá»ƒn bÃ¡o',
    gradient: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    quickPrompts: ['Dá»‹ch há»£p Ä‘á»“ng lao Ä‘á»™ng', 'Dá»‹ch menu nhÃ  hÃ ng', 'Dá»‹ch biá»ƒn bÃ¡o Ä‘Æ°á»ng phá»‘'],
    isPopular: true,
    system: '',
  ),
  _ToolConfig(
    key: 'study_abroad', emoji: 'ðŸŽ“', title: 'Du há»c ÄÃ i Loan', subtitle: 'Lá»™ trÃ¬nh A-Z Â· Há»c bá»•ng Â· Visa',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    quickPrompts: ['TÃ´i vá»«a thi xong THPT, muá»‘n du há»c ÄÃ i Loan', 'Há»c bá»•ng MOE lÃ  gÃ¬, ná»™p nhÆ° tháº¿ nÃ o?', 'Chi phÃ­ du há»c ÄÃ i Loan háº¿t bao nhiÃªu?'],
    isPopular: true,
    system: '''Báº¡n lÃ  chuyÃªn gia tÆ° váº¥n du há»c ÄÃ i Loan cho há»c sinh Viá»‡t Nam, vá»›i kiáº¿n thá»©c chÃ­nh xÃ¡c tá»« nguá»“n chÃ­nh thá»‘ng (MOE, BOCA, TECO).
NGUYÃŠN Táº®C: CHá»ˆ cung cáº¥p thÃ´ng tin Ä‘Ã£ Ä‘Æ°á»£c xÃ¡c minh. LuÃ´n ghi rÃµ nguá»“n. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.''',
  ),
  _ToolConfig(
    key: 'tourism', emoji: 'ðŸ—ºï¸', title: 'Du lá»‹ch ÄÃ i Loan', subtitle: 'Äá»‹a Ä‘iá»ƒm, Äƒn uá»‘ng, di chuyá»ƒn',
    gradient: [Color(0xFF00897B), Color(0xFF00695C)],
    quickPrompts: ['ÄÃ i Báº¯c cÃ³ gÃ¬ hay chÆ¡i?', 'Äi Jiufen cáº§n chuáº©n bá»‹ gÃ¬?', 'Ä‚n gÃ¬ á»Ÿ ÄÃ i Nam?'],
    system: 'Báº¡n lÃ  hÆ°á»›ng dáº«n viÃªn du lá»‹ch ÄÃ i Loan chuyÃªn nghiá»‡p cho ngÆ°á»i Viá»‡t. TÆ° váº¥n Ä‘á»‹a Ä‘iá»ƒm, di chuyá»ƒn, Äƒn uá»‘ng, chi phÃ­ thá»±c táº¿. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
];

const _englishTools = [
  _ToolConfig(
    key: 'en_pronunciation', emoji: 'ðŸ—£ï¸', title: 'PhÃ¡t Ã¢m tiáº¿ng Anh', subtitle: 'AI sá»­a phÃ¡t Ã¢m, luyá»‡n accent',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    quickPrompts: ['PhÃ¡t Ã¢m "comfortable" Ä‘Ãºng khÃ´ng?', 'Sá»­a lá»—i phÃ¡t Ã¢m "th" cho tÃ´i', 'Accent Má»¹ khÃ¡c Anh tháº¿ nÃ o?'],
    system: 'Báº¡n lÃ  giÃ¡o viÃªn phÃ¡t Ã¢m tiáº¿ng Anh chuyÃªn nghiá»‡p. Khi user nháº­p tá»«/cÃ¢u tiáº¿ng Anh, phiÃªn Ã¢m IPA, hÆ°á»›ng dáº«n phÃ¡t Ã¢m, lá»—i ngÆ°á»i Viá»‡t hay máº¯c. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
  _ToolConfig(
    key: 'en_grammar', emoji: 'ðŸ“', title: 'Ngá»¯ phÃ¡p tiáº¿ng Anh', subtitle: 'Giáº£i thÃ­ch grammar thá»±c táº¿',
    gradient: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
    quickPrompts: ['Khi nÃ o dÃ¹ng "have been" vs "had been"?', 'PhÃ¢n biá»‡t "since" vÃ  "for"', 'CÃ¡ch dÃ¹ng conditional sentences'],
    system: 'Báº¡n lÃ  giÃ¡o viÃªn ngá»¯ phÃ¡p tiáº¿ng Anh cho ngÆ°á»i Viá»‡t. Giáº£i thÃ­ch ngá»¯ phÃ¡p rÃµ rÃ ng, cho vÃ­ dá»¥ thá»±c táº¿. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
  _ToolConfig(
    key: 'en_workplace', emoji: 'ðŸ’¼', title: 'Tiáº¿ng Anh cÃ´ng sá»Ÿ', subtitle: 'Email, há»p, thuyáº¿t trÃ¬nh',
    gradient: [Color(0xFF4527A0), Color(0xFF311B92)],
    quickPrompts: ['Soáº¡n email xin nghá»‰ phÃ©p báº±ng tiáº¿ng Anh', 'CÃ¡ch nÃ³i "tÃ´i khÃ´ng Ä‘á»“ng Ã½" lá»‹ch sá»±', 'Tá»« vá»±ng trong cuá»™c há»p'],
    isPopular: true,
    system: 'Báº¡n lÃ  chuyÃªn gia tiáº¿ng Anh cÃ´ng sá»Ÿ cho ngÆ°á»i Viá»‡t. GiÃºp soáº¡n email, giao tiáº¿p cuá»™c há»p, thuyáº¿t trÃ¬nh. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t, kÃ¨m tiáº¿ng Anh.',
  ),
  _ToolConfig(
    key: 'en_daily', emoji: 'ðŸŽ¬', title: 'Tiáº¿ng Anh thá»±c táº¿', subtitle: 'Slang, phim, nháº¡c, Gen Z',
    gradient: [Color(0xFFBF360C), Color(0xFF870000)],
    quickPrompts: ['"No cap" nghÄ©a lÃ  gÃ¬?', 'Slang Gen Z phá»• biáº¿n 2024', 'Hiá»ƒu cÃ¢u thoáº¡i phim nÃ y giÃºp tÃ´i'],
    system: 'Báº¡n lÃ  chuyÃªn gia tiáº¿ng Anh thá»±c táº¿, slang, vÄƒn hÃ³a pop cho ngÆ°á»i Viá»‡t. Giáº£i thÃ­ch slang, idiom, cÃ¡ch nÃ³i tá»± nhiÃªn. Tráº£ lá»i báº±ng tiáº¿ng Viá»‡t.',
  ),
];

class _JobSource {
  final String name, desc, emoji, url, tag;
  final Color color;
  const _JobSource({required this.name, required this.desc, required this.emoji, required this.url, required this.tag, required this.color});
}

const _jobSources = [
  _JobSource(name: '104äººåŠ›éŠ€è¡Œ', desc: 'Trang tÃ¬m viá»‡c lá»›n nháº¥t ÄÃ i Loan', emoji: 'ðŸ†', url: 'https://www.104.com.tw', tag: 'Phá»• biáº¿n nháº¥t', color: Color(0xFF2979FF)),
  _JobSource(name: '1111äººåŠ›éŠ€è¡Œ', desc: 'Lá»›n thá»© 2, nhiá»u viá»‡c part-time', emoji: 'â­', url: 'https://www.1111.com.tw', tag: 'Part-time', color: Color(0xFFFF6B35)),
  _JobSource(name: 'Cake.me', desc: 'Viá»‡c tech, startup, creative', emoji: 'ðŸŽ‚', url: 'https://www.cake.me/jobs', tag: 'Tech & Startup', color: Color(0xFF00C853)),
  _JobSource(name: 'LinkedIn', desc: 'Viá»‡c vÄƒn phÃ²ng, cÃ´ng ty nÆ°á»›c ngoÃ i', emoji: 'ðŸ’¼', url: 'https://www.linkedin.com/jobs', tag: 'VÄƒn phÃ²ng', color: Color(0xFF0A66C2)),
  _JobSource(name: 'WDA - Lao Ä‘á»™ng nÆ°á»›c ngoÃ i', desc: 'CÆ¡ quan chÃ­nh phá»§ há»— trá»£ lao Ä‘á»™ng nÆ°á»›c ngoÃ i', emoji: 'ðŸ›ï¸', url: 'https://fw.wda.gov.tw', tag: 'ChÃ­nh thá»©c', color: Color(0xFF7C4DFF)),
  _JobSource(name: 'LINE: TÆ° váº¥n viá»‡c lÃ m', desc: 'LiÃªn há»‡ mÃ´i giá»›i viá»‡c lÃ m trá»±c tiáº¿p qua LINE', emoji: 'ðŸ’¬', url: 'https://lin.ee/jISSjV4', tag: 'MÃ´i giá»›i', color: Color(0xFF00C300)),
  _JobSource(name: 'Yourator', desc: 'Startup, creative, mÃ´i trÆ°á»ng tráº»', emoji: 'ðŸš€', url: 'https://www.yourator.co', tag: 'Startup', color: Color(0xFFE91E8C)),
];

const _emergencyPhrases = [
  {'vi': 'TÃ´i cáº§n giÃºp Ä‘á»¡!', 'zh': 'æˆ‘éœ€è¦å¹«åŠ©ï¼', 'pinyin': 'WÇ’ xÅ«yÃ o bÄngzhÃ¹!', 'note': ''},
  {'vi': 'Gá»i cáº¥p cá»©u!', 'zh': 'å«æ•‘è­·è»Šï¼', 'pinyin': 'JiÃ o jiÃ¹hÃ¹chÄ“!', 'note': '119'},
  {'vi': 'Gá»i cáº£nh sÃ¡t!', 'zh': 'å«è­¦å¯Ÿï¼', 'pinyin': 'JiÃ o jÇngchÃ¡!', 'note': '110'},
  {'vi': 'TÃ´i bá»‹ láº¡c', 'zh': 'æˆ‘è¿·è·¯äº†', 'pinyin': 'WÇ’ mÃ­lÃ¹ le', 'note': ''},
  {'vi': 'TÃ´i bá»‹ á»‘m', 'zh': 'æˆ‘ç”Ÿç—…äº†', 'pinyin': 'WÇ’ shÄ“ngbÃ¬ng le', 'note': ''},
  {'vi': 'TÃ´i bá»‹ tai náº¡n', 'zh': 'æˆ‘å‡ºè»Šç¦äº†', 'pinyin': 'WÇ’ chÅ« chÄ“huÃ² le', 'note': ''},
  {'vi': 'Bá»‡nh viá»‡n á»Ÿ Ä‘Ã¢u?', 'zh': 'é†«é™¢åœ¨å“ªè£¡ï¼Ÿ', 'pinyin': 'YÄ«yuÃ n zÃ i nÇŽlÇ?', 'note': ''},
  {'vi': 'TÃ´i khÃ´ng hiá»ƒu tiáº¿ng Trung', 'zh': 'æˆ‘ä¸æ‡‚ä¸­æ–‡', 'pinyin': 'WÇ’ bÃ¹ dÇ’ng ZhÅngwÃ©n', 'note': ''},
  {'vi': 'CÃ³ ai nÃ³i tiáº¿ng Anh khÃ´ng?', 'zh': 'æœ‰äººèªªè‹±æ–‡å—Žï¼Ÿ', 'pinyin': 'YÇ’u rÃ©n shuÅ YÄ«ngwÃ©n ma?', 'note': ''},
  {'vi': 'Xin gá»i cho sá»‘ nÃ y', 'zh': 'è«‹æ‰“é€™å€‹é›»è©±', 'pinyin': 'QÇng dÇŽ zhÃ¨ge diÃ nhuÃ ', 'note': ''},
  {'vi': 'TÃ´i bá»‹ máº¥t há»™ chiáº¿u', 'zh': 'æˆ‘çš„è­·ç…§ä¸è¦‹äº†', 'pinyin': 'WÇ’ de hÃ¹zhÃ o bÃ¹ jiÃ n le', 'note': ''},
  {'vi': 'TÃ´i cáº§n thÃ´ng dá»‹ch viÃªn', 'zh': 'æˆ‘éœ€è¦ç¿»è­¯', 'pinyin': 'WÇ’ xÅ«yÃ o fÄnyÃ¬', 'note': ''},
  {'vi': 'Xin gá»i Ä‘áº¡i sá»© quÃ¡n Viá»‡t Nam', 'zh': 'è«‹æ‰“é›»è©±çµ¦è¶Šå—å¤§ä½¿é¤¨', 'pinyin': 'QÇng dÇŽ diÃ nhuÃ  gÄ›i YuÃ¨nÃ¡n dÃ shÇguÇŽn', 'note': '(+84-4) 3845-3637'},
  {'vi': 'TÃ´i bá»‹ chá»§ nhÃ  Ä‘uá»•i', 'zh': 'æˆ¿æ±æŠŠæˆ‘è¶•èµ°äº†', 'pinyin': 'FÃ¡ngdÅng bÇŽ wÇ’ gÇŽn zÇ’u le', 'note': ''},
  {'vi': 'TÃ´i chÆ°a Ä‘Æ°á»£c tráº£ lÆ°Æ¡ng', 'zh': 'æˆ‘é‚„æ²’æœ‰æ‹¿åˆ°è–ªæ°´', 'pinyin': 'WÇ’ hÃ¡i mÃ©iyÇ’u nÃ¡ dÃ o xÄ«nshuÇ', 'note': '1955'},
  {'vi': 'TÃ´i bá»‹ tai náº¡n lao Ä‘á»™ng', 'zh': 'æˆ‘ç™¼ç”Ÿå·¥å‚·äº†', 'pinyin': 'WÇ’ fÄshÄ“ng gÅngshÄng le', 'note': ''},
  {'vi': 'Xin chá»‰ Ä‘Æ°á»ng Ä‘áº¿n Ä‘á»“n cáº£nh sÃ¡t', 'zh': 'è«‹å‘Šè¨´æˆ‘è­¦å¯Ÿå±€åœ¨å“ªè£¡', 'pinyin': 'QÇng gÃ osÃ¹ wÇ’ jÇngchÃ¡jÃº zÃ i nÇŽlÇ', 'note': ''},
  {'vi': 'TÃ´i dá»‹ á»©ng vá»›i thuá»‘c nÃ y', 'zh': 'æˆ‘å°é€™å€‹è—¥éŽæ•', 'pinyin': 'WÇ’ duÃ¬ zhÃ¨ge yÃ o guÃ²mÇn', 'note': ''},
  {'vi': 'Xin viáº¿t xuá»‘ng giÃºp tÃ´i', 'zh': 'è«‹å¹«æˆ‘å¯«ä¸‹ä¾†', 'pinyin': 'QÇng bÄng wÇ’ xiÄ› xiÃ lÃ¡i', 'note': ''},
  {'vi': 'TÃ´i cáº§n vá» nhÃ  ngay', 'zh': 'æˆ‘éœ€è¦é¦¬ä¸Šå›žå®¶', 'pinyin': 'WÇ’ xÅ«yÃ o mÇŽshÃ ng huÃ­jiÄ', 'note': ''},
];

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TOOLS SCREEN
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _reminderExpanded = false;
  bool _rightsExpanded = false;
  bool _calcExpanded = false;
  double _salaryInput = 27470;

  // Reminder data
  final List<Map<String, dynamic>> _reminders = [
    {'icon': 'ðŸ›µ', 'label': 'PhÃ­ Ä‘Æ°á»ng bá»™ xe mÃ¡y', 'zh': 'ç‡ƒæ–™è²»', 'month': 4, 'note': 'NT\$900/nÄƒm Â· ThÃ¡ng 4'},
    {'icon': 'ðŸš—', 'label': 'PhÃ­ Ä‘Æ°á»ng bá»™ Ã´ tÃ´', 'zh': 'ç‰Œç…§ç¨…', 'month': 4, 'note': 'Theo cc xe Â· ThÃ¡ng 4'},
    {'icon': 'ðŸ”§', 'label': 'ÄÄƒng kiá»ƒm xe', 'zh': 'å®šæœŸæª¢é©—', 'month': 0, 'note': '2 nÄƒm/láº§n vá»›i xe má»›i'},
    {'icon': 'ðŸ›¡ï¸', 'label': 'Báº£o hiá»ƒm báº¯t buá»™c', 'zh': 'å¼·åˆ¶éšª', 'month': 0, 'note': 'HÃ ng nÄƒm Â· ~NT\$1,000'},
    {'icon': 'ðŸªª', 'label': 'Gia háº¡n ARC', 'zh': 'å±…ç•™è­‰', 'month': 0, 'note': 'TrÆ°á»›c 30 ngÃ y háº¿t háº¡n'},
    {'icon': 'ðŸ“‹', 'label': 'Khai thuáº¿ thu nháº­p', 'zh': 'ç¶œåˆæ‰€å¾—ç¨…', 'month': 5, 'note': 'ThÃ¡ng 5 hÃ ng nÄƒm'},
    {'icon': 'ðŸ¥', 'label': 'Kiá»ƒm tra NHI', 'zh': 'å…¨æ°‘å¥ä¿', 'month': 0, 'note': 'Kiá»ƒm tra Ä‘á»‹nh ká»³'},
  ];

  // Rights checklist
  final List<Map<String, dynamic>> _rights = [
    {'icon': 'ðŸ’°', 'label': 'LÆ°Æ¡ng tá»‘i thiá»ƒu 2024', 'zh': 'æœ€ä½Žè–ªè³‡', 'value': 'NT\$27,470/thÃ¡ng', 'checked': false},
    {'icon': 'ðŸ¥', 'label': 'Báº£o hiá»ƒm lao Ä‘á»™ng', 'zh': 'å‹žå·¥ä¿éšª', 'value': 'Sáº¿p pháº£i Ä‘Ã³ng', 'checked': false},
    {'icon': 'ðŸ¨', 'label': 'Báº£o hiá»ƒm y táº¿ NHI', 'zh': 'å…¨æ°‘å¥ä¿', 'value': 'Sáº¿p Ä‘Ã³ng 60%', 'checked': false},
    {'icon': 'ðŸ“…', 'label': 'NgÃ y nghá»‰ phÃ©p', 'zh': 'ç‰¹ä¼‘å‡', 'value': '3 ngÃ y/nÄƒm Ä‘áº§u', 'checked': false},
    {'icon': 'â°', 'label': 'Giá» lÃ m tá»‘i Ä‘a', 'zh': 'å·¥æ™‚ä¸Šé™', 'value': '40h/tuáº§n + OT cÃ³ phá»¥ cáº¥p', 'checked': false},
    {'icon': 'ðŸ¤°', 'label': 'Nghá»‰ thai sáº£n', 'zh': 'ç”¢å‡', 'value': '8 tuáº§n cÃ³ lÆ°Æ¡ng', 'checked': false},
  ];

  String get _contextualSituation {
    final h = DateTime.now().hour;
    final weekday = DateTime.now().weekday;
    final day = DateTime.now().day;
    if (day >= 25) return 'ðŸ“„ Cuá»‘i thÃ¡ng â€” Kiá»ƒm tra báº£ng lÆ°Æ¡ng';
    if (weekday == 1) return 'ðŸ’¼ Thá»© 2 â€” Dá»‹ch há»£p Ä‘á»“ng tuáº§n má»›i';
    if (weekday == 5 && h >= 17) return 'ðŸ’° Thá»© 6 chiá»u â€” TÃ­nh lÆ°Æ¡ng cuá»‘i tuáº§n';
    if (h < 10) return 'â˜€ï¸ SÃ¡ng sá»›m â€” Há»c tá»« vá»±ng cÃ´ng sá»Ÿ';
    if (h < 14) return 'ðŸœ Buá»•i trÆ°a â€” Gá»i mÃ³n tiáº¿ng Trung';
    if (h >= 20) return 'ðŸŒ™ Tá»‘i â€” Ã”n láº¡i Ä‘iá»u khoáº£n há»£p Ä‘á»“ng';
    return 'ðŸ› ï¸ CÃ´ng cá»¥ AI â€” DÃ nh riÃªng cho báº¡n';
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
            _buildSectionLabel('ðŸ§  Há»c tiáº¿ng Trung'),
            const SizedBox(height: 14),
            _buildToolGrid(_tools.sublist(0, 3)),
            const SizedBox(height: 24),
            _buildSectionLabel('ðŸ‡¹ðŸ‡¼ Sá»‘ng á»Ÿ ÄÃ i Loan'),
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

  // â”€â”€ HEADER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            Text('CÃ´ng cá»¥ AI', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
            Text('Báº£o vá»‡ quyá»n lá»£i ngÆ°á»i Viá»‡t táº¡i ÄÃ i Loan', style: TextStyle(fontSize: 11, color: Color(0xFFA78BFA))),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _DS.indigo, borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('âš¡', style: TextStyle(fontSize: 13)),
              SizedBox(width: 4),
              Text('15 cÃ´ng cá»¥', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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

  // â”€â”€ EMERGENCY STRIP â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            child: const Text('ðŸ†˜', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CÃ¢u kháº©n cáº¥p', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.red)),
            Text('110 Â· 119 Â· 1955 Â· 20 cÃ¢u cá»©u máº¡ng', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _DS.red),
        ]),
      ),
    );
  }

  // â”€â”€ CONTEXTUAL BANNER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildContextualBanner() {
    final hour = DateTime.now().hour;
    final suggestions = hour < 12
        ? ['Dá»‹ch thÃ´ng bÃ¡o tá»« sáº¿p', 'Soáº¡n email xin phÃ©p', 'Há»c tá»« vá»±ng cÃ´ng sá»Ÿ']
        : hour < 18
            ? ['Gá»i mÃ³n tiáº¿ng Trung', 'Kiá»ƒm tra lÆ°Æ¡ng thÃ¡ng nÃ y', 'Dá»‹ch tin nháº¯n']
            : ['Ã”n há»£p Ä‘á»“ng lao Ä‘á»™ng', 'Kiá»ƒm tra quyá»n lá»£i', 'Há»c tá»« má»›i'];

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
            const Text('ðŸ¤–', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Gá»£i Ã½ cho ${hour < 12 ? "buá»•i sÃ¡ng" : hour < 18 ? "buá»•i chiá»u" : "buá»•i tá»‘i"} hÃ´m nay',
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

  // â”€â”€ REMINDER CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  child: const Center(child: Text('ðŸ””', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Nháº¯c nhá»Ÿ phÃ­ Ä‘á»‹nh ká»³', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  if (urgent.isNotEmpty)
                    Text('âš ï¸ ${urgent.length} khoáº£n Ä‘áº¿n háº¡n thÃ¡ng nÃ y!',
                        style: const TextStyle(fontSize: 11, color: _DS.orange, fontWeight: FontWeight.w600))
                  else
                    const Text('Xe cá»™ Â· ARC Â· Thuáº¿ Â· Báº£o hiá»ƒm', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
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
                      Text('${r['zh']} Â· ${r['note']}', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                    ])),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _DS.yellow.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('ThÃ¡ng nÃ y!', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _DS.orange)),
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

  // â”€â”€ RIGHTS CARD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  child: const Center(child: Text('âš–ï¸', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Báº£n Ä‘á»“ quyá»n lá»£i', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  Text('$checkedCount/${_rights.length} quyá»n lá»£i Ä‘Ã£ xÃ¡c nháº­n',
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
                    'âœ… Tick vÃ o nhá»¯ng quyá»n lá»£i báº¡n Ä‘ang Ä‘Æ°á»£c hÆ°á»Ÿng. Náº¿u thiáº¿u â€” báº¡n cÃ³ quyá»n yÃªu cáº§u sáº¿p!',
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
                          Text('${r['zh']} Â· ${r['value']}', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
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
                      'âš ï¸ Báº¡n chÆ°a xÃ¡c nháº­n ${_rights.length - checkedCount} quyá»n lá»£i. LiÃªn há»‡ 1955 Ä‘á»ƒ Ä‘Æ°á»£c tÆ° váº¥n!',
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

  // â”€â”€ SURVIVAL CALCULATOR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  child: const Center(child: Text('ðŸ§®', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MÃ¡y tÃ­nh sinh tá»“n', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.textDark)),
                  Text('TÃ­nh lÆ°Æ¡ng thá»±c nháº­n Â· Chi phÃ­ Â· Gá»­i tiá»n vá»', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
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
                  const Text('ðŸ’°', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text('LÆ°Æ¡ng gross:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
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
                _buildCalcRow('ðŸ’µ LÆ°Æ¡ng thá»±c nháº­n', 'NT\$${_afterTaxSalary.toInt()}', _DS.green),
                const SizedBox(height: 8),
                _buildCalcRow('ðŸ  Tiá»n nhÃ  tá»‘i Ä‘a (30%)', 'NT\$${_maxRent.toInt()}', _DS.blue),
                const SizedBox(height: 8),
                _buildCalcRow('âœˆï¸ Gá»­i vá» VN (30%)', 'NT\$${_remittance.toInt()} â‰ˆ ${(_remittance * 800).toInt()} VNÄ', _DS.orange),
                const SizedBox(height: 8),
                _buildCalcRow('ðŸ¦ Tiáº¿t kiá»‡m (20%)', 'NT\$${_savingsTarget.toInt()}', _DS.purple),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    'ðŸ’¡ Sau khi trá»« báº£o hiá»ƒm lao Ä‘á»™ng (20%) vÃ  NHI (30%), lÆ°Æ¡ng thá»±c nháº­n tháº¥p hÆ¡n gross khoáº£ng 5-8%.',
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

  // â”€â”€ SECTIONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        const Text('ðŸ‡ºðŸ‡¸ Há»c tiáº¿ng Anh', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(10)),
          child: const Text('Má»›i', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.blue)),
        ),
      ]),
    ),
    const SizedBox(height: 14),
    _buildToolGrid(_englishTools),
  ]);

  Widget _buildJobSection(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ðŸ’¼ TÃ¬m viá»‡c & PhÃ¡t triá»ƒn', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _DS.textDark)),
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
              child: const Center(child: Text('ðŸ”', style: TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Text('TÃ¬m viá»‡c lÃ m', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                SizedBox(width: 8),
                _HotBadge(),
              ]),
              const SizedBox(height: 4),
              Text('7 nguá»“n tÃ¬m viá»‡c Â· AI soáº¡n CV Â· TÆ° váº¥n nghá» nghiá»‡p',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 8),
              Row(children: [
                _MiniTag(label: '104', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: '1111', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: 'LinkedIn', color: Colors.white),
                const SizedBox(width: 6),
                _MiniTag(label: '+4 ná»¯a', color: Colors.white),
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
            child: const Center(child: Text('ðŸ†˜', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CÃ¢u kháº©n cáº¥p', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 3),
            Text('20 cÃ¢u cáº§n thiáº¿t nháº¥t Â· DÃ¹ng Ä‘Æ°á»£c offline', style: TextStyle(fontSize: 12, color: Colors.white70)),
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

// â”€â”€â”€ Tool Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  child: const Text('ðŸ”¥ Phá»• biáº¿n', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
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
    child: const Text('ðŸ”¥ Má»›i', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EMERGENCY PAGE â€” Fix lá»—i láº·p cÃ¢u
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
          Text('ðŸ†˜', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('CÃ¢u kháº©n cáº¥p', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
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
              const Text('Sá»‘ Ä‘iá»‡n thoáº¡i kháº©n cáº¥p', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _EmergencyNumber(number: '110', label: 'Cáº£nh sÃ¡t'),
                _EmergencyNumber(number: '119', label: 'Cáº¥p cá»©u'),
                _EmergencyNumber(number: '1955', label: 'Lao Ä‘á»™ng'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Phrases â€” fixed no duplicate
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
                    content: const Text('ÄÃ£ sao chÃ©p!'),
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// JOB SEARCH PAGE â€” giá»¯ nguyÃªn
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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

  static const _systemPrompt = '''Báº¡n lÃ  chuyÃªn gia tÆ° váº¥n viá»‡c lÃ m cho ngÆ°á»i Viá»‡t táº¡i ÄÃ i Loan.
Nhiá»‡m vá»¥: tÆ° váº¥n loáº¡i viá»‡c phÃ¹ há»£p, giáº£i thÃ­ch yÃªu cáº§u tuyá»ƒn dá»¥ng, soáº¡n CV tiáº¿ng Trung, tÆ° váº¥n má»©c lÆ°Æ¡ng, hÆ°á»›ng dáº«n phá»ng váº¥n.
LuÃ´n tráº£ lá»i báº±ng tiáº¿ng Viá»‡t, kÃ¨m tiáº¿ng Trung khi cáº§n. CHá»ˆ dÃ¹ng Phá»“n thá»ƒ (ç¹é«”å­—).''';

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
      setState(() => _messages.add({'role': 'assistant', 'content': 'âš ï¸ Lá»—i káº¿t ná»‘i. Thá»­ láº¡i nhÃ©!'}));
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'âš ï¸ Lá»—i káº¿t ná»‘i. Thá»­ láº¡i nhÃ©!'}));
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
                child: const Center(child: Text('â­', style: TextStyle(fontSize: 36)))),
            const SizedBox(height: 16),
            const Text('NÃ¢ng cáº¥p VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            Text(limit != null ? 'GÃ³i Free giá»›i háº¡n $limit lÆ°á»£t/ngÃ y.\nVIP Ä‘á»ƒ há»i khÃ´ng giá»›i háº¡n!' : 'Háº¿t lÆ°á»£t miá»…n phÃ­!',
                textAlign: TextAlign.center, style: const TextStyle(color: _DS.textGrey, height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); PaymentService.openCheckout(plan: 'monthly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/33e90daf-ec9a-4ae7-88b9-5221d20c22d1'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: _DS.indigo, width: 2), borderRadius: BorderRadius.circular(16)),
                  child: const Text('NT\$199/thÃ¡ng', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.indigo))),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); PaymentService.openCheckout(plan: 'yearly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/f8fef26c-2235-4bf1-8e04-02252d8e9dac'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Text('NT\$1,099/nÄƒm Â· tiáº¿t kiá»‡m 38% ðŸ”¥', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Äá»ƒ sau', style: TextStyle(color: _DS.textGrey))),
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
          Text('ðŸ”', style: TextStyle(fontSize: 18)),
          SizedBox(width: 8),
          Text('TÃ¬m viá»‡c lÃ m', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
        centerTitle: false, elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _DS.yellow,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'ðŸŒ Nguá»“n tÃ¬m viá»‡c'), Tab(text: 'ðŸ¤– AI tÆ° váº¥n')],
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
          const Text('ðŸ’¡ Máº¹o tÃ¬m viá»‡c táº¡i ÄÃ i Loan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 8),
          Text('â€¢ Cáº§n ARC há»£p lá»‡ má»›i lÃ m viá»‡c Ä‘Æ°á»£c\nâ€¢ LÆ°Æ¡ng tá»‘i thiá»ƒu 2024: NT\$27,470/thÃ¡ng\nâ€¢ Part-time: max 20h/tuáº§n vá»›i visa há»c',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85), height: 1.6)),
        ]),
      ),
      const SizedBox(height: 20),
      const Text('ðŸŒ CÃ¡c trang tÃ¬m viá»‡c', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
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
      const Text('ðŸ¤– Há»i AI nhanh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        'ðŸ“ Soáº¡n CV tiáº¿ng Trung', 'ðŸ’° LÆ°Æ¡ng ngÃ nh F&B', 'ðŸ—£ï¸ CÃ¡ch phá»ng váº¥n', 'ðŸ“‹ Giáº£i thÃ­ch há»£p Ä‘á»“ng',
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
          child: const Center(child: Text('ðŸ¤–', style: TextStyle(fontSize: 40)))),
      const SizedBox(height: 16),
      const Text('AI TÆ° váº¥n viá»‡c lÃ m', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
      const SizedBox(height: 28),
      ...[
        'ðŸ“ Soáº¡n CV tiáº¿ng Trung cho tÃ´i â€” tÃ´i lÃ m nhÃ  hÃ ng 2 nÄƒm',
        'ðŸ’° LÆ°Æ¡ng trung bÃ¬nh ngÃ nh logistics á»Ÿ ÄÃ i Loan?',
        'ðŸ—£ï¸ CÃ¡ch giá»›i thiá»‡u báº£n thÃ¢n khi phá»ng váº¥n',
        'ðŸ“‹ Há»£p Ä‘á»“ng cÃ³ Ä‘iá»u khoáº£n "è©¦ç”¨æœŸ" lÃ  gÃ¬?',
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
              child: const Center(child: Text('ðŸ¤–', style: TextStyle(fontSize: 18)))),
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
          child: const Center(child: Text('ðŸ¤–', style: TextStyle(fontSize: 18)))),
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
          decoration: InputDecoration(hintText: 'Há»i vá» viá»‡c lÃ m, CV, phá»ng váº¥n...',
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// AI TOOL PAGE â€” giá»¯ nguyÃªn
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
      setState(() => _messages.add({'role': 'assistant', 'content': 'âš ï¸ Lá»—i káº¿t ná»‘i. Vui lÃ²ng thá»­ láº¡i.'}));
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'âš ï¸ Lá»—i káº¿t ná»‘i. Vui lÃ²ng thá»­ láº¡i.'}));
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
            const Text('ðŸ”’', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Háº¿t lÆ°á»£t ${widget.tool.title} hÃ´m nay',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('GÃ³i Free giá»›i háº¡n $limit lÆ°á»£t/ngÃ y.\nNÃ¢ng VIP Ä‘á»ƒ dÃ¹ng khÃ´ng giá»›i háº¡n!',
                textAlign: TextAlign.center, style: const TextStyle(color: _DS.textGrey)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); PaymentService.openCheckout(plan: 'monthly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/33e90daf-ec9a-4ae7-88b9-5221d20c22d1'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: _DS.indigo, width: 2), borderRadius: BorderRadius.circular(12)),
                  child: const Text('NT\$199/thÃ¡ng', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.indigo))),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () { Navigator.pop(ctx); PaymentService.openCheckout(plan: 'yearly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/f8fef26c-2235-4bf1-8e04-02252d8e9dac'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: widget.tool.gradient), borderRadius: BorderRadius.circular(12)),
                  child: const Text('NT\$1,099/nÄƒm Â· tiáº¿t kiá»‡m 38% ðŸ”¥', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Äá»ƒ sau', style: TextStyle(color: _DS.textGrey))),
          ]),
        ),
      ),
    );
  }

  void _copyAll() {
    final text = _messages.map((m) => '${m['role'] == 'user' ? 'TÃ´i' : widget.tool.title}: ${m['content']}').join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('âœ… ÄÃ£ sao chÃ©p!'),
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
                  Text('Sao chÃ©p', style: TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w700)),
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
        const Text('âœ… ÄÃ£ giáº£i quyáº¿t váº¥n Ä‘á» chÆ°a?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () { setState(() { _showCompletion = false; _showXp = true; }); Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _showXp = false); }); },
            child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _DS.greenLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('âœ… Xong rá»“i! +5 XP', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.green))),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _showCompletion = false),
            child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(10)),
                child: const Text('ðŸ™‹ Há»i thÃªm', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.indigo))),
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

// â”€â”€â”€ Tool Chat Bubble â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ToolChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final _ToolConfig tool;
  const _ToolChatBubble({required this.message, required this.isUser, required this.tool});

  Widget _buildHighlight(String text, Color color) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbfï¼Œã€‚ï¼ï¼Ÿã€ï¼šï¼›ã€Œã€]+');
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

// â”€â”€â”€ Typing dot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// IMAGE TRANSLATE PAGE â€” giá»¯ nguyÃªn logic, Ä‘á»•i mÃ u Indigo
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
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
    {'key': 'general', 'emoji': 'ðŸ“·', 'label': 'áº¢nh chung'},
    {'key': 'contract', 'emoji': 'ðŸ“‹', 'label': 'Há»£p Ä‘á»“ng'},
    {'key': 'menu', 'emoji': 'ðŸœ', 'label': 'Menu'},
    {'key': 'sign', 'emoji': 'ðŸª§', 'label': 'Biá»ƒn bÃ¡o'},
  ];

  String get _systemContext {
    switch (_imageType) {
      case 'contract': return 'ÄÃ¢y lÃ  há»£p Ä‘á»“ng lao Ä‘á»™ng. HÃ£y: 1) Dá»‹ch toÃ n bá»™ ná»™i dung, 2) Giáº£i thÃ­ch cÃ¡c Ä‘iá»u khoáº£n quan trá»ng, 3) Cáº£nh bÃ¡o Ä‘iá»u khoáº£n báº¥t lá»£i náº¿u cÃ³.';
      case 'menu': return 'ÄÃ¢y lÃ  menu nhÃ  hÃ ng. HÃ£y: 1) Dá»‹ch tÃªn mÃ³n Äƒn, 2) MÃ´ táº£ nguyÃªn liá»‡u chÃ­nh, 3) Gá»£i Ã½ mÃ³n phÃ¹ há»£p ngÆ°á»i Viá»‡t.';
      case 'sign': return 'ÄÃ¢y lÃ  biá»ƒn bÃ¡o/thÃ´ng bÃ¡o. HÃ£y dá»‹ch chÃ­nh xÃ¡c vÃ  giáº£i thÃ­ch Ã½ nghÄ©a thá»±c táº¿.';
      default: return 'Dá»‹ch toÃ n bá»™ vÄƒn báº£n trong áº£nh vÃ  giáº£i thÃ­ch ngáº¯n gá»n.';
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
      setState(() => _result = 'âš ï¸ Lá»—i káº¿t ná»‘i. Thá»­ láº¡i nhÃ©!');
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
                child: const Center(child: Text('â­', style: TextStyle(fontSize: 36)))),
            const SizedBox(height: 16),
            const Text('NÃ¢ng cáº¥p VIP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text('Háº¿t lÆ°á»£t dá»‹ch áº£nh miá»…n phÃ­!\nVIP má»Ÿ khÃ³a dá»‹ch áº£nh khÃ´ng giá»›i háº¡n!',
                textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, height: 1.6)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () { Navigator.pop(context); PaymentService.openCheckout(plan: 'monthly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/33e90daf-ec9a-4ae7-88b9-5221d20c22d1'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: Border.all(color: _DS.indigo, width: 2), borderRadius: BorderRadius.circular(16)),
                  child: const Text('NT\$199/thÃ¡ng', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.indigo))),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () { Navigator.pop(context); PaymentService.openCheckout(plan: 'yearly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/f8fef26c-2235-4bf1-8e04-02252d8e9dac'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]), borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: const Text('NT\$1,099/nÄƒm Â· tiáº¿t kiá»‡m 38% ðŸ”¥', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Äá»ƒ sau', style: TextStyle(color: _DS.textGrey))),
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
          Text('ðŸ“·', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Text('Dá»‹ch áº£nh AI', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 16)),
        ]),
        actions: [
          if (!_isVip)
            Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _DS.indigoLight, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('ðŸ“·', style: TextStyle(fontSize: 12)),
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
                      const Text('Nháº¥n Ä‘á»ƒ chá»n áº£nh', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textDark)),
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
                    Text('ThÆ° viá»‡n', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.indigo)),
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
                    Text('Chá»¥p áº£nh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.indigo)),
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
                  Text(_isLoading ? 'Äang dá»‹ch...' : 'Dá»‹ch áº£nh', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
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
                  Text('Äang phÃ¢n tÃ­ch áº£nh...', style: TextStyle(fontSize: 13, color: _DS.textGrey)),
                ])),

          if (_extractedText.isNotEmpty)
            Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [Icon(Icons.text_fields_rounded, size: 14, color: _DS.textGrey), SizedBox(width: 6),
                    Text('VÄƒn báº£n nháº­n diá»‡n:', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700))]),
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
                    Text('Báº£n dá»‹ch:', style: TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 10),
                  Text(_result, style: const TextStyle(fontSize: 16, color: _DS.textDark, height: 1.6, fontWeight: FontWeight.w600)),
                  if (_explanation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(width: double.infinity, padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(10)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('ðŸ’¡ Giáº£i thÃ­ch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textGrey)),
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
                          content: const Text('ÄÃ£ sao chÃ©p!'), behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 1),
                        ));
                      },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.copy_rounded, size: 14, color: _DS.textGrey),
                            SizedBox(width: 6),
                            Text('Sao chÃ©p', style: TextStyle(fontSize: 12, color: _DS.textGrey, fontWeight: FontWeight.w700)),
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