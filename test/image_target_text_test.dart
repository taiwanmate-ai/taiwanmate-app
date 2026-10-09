// pickImageTargetText() — bug that 2026-10-09: the ket qua dich anh KHONG BAO GIO hien ban dich theo
// ngon ngu dich da chon. Anh tieng Viet + dich sang tieng Trung phai hien chu Han.
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/presentation/screens/translate_screen.dart';

void main() {
  const viOriginal = 'Nhà vệ sinh ở đâu vậy?';

  test('anh tieng Viet + dich sang tieng Trung -> hien ban dich Han (bug that)', () {
    final r = pickImageTargetText(
        targetLang: 'zh-TW', zhTraditional: '廁所在哪裡呢？', english: 'Where is the toilet?', original: viOriginal);
    expect(r, isNotNull);
    expect(r!.text, '廁所在哪裡呢？');
    expect(r.label, contains('tiếng Trung'));
  });

  test('dich sang tieng Anh -> hien ban dich tieng Anh', () {
    final r = pickImageTargetText(
        targetLang: 'en', zhTraditional: '廁所在哪裡呢？', english: 'Where is the toilet?', original: viOriginal);
    expect(r!.text, 'Where is the toilet?');
  });

  test("dich sang tieng Viet -> null (da co khoi 'Nghia tieng Viet' rieng)", () {
    expect(
        pickImageTargetText(targetLang: 'vi', zhTraditional: '廁所', english: 'toilet', original: viOriginal), isNull);
  });

  test('ban dich rong hoac TRUNG van ban goc (vd anh Trung dich sang Trung) -> null, khong lap lai', () {
    expect(pickImageTargetText(targetLang: 'zh-TW', zhTraditional: '', english: '', original: viOriginal), isNull);
    expect(pickImageTargetText(targetLang: 'zh-TW', zhTraditional: ' 廁所 ', english: '', original: '廁所'), isNull);
  });
}
