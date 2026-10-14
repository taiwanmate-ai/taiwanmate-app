/// Tam an Voice (2026-10-14): app doc voice_feature_enabled tu server; false/loi -> AN the "Tro chuyen truc tiep", khoi VIP Voice (nut mua), dong mo ta Voice.
/// true -> hien nhu cu. Cac phan khac (Chat, VIP thuong) khong doi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/core/providers/voice_feature_provider.dart';
import 'package:chinesemate/features/chat/presentation/screens/chat_mode_selection_screen.dart';
import 'package:chinesemate/features/chat/presentation/screens/learning_mode_selection_screen.dart';
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart' show VipScreen;

Widget _app(Widget child, Future<bool> Function() fetcher) => ProviderScope(
      key: UniqueKey(),
      overrides: [voiceFeatureFetcherProvider.overrideWithValue(fetcher)],
      child: MaterialApp(home: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatModeSelectionScreen', () {
    testWidgets('server cho phep -> hien CA 2 the Chat va Tro chuyen truc tiep', (tester) async {
      await tester.pumpWidget(_app(ChatModeSelectionScreen(chatBuilder: (_) => const Text('CHAT_SCREEN')), () async => true));
      await tester.pumpAndSettle();
      expect(find.text('Trò chuyện trực tiếp'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('CHAT_SCREEN'), findsNothing);
    });

    testWidgets('server khong cho phep -> KHONG co the Voice, vao thang Chat', (tester) async {
      await tester.pumpWidget(_app(ChatModeSelectionScreen(chatBuilder: (_) => const Text('CHAT_SCREEN')), () async => false));
      await tester.pumpAndSettle();
      expect(find.text('Trò chuyện trực tiếp'), findsNothing);
      expect(find.text('CHAT_SCREEN'), findsOneWidget);
    });

    testWidgets('dang tai co -> vong cho, khong chop the Voice', (tester) async {
      await tester.pumpWidget(_app(ChatModeSelectionScreen(chatBuilder: (_) => const Text('CHAT_SCREEN')), () async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return false;
      }));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Trò chuyện trực tiếp'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('CHAT_SCREEN'), findsOneWidget);
    });

    testWidgets('loi mang khi lay co -> coi nhu AN (an toan)', (tester) async {
      await tester.pumpWidget(_app(ChatModeSelectionScreen(chatBuilder: (_) => const Text('CHAT_SCREEN')), () async => throw Exception('mang')));
      await tester.pumpAndSettle();
      expect(find.text('Trò chuyện trực tiếp'), findsNothing);
      expect(find.text('CHAT_SCREEN'), findsOneWidget);
    });
  });

  group('LearningModeSelectionScreen — dong mo ta', () {
    testWidgets('an Voice -> chi nhac Chat; hien Voice -> nhac ca Chat va Tro chuyen truc tiep', (tester) async {
      await tester.pumpWidget(_app(const LearningModeSelectionScreen(isFirstTime: false), () async => false));
      await tester.pumpAndSettle();
      expect(find.text('Áp dụng cho Chat — có thể đổi lại bất cứ lúc nào.'), findsOneWidget);
      expect(find.textContaining('Trò chuyện trực tiếp'), findsNothing);

      await tester.pumpWidget(_app(const LearningModeSelectionScreen(isFirstTime: false), () async => true));
      await tester.pumpAndSettle();
      expect(find.text('Áp dụng cho cả Chat và Trò chuyện trực tiếp — có thể đổi lại bất cứ lúc nào.'), findsOneWidget);
    });
  });

  group('VipScreen — khoi VIP Voice', () {
    Future<void> pumpVip(WidgetTester tester, Map<String, dynamic>? user) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: VipScreen(userLoader: () async => user)));
      await tester.pumpAndSettle();
    }

    testWidgets('server cho phep -> hien khoi VIP Voice', (tester) async {
      await pumpVip(tester, {'voice_feature_enabled': true, 'voice_access': false});
      expect(find.text('VIP Voice — Luyện nói trực tiếp cùng AI'), findsOneWidget);
    });

    testWidgets('server khong cho phep / chua tai / thieu truong / loi -> AN khoi Voice, VIP thuong van con', (tester) async {
      for (final user in <Map<String, dynamic>?>[
        {'voice_feature_enabled': false, 'voice_access': true},
        {'voice_access': false},
        null,
      ]) {
        await pumpVip(tester, user);
        expect(find.text('VIP Voice — Luyện nói trực tiếp cùng AI'), findsNothing, reason: '$user');
        expect(find.textContaining('Voice'), findsNothing, reason: 'khong con chu Voice nao tren man hinh Premium');
        expect(find.text('Hoàn tiền\n7 ngày'), findsOneWidget, reason: 'VIP thuong khong doi');
      }
    });
  });
}
