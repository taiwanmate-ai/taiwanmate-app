import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/features/learn_v2/application/providers/vocabulary_providers.dart';
import 'package:chinesemate/features/learn_v2/presentation/widgets/learn_new/new_word_card.dart';
import 'package:chinesemate/features/learn/presentation/widgets/vocab_detail_screen.dart';
import 'package:chinesemate/features/learn_v2/presentation/screens/learning_session_screen.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Tab Hoc moi (v2) — 4 tab theo dung LEARNING_TAB_REFACTOR_PLAN.md.
/// CHI "Hoc moi" trien khai day du trong lan nay — 3 tab con lai la khung rong.
class LearningHubScreenV2 extends ConsumerStatefulWidget {
  const LearningHubScreenV2({super.key});

  @override
  ConsumerState<LearningHubScreenV2> createState() => _LearningHubScreenV2State();
}

class _LearningHubScreenV2State extends ConsumerState<LearningHubScreenV2>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _speak(String text, String language) async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts',
        data: {'text': text, 'lang': language == 'en' ? 'en-US' : 'zh-TW', 'slow': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final b64 = base64Encode(response.data as List<int>);
      await webPlayAudio(b64);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Học tập'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Học mới'),
            Tab(text: 'Ôn tập'),
            Tab(text: 'Đã lưu'),
            Tab(text: 'Tiến độ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewWordsTab(),
          _buildComingSoon('Ôn tập'),
          _buildComingSoon('Đã lưu'),
          _buildComingSoon('Tiến độ'),
        ],
      ),
    );
  }

  Widget _buildComingSoon(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text('$label — Sắp ra mắt', style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNewWordsTab() {
    final language = ref.watch(selectedLearnLanguageProvider);
    final newWordsAsync = ref.watch(newWordsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'zh', label: Text('🇹🇼 Tiếng Trung')),
              ButtonSegment(value: 'en', label: Text('🇺🇸 Tiếng Anh')),
            ],
            selected: {language},
            onSelectionChanged: (selection) {
              ref.read(selectedLearnLanguageProvider.notifier).state = selection.first;
            },
          ),
        ),
        Expanded(
          child: newWordsAsync.when(
            data: (words) {
              if (words.isEmpty) {
                return const Center(child: Text('Không có từ mới nào hôm nay 🎉'));
              }
              return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Bắt đầu học (${words.length} từ)'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LearningSessionScreen(words: words, language: language),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.refresh(newWordsProvider.future),
                      child: ListView.builder(
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                    final word = words[index];
                    return NewWordCard(
                      word: word,
                      language: language,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VocabDetailScreen(
                            word: {
                              'vocabulary_id': word.vocabularyId,
                              'chinese': word.chinese,
                              'english': word.english,
                              'pinyin': word.pinyin,
                              'ipa': word.ipa,
                              'vietnamese': word.vietnamese,
                              'example_zh': word.exampleZh,
                              'example_en': word.exampleEn,
                              'tocfl_level': word.tocflLevel,
                              'cefr_level': word.cefrLevel,
                            },
                            lang: language,
                            onSpeak: (text) => _speak(text, language),
                          ),
                        ),
                        ),
                      );
                    },
                      ),
                    ),
                  ),
                ]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text('Không tải được từ mới. Thử lại nhé!'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => ref.invalidate(newWordsProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}