/// ChatEntryGateScreen — 2026-08-20.
///
/// Man hinh THAT SU duoc route "/chat" (tab "AI Chat" o thanh dieu huong)
/// tro toi — quyet dinh hien LearningModeSelectionScreen (lan dau, CHUA
/// tung chon learningMode) hay ChatModeSelectionScreen (da chon roi,
/// bo qua man hinh chon ngon ngu) truoc khi vao Chat/Voice.
///
/// Dung FutureBuilder doc TRUC TIEP loadLearningMode() (KHONG dung
/// ref.watch(learningModeProvider) — xem docstring learning_mode_provider.dart
/// giai thich ly do: state null cua provider co 2 nghia "dang load" vs
/// "da xac nhan chua chon", FutureBuilder tranh nham lan nay).
///
/// StatefulShellRoute.indexedStack GIU STATE tung tab (khong rebuild khi
/// chuyen tab qua lai) — man hinh nay vi vay CHI duoc build 1 LAN cho
/// moi phien app, dung y "chi hoi lan dau".
library;

import 'package:flutter/material.dart';
import 'package:chinesemate/core/providers/learning_mode_provider.dart';
import 'chat_mode_selection_screen.dart';
import 'learning_mode_selection_screen.dart';

class ChatEntryGateScreen extends StatelessWidget {
  const ChatEntryGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: loadLearningMode(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return const LearningModeSelectionScreen(isFirstTime: true);
        }
        return const ChatModeSelectionScreen();
      },
    );
  }
}
