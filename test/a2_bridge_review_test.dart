// A2 Chang 7 bai 1 (CTO 02/11): buoc on co phan "on nhanh A1" soan san: tieu de tu server, bo qua duoc, khong co nut bao loi (cau khong nam trong DB).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lesson_v2_screen_test.dart' show FakeApi, buildSession, choiceQ, pump, tapKey;

Map<String, dynamic> bridgeQ(int i) => {...choiceQ('bridge:-860:$i', 'grammar_pick', ''), 'word_id': null, 'reportable': false};

Map<String, dynamic> sessionWithBridge({bool skippable = true}) {
  final s = buildSession();
  (s['steps'] as List)[1] = {
    'type': 'review',
    'questions': [bridgeQ(1), bridgeQ(2), bridgeQ(3)],
    'header': 'Ôn nhanh trước khi vào bài',
    if (skippable) 'skippable': true,
    'bridge': 3,
  };
  return s;
}

void main() {
  testWidgets('buoc on A1: hien tieu de server, nut Bo qua sang buoc tu moi', (tester) async {
    final api = FakeApi(sessionWithBridge());
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    expect(find.text('Ôn nhanh trước khi vào bài'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    await tapKey(tester, 'flow_skip');
    expect(find.text('Ôn nhanh trước khi vào bài'), findsNothing);
    expect(find.byKey(const Key('word_next')), findsOneWidget);
  });

  testWidgets('cau on A1 khong co nut bao loi; cau thuong van co', (tester) async {
    final api = FakeApi(sessionWithBridge());
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    await tapKey(tester, 'lesson_opt_a');
    expect(find.byKey(const Key('lesson_report_btn')), findsNothing);
  });

  testWidgets('buoc on thuong (khong skippable): tieu de cu, khong co nut Bo qua', (tester) async {
    final s = buildSession();
    (s['steps'] as List)[1] = {'type': 'review', 'questions': [choiceQ('r1', 'meaning_word', 'w1')]};
    final api = FakeApi(s);
    await pump(tester, api);
    await tapKey(tester, 'lesson_start_btn');
    expect(find.text('Ôn lại những từ bạn hay quên'), findsOneWidget);
    expect(find.byKey(const Key('flow_skip')), findsNothing);
    await tapKey(tester, 'lesson_opt_a');
    expect(find.byKey(const Key('lesson_report_btn')), findsOneWidget);
  });
}
