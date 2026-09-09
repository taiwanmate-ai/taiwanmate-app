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

  // Audit "Web production treo mai o man hinh LOADING tinh (index.html),
  // khong bao gio toi runApp()" (2026-09-09) — XAC NHAN THAT qua production
  // that: 1 request font NotoSansTC-Regular.ttf bi ERR_CONNECTION_RESET
  // (mang chap chon/CDN GitHub Pages), va await fontLoader.load() TRUOC DAY
  // KHONG CO timeout/catch nao — 1 lan fetch font bi treo/that bai la
  // BLOCK VINH VIEN ca app, khong bao gio goi duoc runApp(), khong loi hien
  // ra man hinh (nguoi dung chi thay "LOADING" tinh cua index.html mai
  // mai). Loi nay CO SAN TU TRUOC (main.dart khong bi dung boi 5 tinh
  // nang Voice roadmap moi day), chi la de bi lo ra khi mang/CDN that
  // khong on dinh — rollback ve commit cu KHONG sua duoc gi vi code nay
  // giong het o ca ban cu. Fix dung: gioi han thoi gian cho + bo qua loi
  // (fallback ve font mac dinh cua he thong TAM THOI, Flutter se tu tai
  // lai font that ngay sau do trong nen) — runApp() LUON duoc goi, khong
  // bao gio treo vo thoi han vi 1 asset phu (font) tai cham/loi.
  try {
    final fontLoader = FontLoader('NotoSansTC');
    fontLoader.addFont(rootBundle.load('assets/fonts/NotoSansTC-Regular.ttf'));
    await fontLoader.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    // Im lang bo qua — UI se tam dung font he thong cho tieng Trung, sau
    // do Flutter tu dong ve lai khi font that su tai xong (khong chan gi
    // ca). Uu tien "app mo duoc" hon "font dung ngay tu dau".
  }

  _setupProcessTextListener();

  runApp(const ProviderScope(child: ChineseMateApp()));
}

void _setupProcessTextListener() {
  _processTextChannel.setMethodCallHandler((call) async {
    if (call.method == 'onProcessText') {
      final text = call.arguments as String?;
      if (text != null && text.isNotEmpty) await _routeToTranslate(text);
    } else if (call.method == 'onOpenEmergency') {
      appRouter.go('/emergency');
    }
    return null;
  });

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final text = await _processTextChannel.invokeMethod<String>('getProcessText');
      if (text != null && text.isNotEmpty) {
        await _routeToTranslate(text);
        return;
      }
      final emergency = await _processTextChannel.invokeMethod<bool>('getPendingEmergency');
      if (emergency == true) appRouter.go('/emergency');
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
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}