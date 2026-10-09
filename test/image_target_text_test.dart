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
}
