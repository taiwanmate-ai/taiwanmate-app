import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'core/state/incoming_text_state.dart';
import 'core/storage/secure_storage.dart';

const _processTextChannel = MethodChannel('com.taiwanmate.chinesemate/process_text');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final fontLoader = FontLoader('NotoSansTC');
  fontLoader.addFont(rootBundle.load('assets/fonts/NotoSansTC-Regular.ttf'));
  await fontLoader.load();

  _setupProcessTextListener();

  runApp(const ProviderScope(child: ChineseMateApp()));
}

void _setupProcessTextListener() {
  // App đang chạy nền → Android bắn thẳng qua invokeMethod
  _processTextChannel.setMethodCallHandler((call) async {
    if (call.method == 'onProcessText') {
      final text = call.arguments as String?;
      if (text != null && text.isNotEmpty) await _routeToTranslate(text);
    }
    return null;
  });

  // Cold start (app đang đóng, mở từ menu bôi đen) → chủ động hỏi lại sau frame đầu
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final text = await _processTextChannel.invokeMethod<String>('getProcessText');
      if (text != null && text.isNotEmpty) await _routeToTranslate(text);
    } catch (_) {}
  });
}

Future<void> _routeToTranslate(String text) async {
  // Chỉ điều hướng nếu đã đăng nhập — tránh đá user chưa login thẳng vào /translate,
  // bỏ qua luồng auth-check của SplashScreen
  final hasToken = await SecureStorage.hasToken();
  if (!hasToken) return;
  IncomingTextState.push(text);
  appRouter.go('/translate');
}

class ChineseMateApp extends ConsumerWidget {
  const ChineseMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'ChineseMate AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(themeState.primaryColor),
      darkTheme: AppTheme.darkTheme(themeState.primaryColor),
      themeMode: themeState.themeMode,
      routerConfig: appRouter,
    );
  }
}