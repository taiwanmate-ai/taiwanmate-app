// pickImageTargetText() — bug that 2026-10-09/10: the ket qua dich anh KHONG hien ban dich theo ngon ngu dich
// da chon, roi hien NHAN "tieng Trung" tren noi dung van la tieng Viet (AI chep lai van ban goc). Quy tac
// (user duyet 2026-10-10): NHAN PHAI KHOP ngon ngu that cua noi dung; target=en thi `translated` la tieng Anh.
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/presentation/screens/translate_screen.dart';

void main() {
  const viOriginal = 'Nhà vệ sinh ở đâu vậy?';
  final nl = String.fromCharCode(10);

  test('anh tieng Viet + dich sang tieng Trung -> hien ban dich Han (bug that)', () {
    final r = pickImageTargetText(
        targetLang: 'zh-TW', translated: '廁所在哪裡呢？', english: 'Where is the toilet?', original: viOriginal);
    expect(r, isNotNull);
    expect(r!.text, '廁所在哪裡呢？');
    expect(r.label, contains('tiếng Trung'));
  });

  test('anh tieng Viet + dich sang tieng Anh -> hien ban tieng Anh voi nhan tieng Anh', () {
    final r = pickImageTargetText(
        targetLang: 'en', translated: 'Where is the toilet?', english: 'Where is the toilet?', original: viOriginal);
    expect(r!.text, 'Where is the toilet?');
    expect(r.label, contains('tiếng Anh'));
  });

  test('target=en: `translated` la tieng Anh va `english` rong -> dung `translated` lam du phong', () {
    final r = pickImageTargetText(
        targetLang: 'en', translated: 'Where is the toilet?', english: '', original: viOriginal);
    expect(r!.text, 'Where is the toilet?');
  });

  test('target=en nhung noi dung la CHU HAN (AI dich sai ngon ngu) -> null, khong dan nhan tieng Anh len chu Han', () {
    expect(pickImageTargetText(targetLang: 'en', translated: '廁所在哪裡呢？', english: '廁所在哪裡呢？', original: viOriginal), isNull);
  });

  test('target=en nhung noi dung la chu VIET (AI chep lai goc) -> null', () {
    expect(
        pickImageTargetText(
            targetLang: 'en',
            translated: 'Phở bò tái ... 50.000đ',
            english: 'Phở bò tái ... 50.000đ',
            original: 'THỰC ĐƠN${nl}Phở bò tái ... 50.000đ'),
        isNull);
  });

  test("dich sang tieng Viet -> null (da co khoi 'Nghia tieng Viet' rieng)", () {
    expect(pickImageTargetText(targetLang: 'vi', translated: '廁所', english: 'toilet', original: viOriginal), isNull);
  });

  test('ban dich rong hoac TRUNG van ban goc (vd anh Trung dich sang Trung) -> null, khong lap lai', () {
    expect(pickImageTargetText(targetLang: 'zh-TW', translated: '', english: '', original: viOriginal), isNull);
    expect(pickImageTargetText(targetLang: 'zh-TW', translated: ' 廁所 ', english: '', original: '廁所'), isNull);
  });

  test('zh-TW nhung noi dung KHONG co chu Han (AI chep lai chu Viet) -> null, khong dan nhan sai (bug that)', () {
    expect(
        pickImageTargetText(
            targetLang: 'zh-TW',
            translated: 'MENU${nl}Phở bò tái ... 50.000đ',
            english: '',
            original: 'THỰC ĐƠN${nl}Phở bò tái ... 50.000đ'),
        isNull);
  });

  // ───────── 2026-10-10 (lan 2): kiem tra theo TY LE thay cho "co >= 1 chu Han" ─────────
  group('ty le chu (khong con chi can >= 1 chu Han)', () {
    final menuVi = 'THỰC ĐƠN${nl}Phở bò tái ....... 50.000đ${nl}Bún chả Hà Nội .... 45.000đ${nl}Cơm tấm sườn ..... 60.000đ';
    // CA THAT: tieu de dich sang Han, THAN chep nguyen tieng Viet. Lop chan cu (hasMatch Han) CHO QUA -> hien tieng Viet duoi nhan tieng Trung.
    final mixed = '菜單${nl}Phở bò tái ....... 50.000đ${nl}Bún chả Hà Nội .... 45.000đ${nl}Cơm tấm sườn ..... 60.000đ';

    test('TAI HIEN: tieu de Han + than Viet -> null (khong dan nhan tieng Trung len chu Viet)', () {
      expect(pickImageTargetText(targetLang: 'zh-TW', translated: mixed, english: '', original: menuVi), isNull);
    });

    test('ban dich Han day du -> hien; Han co chen Latin/ten rieng Viet <= 10% van hien', () {
      expect(pickImageTargetText(targetLang: 'zh-TW', translated: '菜單${nl}牛肉河粉 ....... 50.000越南盾', english: '', original: menuVi), isNotNull);
      expect(pickImageTargetText(targetLang: 'zh-TW', translated: '請掃描 QR code 用 LINE Pay 付款，謝謝您的光臨與支持', english: '', original: 'Quét mã QR'), isNotNull);
      expect(pickImageTargetText(targetLang: 'zh-TW', translated: '這家店的招牌是 Phở 和炸春捲，非常好吃，歡迎品嚐', english: '', original: 'x'), isNotNull);
    });

    test('Viet khong dau (khong co chu Han nao) -> null', () {
      expect(pickImageTargetText(targetLang: 'zh-TW', translated: 'MENU Pho bo tai 50.000', english: '', original: 'THUC DON'), isNull);
    });

    test('target=en: > 10% chu Han hoac chu Viet -> null; ten rieng Viet it -> van hien', () {
      expect(pickImageTargetText(targetLang: 'en', translated: 'MENU${nl}牛肉河粉 ........ 50.000', english: 'MENU${nl}牛肉河粉 ........ 50.000', original: menuVi), isNull);
      expect(pickImageTargetText(targetLang: 'en', translated: menuVi, english: menuVi, original: 'x'), isNull);
      final ok = pickImageTargetText(targetLang: 'en', translated: 'Beef Phở and spring rolls, a very popular dish in Hanoi', english: '', original: 'x');
      expect(ok, isNotNull);
    });

    test('scriptRatios: dem tren KY TU CHU (chu Han cung tinh), bo so/dau cau', () {
      final r = scriptRatios('菜單 Phở 50.000');
      expect(r.han, closeTo(2 / 5, 1e-9)); // 菜 單 P h ở  => 5 chu
      expect(r.vi, closeTo(1 / 5, 1e-9));
      expect(scriptRatios('').han, 0);
      expect(scriptRatios('12345 ....').vi, 0);
    });

    test('pinyinLooksValid: pinyin co thanh dieu hop le; chu Viet chep lai thi khong', () {
      expect(pinyinLooksValid('Càidān niúròu héfěn lǜ'), isTrue);
      expect(pinyinLooksValid(''), isTrue);
      expect(pinyinLooksValid('THỰC ĐƠN Phở bò tái 50.000đ'), isFalse);
    });
  });
}
