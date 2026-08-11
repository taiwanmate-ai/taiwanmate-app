/// LanguageOrderGuard — tu dong phat hien va sua thu tu Anh/Viet trong
/// response cua AI khi learningMode la en_vi (hoac zh_vi de phong ngua).
/// Khong phu thuoc AI tra dung rule prompt — tu kiem tra bang dac diem
/// chu viet (tieng Viet luon co dau, tieng Anh khong bao gio co dau).
class LanguageOrderGuard {
  const LanguageOrderGuard();

  // Regex tim cap "cau chinh (noi dung trong ngoac)"
  // Khop tu ky tu sau dau cham/!/?/dau nhay truoc do (hoac dau dong)
  // toi het 1 cum trong ngoac tron gan nhat.
  static final RegExp _sentenceParenPattern = RegExp(
    r'([^()]*?)\s*\(([^()]+)\)',
  );

  // Ky tu co dau tieng Viet — khong bao gio xuat hien trong tieng Anh thuan.
  static final RegExp _vietnameseDiacritics = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]',
    caseSensitive: false,
  );

  bool _hasVietnameseDiacritics(String text) =>
      _vietnameseDiacritics.hasMatch(text);

  // So sanh 2 chuoi bo qua khoang trang thua va dau cau cuoi cau (. ! ?)
  // de phat hien truong hop AI lap lai y het cung 1 noi dung tieng Viet
  // o ca cau chinh lan trong ngoac (thieu ban dich tieng Anh).
  static final RegExp _trailingPunctuation = RegExp(r'[.!?]+$');

  String _normalizeForCompare(String text) =>
      text.trim().replaceAll(_trailingPunctuation, '').trim().toLowerCase();

  /// Sua thu tu cho 1 chuoi response, ap dung cho learningMode 'en_vi'.
  /// Xu ly 2 truong hop:
  /// 1. Cau chinh la tieng Viet (co dau) VA noi dung trong ngoac KHONG
  ///    phai tieng Viet (khong dau — tuc la tieng Anh) → hoan doi 2 phan.
  /// 2. Ca cau chinh lan trong ngoac deu la tieng Viet VA noi dung giong
  ///    het nhau (AI quen tao ban dich tieng Anh, lap lai tieng Viet) →
  ///    xoa bot phan ngoac trung lap, chi giu 1 lan (khong the tu tao
  ///    ban dich tieng Anh con thieu bang code thuan).
  String fixEnViOrder(String text) {
    return text.replaceAllMapped(_sentenceParenPattern, (match) {
      final mainPart = match.group(1) ?? '';
      final parenPart = match.group(2) ?? '';

      final mainTrimmed = mainPart.trim();
      if (mainTrimmed.isEmpty) return match.group(0)!;

      final mainIsVietnamese = _hasVietnameseDiacritics(mainTrimmed);
      final parenIsVietnamese = _hasVietnameseDiacritics(parenPart);

      // Truong hop 2: ca hai deu tieng Viet VA noi dung giong het nhau
      // (sau khi chuan hoa) → AI thieu ban dich, xoa phan ngoac trung lap.
      if (mainIsVietnamese &&
          parenIsVietnamese &&
          _normalizeForCompare(mainTrimmed) == _normalizeForCompare(parenPart)) {
        return mainTrimmed;
      }

      // Truong hop 1: cau chinh CO dau Viet, ngoac KHONG co dau Viet
      // (tuc la nguoc thu tu mong muon cho en_vi: main phai la Anh,
      // ngoac phai la Viet).
      if (mainIsVietnamese && !parenIsVietnamese) {
        return '$parenPart ($mainTrimmed)';
      }
      return match.group(0)!;
    });
  }

  /// Diem vao chinh — chi ap dung fix khi dang o che do en_vi.
  /// Cac che do khac (zh_vi, zh_only, en_only) giu nguyen, khong dung guard.
  String apply(String text, String learningMode) {
    if (learningMode != 'en_vi') return text;
    return fixEnViOrder(text);
  }

  /// CHI dung truoc khi gui van ban sang TTS — KHONG dung de hien thi.
  /// Sau khi noi dung trong ngoac da bi xoa (boi _cleanForTTS), phan con
  /// lai le ra khong con dau tieng Viet nao. Neu van con 1 cau co dau
  /// tieng Viet — do la cau "mo coi" (AI viet tieng Viet ra ngoai ngoac),
  /// se bi doc nham giong — xoa hang cau do khoi luong TTS, giu nguyen
  /// hien thi tren man hinh.
  ///
  /// Bug da sua (dieu tra that qua chay code, khong doan): regex tach cau
  /// TRUOC DAY chi nhan dau cau HALF-WIDTH (.!?) va xuong dong — KHONG
  /// nhan dau cau FULL-WIDTH tieng Trung (。！？) ma AI LUON duoc lenh
  /// dung (system prompt bat buoc "ONLY Phồn thể... dau cau Trung"). Hau
  /// qua: 1 doan tra loi nhieu cau tieng Trung dung dau cau full-width bi
  /// hieu nham la MOT cau duy nhat — chi can 1 tu tieng Viet "mo coi" lot
  /// ra ngoai ngoac O BAT KY DAU trong "cau" khong lo do, ca khoi (co the
  /// la TOAN BO tin nhan) bi coi la "cau mo coi" va bi xoa sach, keo theo
  /// moi cau tieng Trung dung truoc no — dung nguyen nhan bug "chi doc
  /// duoc 1 cau/mat het noi dung" da xac nhan qua dieu tra truoc.
  String stripOrphanVietnameseForTts(String textAfterParenRemoved) {
    final sentences =
        textAfterParenRemoved.split(RegExp(r'(?<=[.!?。！？\n])'));
    final kept = sentences.where((s) => !_hasVietnameseDiacritics(s));
    return kept.join('').trim();
  }
}