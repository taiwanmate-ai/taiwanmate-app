// ═══════════════════════════════════════════════════════════════
// ROLEPLAY CHAT SCREEN — Chat thật với AI trong vai kịch bản
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/utils/web_utils.dart';

class RoleplayChatScreen extends StatefulWidget {
  final String scenarioKey;
  final String scenarioName;

  const RoleplayChatScreen({super.key, required this.scenarioKey, required this.scenarioName});

  @override
  State<RoleplayChatScreen> createState() => _RoleplayChatScreenState();
}

class _RoleplayChatScreenState extends State<RoleplayChatScreen> {
  final _storage = const FlutterSecureStorage();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  String _systemPrompt = '';
  bool _isLoading = true;
  bool _isSending = false;
  int _difficultyLevel = 1;

  static const _purple = Color(0xFF5B5FEF);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _startScenario();
  }

  @override
  void dispose() {
    _finishScenario();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startScenario() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/roleplay/${widget.scenarioKey}/start',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _systemPrompt = response.data['system_prompt'] ?? '';
        _difficultyLevel = (response.data['difficulty_level'] as num?)?.toInt() ?? 1;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _finishScenario() async {
    if (_messages.isEmpty) return;
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/roleplay/${widget.scenarioKey}/finish',
        data: {'messages': _messages},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'assistant', 'content': ''});
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final history = _messages.sublist(0, _messages.length - 1)
          .map((m) => {'role': m['role'], 'content': m['content']}).toList();

      final stream = webChatStream(
        url: 'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/chat-stream',
        token: token ?? '',
        body: {
          'message': text,
          'system_prompt': _systemPrompt,
          'history': history,
          'learning_mode': 'zh_vi',
        },
      );
      await for (final chunk in stream) {
        setState(() {
          _messages[_messages.length - 1]['content'] = (_messages.last['content'] ?? '') + chunk;
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() => _messages[_messages.length - 1]['content'] = '⚠️ Lỗi kết nối. Thử lại nhé!');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.scenarioName, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
          Text('Độ khó $_difficultyLevel/3', style: const TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isUser = m['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser ? _purple : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Text(m['content'] ?? '',
                            style: TextStyle(color: isUser ? Colors.white : _ink, fontSize: 14, height: 1.5, fontFamily: 'NotoSansTC')),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: (_) => _send(),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 46, height: 46,
                      decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }
}