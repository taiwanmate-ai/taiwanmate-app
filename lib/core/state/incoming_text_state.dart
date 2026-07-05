import 'package:flutter/foundation.dart';

/// Bus truyền text từ ngoài app (PROCESS_TEXT intent) vào TranslateScreen.
/// Không dùng go_router `extra` vì /translate nằm trong StatefulShellRoute.indexedStack
/// (widget được giữ state, extra mới không đảm bảo trigger rebuild).
class IncomingTextState {
  static final ValueNotifier<String?> pendingText = ValueNotifier<String?>(null);

  static void push(String text) => pendingText.value = text;
  static void consume() => pendingText.value = null;
}