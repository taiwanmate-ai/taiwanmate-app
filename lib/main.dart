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

  // Audit "Web tai qua cham, co luc toi 5 phut" (2026-09-14) — network
  // trace THAT tren production xac nhan NotoSansTC-Regular.ttf (6.78MB)
  // bi tai 2 LAN rieng biet, ca 2 deu du dung luong: 1 lan tu FontLoader
  // thu cong o day (fix cu 2026-09-09 cho bug "treo vinh vien o man hinh
  // LOADING"), 1 lan tu co che tu dong cua chinh Flutter Web cho font DA
  // KHAI BAO san trong pubspec.yaml (flutter.fonts) — 2 co che tai DOC
  // LAP, KHONG biet ve nhau, cung fetch 1 file.
  //
  // XOA HAN FontLoader thu cong (khong chi sua timeout) vi day la cach
  // fix TRIET DE HON ca ban cu: co che tu dong cua Flutter Web dung Web
  // Font Loading API cua trinh duyet — von di BAT DONG BO, KHONG BAO GIO
  // chan JS/Dart thread cho toi (day KHONG PHAI await trong code Dart cua
  // ta, ma la 1 co che nen tang cua trinh duyet, hoat dong doc lap voi
  // vong doi widget). Ngay ca khi font that bai/treo vinh vien phia
  // mang, no cung KHONG lam treo runApp() hay bat ky code Dart nao —
  // Flutter chi tiep tuc ve chu bang font he thong (fallback), roi tu ve
  // lai bang NotoSansTC ngay khi font tai xong trong nen (dung hanh vi
  // "flash of unstyled text" tieu chuan cua moi web font, khong phai
  // loi). Ket qua: runApp() gio HOAN TOAN KHONG con phu thuoc mang/font
  // (khong con 1 await nao lien quan font truoc runApp()) — an toan hon
  // ca ban co timeout 5s truoc day, VA loai bo duoc 6.78MB tai trung lap.
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