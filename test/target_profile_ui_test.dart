// Ho so ngon ngu dich (backend app/services/target_profile.py), phia app (2026-10-11): dich sang TIENG ANH thi
// khong hien pinyin o tu dong nghia/vi du, nhan 'Vi du tieng Anh', IPA co nhan rieng; ban dich chinh khong bi xoa khi backend bo field loi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/presentation/screens/translate_screen.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  test('contentLangFor: zh-TW -> zh, en -> en, vi -> theo ngon ngu NGUON', () {
    expect(contentLangFor('zh-TW', 'Nhà vệ sinh ở đâu?'), 'zh');
    expect(contentLangFor('en', 'Nhà vệ sinh ở đâu?'), 'en');
    expect(contentLangFor('en', '廁所在哪裡？'), 'en'); // dich sang en: noi dung LUON la tieng Anh, ke ca nguon la tieng Trung
    expect(contentLangFor('vi', '廁所在哪裡？'), 'zh');
    expect(contentLangFor('vi', 'Where is the toilet?'), 'en');
  });

  test('preferNonEmpty: backend bo field loi (rong) thi GIU ban dich chinh dang hien', () {
    expect(preferNonEmpty('', 'Where is the toilet?'), 'Where is the toilet?');
    expect(preferNonEmpty(null, 'old'), 'old');
    expect(preferNonEmpty('   ', 'old'), 'old');
    expect(preferNonEmpty('new', 'old'), 'new');
  });

  test('pronunciationLabel theo loai', () {
    expect(pronunciationLabel('ipa'), contains('IPA'));
    expect(pronunciationLabel('pinyin'), contains('Pinyin'));
  });

  final synonyms = [
    {'word': 'restroom', 'pinyin': 'xǐshǒujiān', 'meaning': 'phòng vệ sinh'}
  ];
  final examples = [
    {'sentence': 'Where is the restroom?', 'pinyin': 'cèsuǒ zài nǎlǐ', 'meaning': 'Nhà vệ sinh ở đâu?'}
  ];

  testWidgets('contentLang=en: nhan "Vi du tieng Anh", KHONG hien pinyin du backend lo gui, nghia van la tieng Viet', (tester) async {
    await tester.pumpWidget(_wrap(SynonymsAndExamplesView(synonyms: synonyms, examples: examples, contentLang: 'en')));
    expect(find.text('Ví dụ tiếng Anh'), findsOneWidget);
    expect(find.text('Từ đồng nghĩa'), findsOneWidget);
    expect(find.text('restroom'), findsOneWidget);
    expect(find.text('Where is the restroom?'), findsOneWidget);
    expect(find.text('Nhà vệ sinh ở đâu?'), findsOneWidget);
    expect(find.textContaining('xǐshǒujiān'), findsNothing);
    expect(find.textContaining('cèsuǒ'), findsNothing);
    final style = tester.widget<Text>(find.text('Where is the restroom?')).style!;
    expect(style.fontFamily, isNull); // tieng Anh khong dung font chu Han
  });

  testWidgets('contentLang=zh: giu nhu cu — chu Han + pinyin + nhan "Vi du"', (tester) async {
    final zhSyn = [
      {'word': '洗手間', 'pinyin': 'xǐshǒujiān', 'meaning': 'nhà vệ sinh'}
    ];
    final zhEx = [
      {'sentence': '廁所在哪裡？', 'pinyin': 'cèsuǒ zài nǎlǐ', 'meaning': 'Nhà vệ sinh ở đâu?'}
    ];
    await tester.pumpWidget(_wrap(SynonymsAndExamplesView(synonyms: zhSyn, examples: zhEx)));
    expect(find.text('Ví dụ'), findsOneWidget);
    expect(find.text('xǐshǒujiān'), findsOneWidget);
    expect(find.text('cèsuǒ zài nǎlǐ'), findsOneWidget);
    expect(tester.widget<Text>(find.text('廁所在哪裡？')).style!.fontFamily, 'NotoSansTC');
  });

  testWidgets('rong thi khong ve gi; du lieu sai kieu khong crash', (tester) async {
    await tester.pumpWidget(_wrap(const SynonymsAndExamplesView(synonyms: [], examples: [])));
    expect(find.text('Ví dụ'), findsNothing);
    await tester.pumpWidget(_wrap(SynonymsAndExamplesView(synonyms: ['chuoi', 5, null], examples: [123, {'sentence': ''}], contentLang: 'en')));
    expect(tester.takeException(), isNull);
  });
}
