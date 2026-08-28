/// MultilingualTtsSegmenter — tach 1 doan text tra loi cua AI (co the tron
/// Viet + Trung (Phon the) + Anh + Pinyin trong ngoac) thanh danh sach
/// TtsSegment theo DUNG THU TU xuat hien, moi segment gan 1 ngon ngu duy
/// nhat de goi TTS dung giong.
///
/// Dung CHUNG cho ca nut "Nghe" trong AI Chat va (sau nay) Voice Chat —
/// KHONG duoc tao logic tach ngon ngu rieng o 2 noi.
///
/// Nguyen tac phan loai (uu tien tu tren xuong, chi tin hieu Unicode/script
/// CHAC CHAN, khong doan mo ho — xem class doc chi tiet o duoi):
/// 1. Chu Han (CJK) -> zh-TW.
/// 2. Trong ngoac NGAY SAU 1 doan chu Han, chu La-tinh khong dau ->
///    Pinyin (zh-TW/pinyin) — day la cach AI luon dinh dang phien am.
/// 3. Dau thanh dieu Pinyin RIENG (macron/caron/u-umlaut: a ê i ô u,
///    a caron ê caron..., u) khong bao gio xuat hien trong tieng Viet ->
///    Pinyin, bat ke vi tri.
/// 4. Dau tieng Viet RIENG (d gach ngang, cac nguyen am co mu+thanh dieu,
///    dau nga/nang) khong bao gio xuat hien trong Pinyin/Anh -> tieng Viet.
/// 5. Dau sac/huyen don thuan (a a e e i i o o u u) dung chung ca Viet lan
///    Pinyin (tone 2/4) -> uu tien tieng Viet, TRU khi dang o vi tri (2).
/// 6. Chu La-tinh thuan (khong dau) -> KHONG the tu no phan biet Viet
///    (tu khong dau: "khi", "la"...) voi Anh -> "khong chac chan", duoc
///    gan theo tu lang gieng gan nhat DA XAC DINH (uu tien tu truoc, neu
///    dau doan thi xet tu sau); neu ca doan khong co tu nao xac dinh duoc
///    (vd doan thuan tieng Anh) -> mac dinh tieng Anh.
///
/// HAN CHE DA BIET: 1 tu muon (vd "overtime") chen giua 1 cau tieng Viet,
/// KHONG co dau cau/dau ngoac tach rieng va KHONG co dau, se bi gop nham
/// vao tieng Viet xung quanh (vi khong co tu dien de nhan dien no la tu
/// Anh) — day la gioi han cua 1 segmenter dua tren script/Unicode, khong
/// dung tu dien ngon ngu. Neu can chinh xac hon truong hop nay, se can bo
/// sung tu dien tu muon rieng (ngoai pham vi FIX-TTS-02).
library;

class TtsSegment {
  const TtsSegment({
    required this.text,
    required this.lang,
    this.isPinyin = false,
    this.metadata = const {},
  });

  /// Noi dung can doc — da duoc lam sach khoang trang thua 2 dau.
  final String text;

  /// 'vi' | 'zh-TW' | 'en'
  final String lang;

  /// true neu day la phan phien am Pinyin (van dung lang='zh-TW' de chon
  /// giong Trung, nhung danh dau rieng de noi tieu dung/phia goi TTS biet
  /// day la van ban La-tinh chu khong phai Han tu, phong khi can xu ly
  /// khac trong tuong lai).
  final bool isPinyin;

  final Map<String, Object?> metadata;

  @override
  String toString() =>
      'TtsSegment(lang=$lang${isPinyin ? "/pinyin" : ""}, text="$text")';

  @override
  bool operator ==(Object other) =>
      other is TtsSegment &&
      other.text == text &&
      other.lang == lang &&
      other.isPinyin == isPinyin;

  @override
  int get hashCode => Object.hash(text, lang, isPinyin);
}

enum _Lang { han, vi, en, pinyin, unknown }

class _Word {
  _Word(this.text, this.lang, {this.pinyinCandidate = false});
  final String text;
  _Lang lang;
  final bool pinyinCandidate;
}

class MultilingualTtsSegmenter {
  const MultilingualTtsSegmenter();

  static final RegExp _hanRun = RegExp(
    r'[一-鿿㐀-䶿，。！？、：；'
    r'【】…—]+',
  );

  static final RegExp _parenGroup = RegExp(r'\(([^()]*)\)|（([^（）]*)）');

  // Dau ngoac kep/trich dan (thang, cong, hay Trung 「」『』) — CHI dung de
  // BAO QUANH 1 cum tu, KHONG phai noi dung can doc. Neu de lot vao segment
  // (lam "glue" nhu cac dau cau khac), 2 hau qua: (1) dau ngoac nam GIUA
  // cau bi nhet lien vao chu ke ben, TTS doc sai/la; (2) dau ngoac dung
  // NGAY SAU dau cham cau (.!?) bi tach thanh 1 "segment" rieng chi co 1
  // ky tu vo nghia, TTS phat ra am thanh vo nghia. XAC NHAN qua chay that
  // MultilingualTtsSegmenter: loi nay xay ra CA VOI cap Anh+Viet (khong
  // rieng Han+Viet nhu nghi ngo ban dau) moi khi van ban co dau ngoac kep
  // — vi vay XOA HAN cac dau nay khoi noi dung doc, KHONG gan vao bat ky
  // segment nao (khac voi cac dau cau khac van duoc giu lam glue).
  //
  // Dau nhay don (') CUNG duoc xoa o day — nhung CHI khi no toi duoc
  // nhanh xu ly ky tu "khong khop" nay, tuc la KHONG phai apostrophe
  // trong tu contraction ("don't") — apostrophe kieu do da duoc _wordPattern
  // nhan trong tu hoan chinh tu truoc do roi, khong bao gio con roi toi
  // day. Vi vay o day chi con lai dau nhay don dung de trich dan, an
  // toan de xoa.
  static final RegExp _quoteWrapper = RegExp("[\"“”‘’「」『』']");

  // Sua bug TTS doc thanh tieng cac ky tu dinh dang KHONG PHAI noi dung
  // can noi (2026-08-14, phat hien khi dieu tra bug thieu dich song ngu:
  // AI hay tra loi dang liet ke markdown "- giai thich", "**tieu de**",
  // "### 1. muc" — cac ky tu "-"/"*"/"#" nay TRUOC DAY roi vao nhanh
  // "glue" chung (dong ben duoi), bi nhet nguyen van vao segment.text roi
  // gui thang cho TTS doc thanh tieng "gach ngang"/"sao"/"thang"). Gom
  // chung 1 nhom voi _quoteWrapper: XOA HAN, KHONG gan vao segment nao —
  // day la ky tu dinh dang HIEN THI (markdown), khong phai noi dung can
  // doc, giong dau ngoac kep o tren.
  static final RegExp _silentFormattingMarker = RegExp(r'[\-•*#]');

  // Dau tieng Viet CHI CO trong tieng Viet, khong bao gio xuat hien trong
  // Pinyin (Pinyin chi dung macron/caron/u-umlaut cho thanh dieu, khong
  // dung dau moc/mu rieng, dau nga, dau hoi, hay dau nang).
  static const String _viExclusiveLower =
      'ăắằẳẵặ' 'âấầẩẫậ' 'êếềểễệ' 'ôốồổỗộ' 'ơớờởỡợ' 'ưứừửữự' 'ýỳỷỹỵ' 'đ'
      'ãẽĩõũ' 'ảẻỉỏủ' 'ạẹịọụ';
  static const String _viExclusiveUpper =
      'ĂẮẰẲẴẶ' 'ÂẤẦẨẪẬ' 'ÊẾỀỂỄỆ' 'ÔỐỒỔỖỘ' 'ƠỚỜỞỠỢ' 'ƯỨỪỬỮỰ' 'ÝỲỶỸỴ' 'Đ'
      'ÃẼĨÕŨ' 'ẢẺỈỎỦ' 'ẠẸỊỌỤ';

  // Dau sac/huyen tren nguyen am thuong (a e i o u) — dung chung ca tieng
  // Viet lan Pinyin (thanh 2/thanh 4), khong the tu no phan biet chac
  // chan — xem _classifyWord de biet cach xu ly.
  static const String _ambiguousLower = 'áàéèíìóòúù';
  static const String _ambiguousUpper = 'ÁÀÉÈÍÌÓÒÚÙ';

  // Dau thanh dieu Pinyin (macron/caron) + u-umlaut — khong bao gio xuat
  // hien trong tieng Viet.
  static const String _pinyinExclusiveLower = 'āēīōū' 'ǎěǐǒǔ' 'üǖǘǚǜ';
  static const String _pinyinExclusiveUpper = 'ĀĒĪŌŪ' 'ǍĚǏǑǓ' 'ÜǕǗǙǛ';

  // Tu (word) La-tinh: chu cai (thuong/hoa, co dau Viet/Pinyin) + so, cho
  // phep 1 dau nhay don kieu contraction ("don't").
  static final RegExp _wordPattern = RegExp(
    "[A-Za-z0-9$_viExclusiveLower$_viExclusiveUpper"
    "$_ambiguousLower$_ambiguousUpper"
    "$_pinyinExclusiveLower$_pinyinExclusiveUpper]+(?:'[A-Za-z]+)?",
  );

  static final RegExp _viExclusive =
      RegExp('[$_viExclusiveLower$_viExclusiveUpper]');

  static final RegExp _pinyinExclusive =
      RegExp('[$_pinyinExclusiveLower$_pinyinExclusiveUpper]');

  static final RegExp _ambiguousAcuteGrave =
      RegExp('[$_ambiguousLower$_ambiguousUpper]');

  static final RegExp _contraction = RegExp(r"^[A-Za-z]+'[A-Za-z]+$");

  static final RegExp _sentenceBoundary = RegExp(r'(?<=[.!?。！？\n])');

  static final RegExp _endsSentence = RegExp(r'[.!?。！？]$');

  // Bat ky chu cai/Han tu nao (dung \p{L} — Unicode category "Letter",
  // bao phu ca chu La-tinh, chu Viet co dau, LAN chu Han) — dung de phat
  // hien 1 "segment" sau khi tach cau co con NOI DUNG THUC SU de doc hay
  // KHONG (vd chuoi dau cham lien tiếp "..." khong co chu nao).
  static final RegExp _hasLetterContent = RegExp(r'\p{L}', unicode: true);

  List<TtsSegment> segment(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return const [];

    final words = <_Word>[];
    _tokenize(text, words, pinyinCandidate: false);
    // Uu tien 3 (tu dien dac trung) PHAI chay TRUOC uu tien 4 (sticky
    // context o _resolveUnknown) — xem thu tu uu tien day du o docstring
    // ngay truoc _englishDictionary.
    _resolveUnknownByDictionary(words);
    _resolveUnknown(words);
    final merged = _mergeAdjacent(words);
    return _splitAtSentenceBoundaries(merged);
  }

  /// Duyet text theo thu tu: doan chu Han -> 1 word lang=han; doan trong
  /// ngoac -> de quy tokenize noi dung ben trong (co the la Pinyin, Viet,
  /// hay Anh); phan con lai -> tach tung tu La-tinh, giu nguyen khoang
  /// trang/dau cau lam "glue" giua cac tu bang cach nhet vao text cua tu
  /// ngay truoc do.
  void _tokenize(String text, List<_Word> out, {required bool pinyinCandidate}) {
    int i = 0;
    _Lang? lastPushedLang;
    while (i < text.length) {
      final hanMatch = _hanRun.matchAsPrefix(text, i);
      if (hanMatch != null) {
        out.add(_Word(hanMatch.group(0)!, _Lang.han));
        lastPushedLang = _Lang.han;
        i = hanMatch.end;
        continue;
      }

      final parenMatch = _parenGroup.matchAsPrefix(text, i);
      if (parenMatch != null) {
        final inner = (parenMatch.group(1) ?? parenMatch.group(2) ?? '').trim();
        if (inner.isNotEmpty) {
          // Neu CA doan trong ngoac co bat ky dau tieng Viet RIENG nao
          // (vd "nghĩa là") -> chac chan KHONG phai Pinyin (Pinyin khong
          // bao gio co cac dau nay) — ap dung cho CA doan, tranh truong
          // hop 1 tu trong cung cum bi hieu nham la Pinyin chi vi dung
          // dau sac/huyen dung chung voi Pinyin ("là").
          final afterHan = lastPushedLang == _Lang.han && !_viExclusive.hasMatch(inner);
          _tokenize(inner, out, pinyinCandidate: afterHan);
        }
        i = parenMatch.end;
        continue;
      }

      final wordMatch = _wordPattern.matchAsPrefix(text, i);
      if (wordMatch != null) {
        final w = wordMatch.group(0)!;
        final lang = _classifyWord(w, pinyinCandidate: pinyinCandidate);
        out.add(_Word(w, lang, pinyinCandidate: pinyinCandidate));
        lastPushedLang = lang;
        i = wordMatch.end;
        continue;
      }

      final ch = text[i];

      // Dau ngoac kep/trich dan — XOA HAN, KHONG gan vao segment nao (xem
      // giai thich chi tiet o dinh nghia _quoteWrapper). Khac voi cac dau
      // cau khac, day la ky tu BAO QUANH chu khong phai NOI DUNG can doc.
      if (_quoteWrapper.hasMatch(ch)) {
        i += 1;
        continue;
      }

      // Ky tu dinh dang markdown (-/•/*/#) — XOA HAN, KHONG doc thanh
      // tieng (xem giai thich chi tiet o dinh nghia _silentFormattingMarker).
      if (_silentFormattingMarker.hasMatch(ch)) {
        i += 1;
        continue;
      }

      // Ky tu "glue" con lai (khoang trang, dau cau...) — gan vao cuoi tu
      // truoc do de giu dung van ban khi ghep lai; neu chua co tu nao, bo qua.
      if (out.isNotEmpty) {
        out[out.length - 1] = _Word(
          out.last.text + ch,
          out.last.lang,
          pinyinCandidate: out.last.pinyinCandidate,
        );
      }
      i += 1;
    }
  }

  _Lang _classifyWord(String w, {required bool pinyinCandidate}) {
    if (_contraction.hasMatch(w) || w == 'I') return _Lang.en;
    if (_viExclusive.hasMatch(w)) return _Lang.vi;
    if (_pinyinExclusive.hasMatch(w)) return _Lang.pinyin;
    if (_ambiguousAcuteGrave.hasMatch(w)) {
      return pinyinCandidate ? _Lang.pinyin : _Lang.vi;
    }
    if (pinyinCandidate) return _Lang.pinyin;
    return _Lang.unknown;
  }

  // ============================================================
  // GIAI PHAP TRIET DE (2026-08-15) cho cau "mo ho" — tieng Anh KHONG dau
  // dung CHUNG bang chu cai La-tinh voi tieng Viet khong dau, nen 1 CAU
  // TIENG ANH DAI (khong chi 1 tu) van co the bi "sticky context" (hang
  // xom cau lien ke) gan nham ngon ngu neu khong co dau thanh Viet/ky tu
  // Han neo nao trong toan bo cau. Truoc Phase 2 Voice (loi phan loai se
  // nghiem trong hon nhieu trong voice thoi gian thuc), can 1 tin hieu
  // MANH HON, DOC LAP voi ngu canh cau lien ke: tu dien tu khoa tan suat
  // cao dac trung rieng cho tung ngon ngu.
  //
  // THU TU UU TIEN (giam dan do tin cay), khop dung yeu cau da xac nhan:
  //   1. Dau thanh dieu Viet ro rang (_viExclusive/_ambiguousAcuteGrave)
  //      — DA xu ly o _classifyWord(), khong doi.
  //   2. Han tu — DA xu ly o _tokenize() (nhanh _hanRun), khong doi.
  //   3. Tu dien dac trung (MOI, xem _resolveUnknownByDictionary duoi day)
  //      — ap dung THEO TUNG CAU (nhom tu bi chan boi dau ket cau), dem so
  //      tu khop tu dien Anh (a) vs tu dien Viet khong dau (b) trong CHINH
  //      cau do; neu 1 ben ap dao ro rang (>=2 tu khop, ben kia 0 tu) ->
  //      quyet dinh CA CAU theo ben do.
  //   4. Sticky context (_resolveUnknown(), giu NGUYEN khong doi, ke ca fix
  //      "single-word sentence" da lam dung truoc — chi la BUOC CHOT sau
  //      khi tu dien khong du tin hieu, KHONG con la buoc dau tien).
  //   5. Mac dinh tieng Anh (fallback cuoi cung trong _resolveUnknown()).
  //
  // 2 danh sach duoc chon can than de KHONG trung nhau (1 tu khong duoc
  // vua la tieng Anh thong dung VUA la tieng Viet khong dau thong dung —
  // vd co tinh LOAI "do"/"an"/"so"/"the"/"that"/"may" khoi danh sach Viet
  // vi trung voi tu tieng Anh rat pho bien).
  // ============================================================

  static const Set<String> _englishDictionary = {
    // Mao tu / dai tu / gioi tu / lien tu — tan suat cao nhat, gan nhu
    // KHONG BAO GIO la tu tieng Viet khong dau hop le.
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'am', 'be', 'been', 'being',
    'this', 'that', 'these', 'those', 'with', 'from', 'have', 'has', 'had',
    'will', 'would', 'should', 'could', 'can', 'cannot', 'and', 'but',
    'because', 'when', 'where', 'what', 'who', 'whom', 'whose', 'how', 'why',
    'which', 'there', 'here', 'then', 'than', 'if', 'or', 'not', 'no', 'yes',
    'you', 'your', 'yours', 'they', 'them', 'their', 'theirs', 'we', 'our',
    'ours', 'us', 'he', 'she', 'it', 'its', 'his', 'her', 'him', 'my',
    'mine', 'me', 'i', 'do', 'does', 'did', 'done', 'of', 'to', 'in', 'on',
    'at', 'by', 'for', 'up', 'down', 'out', 'about', 'into', 'over', 'under',
    'again', 'further', 'once', 'all', 'each', 'few', 'more', 'most',
    'other', 'some', 'such', 'only', 'own', 'same', 'so', 'too', 'very',
    'just',
    // Dang rut gon (contraction) — luon la tieng Anh, xem them _contraction.
    "don't", "doesn't", "didn't", "isn't", "aren't", "wasn't", "weren't",
    "won't", "wouldn't", "shouldn't", "couldn't", "can't", "let's", "that's",
    "it's", "what's", "who's", "i'm", "you're", "we're", "they're", "i've",
    "you've", "we've", "they've", "i'll", "you'll", "he'll", "she'll",
    "we'll", "they'll", "i'd", "you'd", "he'd", "she'd", "we'd", "they'd",
    // Tu vung noi dung thong dung trong ngu canh day-hoc/tro chuyen (dung
    // trong AI Companion that): word, mean, example, learn, study...
    'word', 'words', 'mean', 'means', 'meaning', 'example', 'examples',
    'sentence', 'sentences', 'use', 'used', 'using', 'learn', 'learning',
    'learned', 'study', 'studying', 'studied', 'practice', 'practicing',
    'correct', 'wrong', 'right', 'good', 'great', 'nice', 'well', 'like',
    'likes', 'liked', 'want', 'wants', 'wanted', 'need', 'needs', 'needed',
    'try', 'trying', 'tried', 'think', 'thinks', 'thought', 'know', 'knows',
    'knew', 'known', 'feel', 'feels', 'felt', 'get', 'gets', 'got',
    'gotten', 'make', 'makes', 'made', 'say', 'says', 'said', 'tell',
    'tells', 'told', 'ask', 'asks', 'asked', 'give', 'gives', 'gave',
    'given', 'take', 'takes', 'took', 'taken', 'come', 'comes', 'came',
    'go', 'goes', 'went', 'gone', 'see', 'sees', 'saw', 'seen', 'look',
    'looks', 'looked', 'find', 'finds', 'found', 'thing', 'things', 'way',
    'ways', 'time', 'times', 'day', 'days', 'people', 'person', 'life',
    'work', 'working', 'worked', 'world', 'hand', 'hands', 'part', 'place',
    'week', 'weeks', 'month', 'months', 'year', 'years', 'point', 'number',
    'group', 'today', 'tomorrow', 'yesterday', 'now', 'before', 'after',
    'always', 'never', 'sometimes', 'usually', 'often', 'still', 'also',
    'even', 'really', 'actually', 'maybe', 'perhaps', 'please', 'thanks',
    'thank', 'sorry', 'welcome', 'hello', 'hi', 'hey', 'bye', 'goodbye',
    'sure', 'course', 'important', 'remember', 'understand', 'explain',
    'question', 'answer', 'help', 'let',
  };

  // Tu chuc nang/dai tu/gioi tu tieng Viet CO THE bi go khong dau — chi gom
  // tu KHONG trung voi tu tieng Anh thong dung. Co tinh KHONG dua vao day
  // cac tu "an" (ăn), "so" (so sanh), "but" (bút), "day" (đây/dạy) khong
  // dau du la tu Viet hop le — vi tat ca deu trung truc tiep voi tu tieng
  // Anh CUC KY pho bien (an/so/but/day) da co san trong _englishDictionary
  // (xac nhan qua script doi chieu 2 danh sach — xem _p21_dict_check.py,
  // da xoa sau khi dung). Giu ca 2 ben se tu mau thuan ngay trong 1 lan
  // vote (tinh sai). Uu tien AN TOAN: bo khoi danh sach Viet, chi giu ben
  // tieng Anh.
  static const Set<String> _vietnameseNoDiacriticDictionary = {
    'la', 'gi', 'cua', 'cho', 'nay', 'hay', 'den', 'di', 've', 'con',
    'nguoi', 'minh', 'ban', 'hoc', 'noi', 'khong', 'toi', 'va',
    'roi', 'chua', 'dang', 'se', 'da', 'rat', 'qua', 'lam', 'sinh', 'viec',
    'anh', 'em', 'chi', 'ong', 'chau', 'nha', 'truong', 'lop', 'thay',
    'giao', 'ghe', 'sach', 'vo', 'tay', 'chan', 'mieng', 'mui',
    'tai', 'toc', 'ao', 'quan', 'giay', 'non', 'mu', 'phut', 'nam',
    'thang', 'tuan', 'sang', 'trua', 'chieu', 'dem', 'kia', 'ay',
    'nao', 'sao', 'nhu', 'vay', 'rang', 'neu', 'boi', 'vi', 'tu', 'tren',
    'duoi', 'giua', 'ngoai', 'trong', 'ngay', 'biet', 'muon', 'thich',
    'ghet', 'yeu', 'buon', 'vui', 'gian', 'lo', 'mung', 'giong', 'khac',
    'moi', 'cu', 'nho', 'dai', 'ngan', 'cao', 'thap', 'nhieu', 'dep',
    'xau', 'tot', 'te', 'nong', 'lanh', 'mua', 'nang', 'choi', 'uong',
    'ngu', 'thuc', 'chay', 'dung', 'ngoi', 'xem', 'nghe', 'doc', 'viet',
  };

  static final RegExp _coreWordPattern = RegExp(r"^[A-Za-z]+(?:'[A-Za-z]+)?");

  /// Tra ve 'en'/'vi' neu tu (sau khi tach phan glue/dau cau dinh kem) co
  /// trong 1 trong 2 tu dien dac trung o tren, null neu khong khop tu nao
  /// (van con "mo ho", se roi xuong sticky context o _resolveUnknown()).
  String? _dictLangFor(String wordText) {
    final m = _coreWordPattern.firstMatch(wordText);
    if (m == null) return null;
    final core = m.group(0)!.toLowerCase();
    if (_englishDictionary.contains(core)) return 'en';
    if (_vietnameseNoDiacriticDictionary.contains(core)) return 'vi';
    return null;
  }

  /// Buoc UU TIEN 3 (xem docstring khoi tren): voi MOI "cau" (nhom tu bi
  /// chan boi dau ket cau .!?。！？), dem so tu _Lang.unknown khop tu dien
  /// Anh vs Viet KHONG DAU trong CHINH cau do. Neu 1 ben ap dao ro rang
  /// (>=2 tu khop, ben kia dung 0 tu) -> gan CA CAU theo ben do. Neu hoa/
  /// khong du tin hieu -> KHONG dong gi ca, de _resolveUnknown() (sticky
  /// context) xu ly phan con lai nhu buoc chot.
  void _resolveUnknownByDictionary(List<_Word> words) {
    bool endsSentence(_Word w) => _endsSentence.hasMatch(w.text.trim());
    int groupStart = 0;
    for (int i = 0; i < words.length; i++) {
      if (endsSentence(words[i]) || i == words.length - 1) {
        _applyDictionaryVoteToGroup(words, groupStart, i);
        groupStart = i + 1;
      }
    }
  }

  void _applyDictionaryVoteToGroup(List<_Word> words, int start, int end) {
    int enCount = 0;
    int viCount = 0;
    for (int k = start; k <= end; k++) {
      if (words[k].lang != _Lang.unknown) continue;
      final d = _dictLangFor(words[k].text);
      if (d == 'en') enCount++;
      if (d == 'vi') viCount++;
    }
    _Lang? decided;
    if (enCount >= 2 && viCount == 0) decided = _Lang.en;
    if (viCount >= 2 && enCount == 0) decided = _Lang.vi;
    if (decided == null) return;
    for (int k = start; k <= end; k++) {
      if (words[k].lang == _Lang.unknown) words[k].lang = decided;
    }
  }

  /// Tu khong the tu xac dinh (La-tinh thuan, khong dau) chi co the la
  /// Viet hoac Anh (ban chat van ban La-tinh) — nen CHI ke thua tu hang
  /// xom cung la Viet/Anh, BO QUA hang xom la Han/Pinyin (khac he chu
  /// viet, khong lien quan toi viec phan biet Viet/Anh). Uu tien hang
  /// xom phia truoc; neu dau doan/dau cau ket thuc cau (. ! ? 。！？) thi
  /// KHONG vuot qua ranh gioi do — moi cau la 1 pham vi rieng, tranh 1
  /// cau tieng Anh/Viet thuan bi "muon" nham ngon ngu cua cau truoc do.
  /// Neu ca cau khong co tu Viet/Anh nao xac dinh duoc (vd toan bo la
  /// tieng Anh thuan) -> mac dinh tieng Anh.
  void _resolveUnknown(List<_Word> words) {
    bool isViOrEn(_Lang l) => l == _Lang.vi || l == _Lang.en;
    bool endsSentence(_Word w) => _endsSentence.hasMatch(w.text.trim());
    for (int i = 0; i < words.length; i++) {
      if (words[i].lang != _Lang.unknown) continue;
      _Lang? found;
      for (int b = i - 1; b >= 0; b--) {
        // Tu ket thuc cau truoc do -> da sang pham vi cau khac, dung lai
        // NGAY, khong duoc dung tu do lam hang xom du no la vi/en.
        if (endsSentence(words[b])) break;
        if (isViOrEn(words[b].lang)) {
          found = words[b].lang;
          break;
        }
      }
      found ??= () {
        // Bug that (2026-08-15): neu CHINH tu dang xet (words[i]) da tu no
        // mang dau ket cau (vd 1 cau/thang tu cam than DUY NHAT 1 tu nhu
        // "Hello!", "Great!", "OK."), thi no DA O RANH GIOI CUOI cau cua
        // chinh no — KHONG duoc tiep tuc nhin xuyen SANG NOI DUNG SAU no
        // (thuong la ban dich tieng Viet trong ngoac ngay sau). Cac dieu
        // kien endsSentence(words[f]) o duoi CHI bat duoc truong hop dau
        // ket cau nam o 1 TU KHAC (vd "Of course!" — dau "!" o tu "course",
        // khong phai tu dau tien "Of") — truong hop 1-tu-1-cau nay lot qua
        // vi vong lap forward chua tung tu kiem tra chinh no truoc khi
        // buoc sang tu ke tiep. XAC NHAN qua chay that MultilingualTtsSegmenter:
        // "Hello! (Xin chào!)" -> "Hello!" bi gan nham lang=vi (doc bang
        // giong Viet) truoc khi co dong nay.
        if (endsSentence(words[i])) return null;
        for (int f = i + 1; f < words.length; f++) {
          if (isViOrEn(words[f].lang)) return words[f].lang;
          if (endsSentence(words[f])) return null; // sang cau sau, dung lai
        }
        return null;
      }();
      words[i].lang = found ?? _Lang.en;
    }
  }

  List<TtsSegment> _mergeAdjacent(List<_Word> words) {
    final result = <TtsSegment>[];
    final buffer = StringBuffer();
    _Lang? currentLang;
    bool currentIsPinyin = false;

    void flush() {
      if (currentLang == null) return;
      final text = buffer.toString().trim();
      buffer.clear();
      if (text.isEmpty) return;
      result.add(TtsSegment(
        text: text,
        lang: currentLang == _Lang.han || currentIsPinyin
            ? 'zh-TW'
            : (currentLang == _Lang.vi ? 'vi' : 'en'),
        isPinyin: currentIsPinyin,
      ));
    }

    for (final w in words) {
      final isPinyin = w.lang == _Lang.pinyin;
      final effectiveLang = w.lang == _Lang.pinyin ? _Lang.han : w.lang;
      if (currentLang != null &&
          (currentLang != effectiveLang || currentIsPinyin != isPinyin)) {
        flush();
      }
      currentLang = effectiveLang;
      currentIsPinyin = isPinyin;
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(w.text.trim());
    }
    flush();
    return result;
  }

  /// XAC NHAN qua chay that: dau cham lien tiep (vd "..." — 3 dau cham
  /// ASCII rieng le, KHAC voi ky tu dau "…" da co san trong _hanRun) tao
  /// ra nhieu diem tach LIEN TIEP KHONG CO chu nao o giua — moi lan tach
  /// nhu vay sinh ra 1 "segment" chi co DUY NHAT 1 dau cham, duoc gui
  /// nguyen sang TTS nhu 1 cau hoan chinh. TTS phat am 1 dau cham don le
  /// ra am thanh gan nhu im lang — nguoi dung nghe giong nhu "mat 1 doan,
  /// bi bo qua" giua 2 cau that. Fix: sau khi tach, neu 1 manh KHONG CO
  /// chu cai/Han tu nao (chi con dau cau con sot), GOP no vao CUOI segment
  /// LIEN TRUOC do thay vi tao segment rieng — khong mat dau cau (van giu
  /// lai trong text) nhung cung khong tao 1 "cau" rong de TTS phat rieng.
  List<TtsSegment> _splitAtSentenceBoundaries(List<TtsSegment> segments) {
    final out = <TtsSegment>[];
    for (final seg in segments) {
      final parts = seg.text.split(_sentenceBoundary);
      for (final p in parts) {
        final trimmed = p.trim();
        if (trimmed.isEmpty) continue;
        if (!_hasLetterContent.hasMatch(trimmed)) {
          // Manh chi con dau cau, khong co chu nao — gop vao segment lien
          // truoc (neu co); neu day la manh DAU TIEN (chua co segment nao
          // truoc do) thi bo qua han, khong tao segment rong-vo-nghia.
          //
          // Fix 2026-08-28 (bao cao that: TTS doc dau cham cuoi cau thanh
          // tieng "dot"): NOI TRUC TIEP, KHONG chen space truoc trimmed —
          // ban truoc chen ' $trimmed' (co space) trong khi manh nay CHINH
          // LA phan dau cau con sot cua CAU TRUOC (vd moi dau "." rieng le
          // cua "..." sau khi tach o tren), khong phai 1 tu moi. Voi "..."
          // (3 dau cham rieng le), moi lan gop CO space bien "tu..." thanh
          // "tu. . ." — 1 dau cham dung TACH RIENG boi khoang trang o CA 2
          // phia chinh la dang TTS (dac biet giong Anh) hay doc thanh
          // tieng "dot" nhat, thay vi hieu la dau "..." lien tuc/tu nhien.
          if (out.isNotEmpty) {
            final prev = out.removeLast();
            out.add(TtsSegment(
              text: '${prev.text}$trimmed',
              lang: prev.lang,
              isPinyin: prev.isPinyin,
              metadata: prev.metadata,
            ));
          }
          continue;
        }
        out.add(TtsSegment(
          text: trimmed,
          lang: seg.lang,
          isPinyin: seg.isPinyin,
          metadata: seg.metadata,
        ));
      }
    }
    return out;
  }
}
