import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';

void main() {
  runApp(const ProviderScope(child: TaiwanMateApp()));
}

class TaiwanMateApp extends ConsumerWidget {
  const TaiwanMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'TaiwanMate AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(themeState.primaryColor),
      darkTheme: AppTheme.darkTheme(themeState.primaryColor),
      themeMode: themeState.themeMode,
      routerConfig: appRouter,
    );
  }
}
