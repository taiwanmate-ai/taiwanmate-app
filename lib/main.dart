import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Preload NotoSansTC — tránh ô vuông khi bấm nhanh
  final fontLoader = FontLoader('NotoSansTC');
  fontLoader.addFont(
    rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
  );
  await fontLoader.load();
  
  runApp(const ProviderScope(child: ChineseMateApp()));
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