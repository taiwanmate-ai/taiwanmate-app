import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/services/payment_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:chinesemate/core/utils/web_utils.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chinesemate/core/providers/hanzi_mode_provider.dart';
import 'roleplay_screen.dart';
import 'chat_history_screen.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';
import 'package:chinesemate/features/chat/engines/language_order_guard.dart';
import 'package:chinesemate/features/chat/engines/companion_memory_service.dart';
import 'package:chinesemate/features/chat/engines/companion_learning_engine.dart';
import 'package:chinesemate/features/chat/engines/companion_learning_service.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';

class _DS {
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const indigoDeep = Color(0xFF1A1A4E);
  static const indigoLight = Color(0xFFEEEDFE);
  static const bg = Color(0xFFF0F4FF);
  static const chatBg = Color(0xFFF5F7FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const yellow = Color(0xFFFFD166);
  static const yellowLight = Color(0xFFFFF8E1);
  static const blue = Color(0xFF2979FF);
  static const red = Color(0xFFFF3D57);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _storage = const FlutterSecureStorage();
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _hanziCache = {};
  bool _isLoading = false;
  int _freeMessagesLeft = 0;
  bool _isVip = false;
  String _aiGender = 'female';
  bool _autoSpeak = true;
  String _liveTranscript = '';
  late final CompanionVoiceController _voiceController;
  String _userType = 'student';
  String _learningMode = 'zh_vi';
  int _sessionMessages = 0;
  bool _showXpPop = false;
  String _xpPopText = '';
  late AnimationController _xpPopCtrl;
  late Animation<double> _xpPopAnim;
  String _aiMood = '😊';
  int _typingDotSpeed = 600;
  final List<String> _mistakes = [];
  String _streamingText = '';
  bool _isStreaming = false;
  final List<String> _newVocabSuggestions = [];
  bool _userFrustrated = false;
  Map<String, dynamic> _aiMemory = {};
  bool _memoryLoaded = false;
  String? _currentSessionId;
 Map<String, dynamic>? _nextAction;
  final List<String> _recentSuggestedTrendPhraseIds = [];

  void _recordSuggestedTrendPhrase(String? id) {
    if (id == null) return;
    _recentSuggestedTrendPhraseIds.add(id);
    while (_recentSuggestedTrendPhraseIds.length > 3) {
      _recentSuggestedTrendPhraseIds.removeAt(0);
    }
  }

  // Quick reply suggestions
  List<String> _quickReplies = [];

  // Buoc 1 refactor: doi chieu song song CompanionPersonalityEngine voi ham cu
  static const _personalityEngine = CompanionPersonalityEngine();
  static const _languageOrderGuard = LanguageOrderGuard();
  static const _memoryService = CompanionMemoryService();
  static const _learningEngine = CompanionLearningEngine();
  static const _learningService = CompanionLearningService();

  String get _aiName => _aiGender == 'female' ? 'Yuki' : 'Kai';
  List<Color> get _aiGradient => _aiGender == 'female'
      ? [const Color(0xFF5B5FEF), const Color(0xFF7C3AED)]
      : [const Color(0xFF2979FF), const Color(0xFF1565C0)];

  String get _aiMoodEmoji {
    switch (_aiMood) {
      case '😂': return '😂';
      case '🤩': return '🤩';
      case '😤': return '😤';
      case '😲': return '😲';
      case '💪': return '💪';
      case '🥺': return '🥺';
      default: return '😊';
    }
  }

  Color get _aiMoodColor {
    switch (_aiMood) {
      case '😤': return _DS.red;
      case '🤩': return _DS.yellow;
      case '😂': return _DS.green;
      case '💪': return _DS.blue;
      default: return _DS.indigo;
    }
  }

  List<String> get _defaultQuickReplies {
    switch (_learningMode) {
      case 'zh_vi': return ['Dạy tôi từ mới 📚', 'Sửa lỗi cho tôi ✍️', 'Kể chuyện Đài Loan 🇹🇼'];
      case 'en_vi': return ['Teach me new words 📚', 'Correct my English ✍️', 'Tell me about Taiwan 🇹🇼'];
      default: return ['學新詞彙 📚', '幫我糾錯 ✍️', '聊台灣文化 🇹🇼'];
    }
  }

String _relationshipLabel(Map<String, dynamic>? memory) {
    final relationship = memory?['relationship']?.toString().trim().toLowerCase();
    switch (relationship) {
      case 'acquaintance':
        return 'Bạn mới quen';
      case 'friend':
        return 'Bạn đồng hành';
      case 'bestfriend':
        return 'Bạn thân thiết';
      case 'stranger':
      default:
        return 'Đang làm quen';
    }
  }

  String _getLearningModeLabel() {
    switch (_learningMode) {
      case 'zh_only': return '中文 only';
      case 'en_vi': return 'English + Việt';
      case 'en_only': return 'English only';
      default: return '中文 + Việt';
    }
  }

  String _buildSystemPrompt(String currentUserText) {
    final result = _personalityEngine.buildSystemPromptV2(
      learningMode: _learningMode,
      userType: _userType,
      sessionMessages: _sessionMessages,
      mistakes: List<String>.unmodifiable(_mistakes),
      userFrustrated: _userFrustrated,
      aiMemory: Map<String, dynamic>.unmodifiable(_aiMemory),
      nextAction: _nextAction != null ? Map<String, dynamic>.unmodifiable(_nextAction!) : null,
      aiName: _aiName,
      aiGender: _aiGender,
      isVip: _isVip,
      now: DateTime.now(),
      currentUserText: currentUserText,
      recentlySuggestedTrendPhraseIds: _recentSuggestedTrendPhraseIds.toSet(),
    );
    _recordSuggestedTrendPhrase(result.usedTrendPhraseId);
    return result.prompt;
  }

  @override
  void initState() {
    super.initState();
    _xpPopCtrl = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
    _xpPopAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _xpPopCtrl, curve: Curves.elasticOut),
    );
    _quickReplies = _defaultQuickReplies;
    _voiceController = CompanionVoiceController(
      tokenProvider: () => _storage.read(key: 'access_token'),
    );
    _voiceController.addListener(_onVoiceChanged);
    _loadMemory();
    _loadNextAction();
    _initChat();
    _loadQuota();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadNextAction() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final action = await _learningService.loadNextAction(token);
      if (mounted && action != null) {
        setState(() => _nextAction = action);
      }
    } catch (e) {}
  }

  Future<void> _initChat() async {
    await _loadChatHistory();
    if (mounted && _messages.isEmpty) {
      _sendWelcomeMessage();
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/sessions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final sessions = List<Map<String, dynamic>>.from(res.data['sessions'] ?? []);
      if (sessions.isEmpty) return;
      final latest = sessions.first;
      final lastMsgTime = DateTime.parse(latest['last_message_at']);
      // Qua 6 tieng khong nhan tin -> coi la cuoc tro chuyen moi, khong tu load lai
      if (DateTime.now().toUtc().difference(lastMsgTime.toUtc()).inHours > 6) return;

      final msgRes = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/session/${latest['id']}/messages',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final messages = List<Map<String, dynamic>>.from(msgRes.data['messages'] ?? []);
      if (messages.isNotEmpty && mounted) {
        setState(() {
          _currentSessionId = latest['id'] as String;
          _messages.addAll(messages.map((m) => {'role': m['role'], 'content': m['content']}));
        });
        _scrollToBottom();
      }
    } catch (e) {}
  }
  Future<void> _loadSpecificSession(String sessionId) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/session/$sessionId/messages',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final messages = List<Map<String, dynamic>>.from(res.data['messages'] ?? []);
      if (mounted) {
        setState(() {
          _currentSessionId = sessionId;
          _messages.clear();
          _messages.addAll(messages.map((m) => {'role': m['role'], 'content': m['content']}));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được cuộc trò chuyện này')),
      );
    }
  }

  Future<void> _openHistory() async {
    final selectedId = await Navigator.push<String>(
      context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
    );
    if (selectedId != null) _loadSpecificSession(selectedId);
  }

  void _startNewConversation() {
    setState(() {
      _messages.clear();
      _mistakes.clear();
      _newVocabSuggestions.clear();
      _quickReplies = _defaultQuickReplies;
      _currentSessionId = null;
    });
    _sendWelcomeMessage();
  }

  Future<void> _saveMessageToHistory(String role, String content) async {
    if (content.trim().isEmpty) return;
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/message',
        data: {'role': role, 'content': content, 'session_id': _currentSessionId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _currentSessionId = res.data['session_id'] as String?;
    } catch (e) {}
  }

  @override
  void dispose() {
    _saveMemory();
    _controller.dispose();
    _scrollController.dispose();
    _xpPopCtrl.dispose();
    _voiceController.removeListener(_onVoiceChanged);
    _voiceController.dispose();
    super.dispose();
  }
  Future<void> _loadMemory() async {
    try {
      if (!mounted) return;
      final token = await _storage.read(key: 'access_token');
      final memory = await _memoryService.loadMemory(token);
      if (memory != null) {
        setState(() {
          _aiMemory = memory;
          _memoryLoaded = true;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadQuota() async {
    try {
      if (!mounted) return;
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/quota',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      final isVip = response.data['is_vip'] == true;
      final chatRemaining = response.data['chat_remaining'] as int? ?? 10;
      setState(() {
        _isVip = isVip;
        if (!isVip) _freeMessagesLeft = chatRemaining;
      });
    } catch (e) {}
  }

  Future<void> _saveMemory() async {
    if (_messages.length < 2) return;
    try {
      if (!mounted) return;
      final token = await _storage.read(key: 'access_token');
      await _memoryService.saveMemory(
        token: token,
        messages: _messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
        existingMemory: _aiMemory,
      );
    } catch (e) {}
  }

  

  void _showMicOverlay() {
    _voiceController.startListening(
      onTranscript: (transcript) async {
        if (transcript.isNotEmpty) {
          setState(() => _liveTranscript = transcript);
          await _send(voiceText: transcript);
        } else {
          setState(() => _liveTranscript = '');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không nhận được giọng nói. Thử lại nhé!')),
          );
        }
      },
      onError: (error) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi microphone: $error')),
        );
      },
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setOverlay) {
          Timer.periodic(const Duration(milliseconds: 200), (timer) {
            if (!mounted || !_voiceController.isListening) {
              timer.cancel();
              if (Navigator.canPop(ctx)) Navigator.pop(ctx);
              return;
            }
            setOverlay(() {});
          });
          return WillPopScope(
            onWillPop: () async => false,
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Đang lắng nghe...', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('Nói bằng tiếng Việt', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: 220, height: 220,
                    child: Stack(alignment: Alignment.center, children: [
                      _ChatPulseRing(size: 200, color: _DS.indigo, opacity: 0.08, delay: 0),
                      _ChatPulseRing(size: 170, color: _DS.indigo, opacity: 0.12, delay: 300),
                      _ChatPulseRing(size: 140, color: _DS.indigo, opacity: 0.18, delay: 600),
                      GestureDetector(
                        onTap: () {
                          _voiceController.stopListening();
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)],
                          ),
                          child: const Icon(Icons.stop_rounded, size: 48, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    child: Text(
                      _liveTranscript.isNotEmpty ? _liveTranscript : 'Bắt đầu nói...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _liveTranscript.isNotEmpty ? 18 : 15,
                        color: _liveTranscript.isNotEmpty ? Colors.white : Colors.white.withOpacity(0.4),
                        fontWeight: _liveTranscript.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('Nhấn ■ để dừng và gửi', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendWelcomeMessage() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || _messages.isNotEmpty) return;
    final hour = DateTime.now().hour;
    final greetings = {
      'kid': ['Chào bạn nhỏ! Hôm nay mình học gì nào? 🌟', 'Bạn ơi! Mình đang chờ bạn đây! 😊'],
      'student': hour < 10 ? [
        'Ê mày! Sáng sớm học tiếng Trung thì pro lắm đó 💪 Bắt đầu thôi!',
        'Dậy rồi à? Tao cũng vừa uống cà phê xong, học thôi mày!',
      ] : hour < 14 ? [
        'Ê! Ăn trưa chưa? Học xong rồi đi ăn nha 😤',
        'Giờ này mà học tiếng Trung thì tao respect mày lắm đó!',
      ] : hour < 22 ? [
        'Mày cuối cùng cũng vào rồi! Tao chờ cả ngày 😤',
        'Tối rồi mà vẫn học, tao thích cái tinh thần này 🔥',
      ] : [
        'Khuya rồi mà còn học? Mày ổn không vậy 😂',
        'Khuya thế này tao cũng đang online, học ít thôi rồi ngủ nha!',
      ],
      'adult': ['Xin chào! Hôm nay có cần học từ vựng công sở không?', 'Chào bạn! Mình sẵn sàng giúp bạn học tiếng Trung rồi!'],
      'elder': ['Chào anh/chị! Hôm nay mình cùng ôn lại bài cũ nhé?', 'Anh/chị khỏe không? Mình đang chờ để học cùng đây!'],
    };
    final list = greetings[_userType] ?? greetings['student']!;
    final msg = list[DateTime.now().second % list.length];
    setState(() => _messages.add({'role': 'assistant', 'content': msg}));
  }



  void _detectEmotion(String text) {
    final lower = text.toLowerCase();
    final frustratedWords = ['chán', 'khó quá', 'bỏ cuộc', 'mệt', 'không hiểu', 'thôi', 'chịu rồi', 'give up', 'too hard', 'tired'];
    _userFrustrated = frustratedWords.any((w) => lower.contains(w));
  }

  void _updateMood(String reply) {
    final lower = reply.toLowerCase();
    String mood = '😊';
    if (lower.contains('haha') || lower.contains('hehe') || lower.contains('lmao') || lower.contains('💀')) mood = '😂';
    else if (lower.contains('slay') || lower.contains('tuyệt') || lower.contains('giỏi') || lower.contains('厲害')) mood = '🤩';
    else if (lower.contains('sai') || lower.contains('wrong') || lower.contains('錯') || lower.contains('delulu')) mood = '😤';
    else if (lower.contains('ủa') || lower.contains('seriously') || lower.contains('什麼')) mood = '😲';
    else if (lower.contains('cố lên') || lower.contains('you got this') || lower.contains('加油')) mood = '💪';
    else if (lower.contains('buồn') || lower.contains('nhớ nhà') || lower.contains('mệt')) mood = '🥺';
    if (mounted) setState(() => _aiMood = mood);
  }

  void _extractNewVocab(String reply) {
    final newVocab = _learningEngine.extractNewVocab(reply);
    if (newVocab.isNotEmpty) {
      setState(() {
        _newVocabSuggestions.clear();
        _newVocabSuggestions.addAll(newVocab);
      });
    }
  }

  void _trackMistake(String userText) {
    if (_learningEngine.shouldTrackMistake(_mistakes, userText)) {
      _mistakes.add(userText);
    }
  }

  void _showXpReward(int xp) {
    setState(() { _xpPopText = '+$xp XP 🔥'; _showXpPop = true; });
    _xpPopCtrl.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showXpPop = false);
      });
    });
  }

  List<Map<String, dynamic>> get _cleanHistory {
    return _messages
        .where((m) => m['content'] != null && !(m['content'] as String).startsWith('⚠️') && (m['content'] as String).isNotEmpty)
        .take(8)
        .map((m) => {'role': m['role'], 'content': m['content']})
        .toList();
  }

  Future<void> _saveVocab(String word) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary',
        data: {'chinese': word, 'pinyin': '', 'vietnamese': '', 'source': 'chat'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() => _newVocabSuggestions.remove(word));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Đã lưu "$word" vào từ vựng!'),
          backgroundColor: _DS.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {}
  }

  Future<void> _send({String? voiceText}) async {
    final text = voiceText ?? _controller.text.trim();
    if (text.isEmpty || _isLoading) return;
    if (!_isVip && _freeMessagesLeft <= 0) { _showUpgradeDialog(); return; }
    _voiceController.stopSpeaking();
    _controller.clear();
    _sessionMessages++;
    _detectEmotion(text);
    _trackMistake(text);
    if (_sessionMessages % 10 == 0) {
      _saveMemory(); // fire-and-forget: kiem tra loi + tom tat dinh ky, khong doi ket qua
    }
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _streamingText = '';
      _newVocabSuggestions.clear();
      _quickReplies = [];
      _typingDotSpeed = 400 + math.Random().nextInt(400);
    });
    _scrollToBottom();
    _saveMessageToHistory('user', text);
    final xpReward =
        _learningEngine.getXpRewardForSessionCount(_sessionMessages);
    if (xpReward != null) {
      _showXpReward(xpReward);
    }
    try {
      final token2 = await _storage.read(key: 'access_token');

      final int botIndex = _messages.length;
      setState(() {
        _messages.add({'role': 'assistant', 'content': ''});
        _isLoading = false;
        _isStreaming = true;
      });

      String rawReply = '';
      final stream = webChatStream(
        url: 'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/chat-stream',
        token: token2 ?? '',
        body: {
          'message': text,
          'system_prompt': _buildSystemPrompt(text),
          'history': _cleanHistory,
          'learning_mode': _learningMode,
          // Gui kem userType that de backend co the tu chan doc lap noi
          // dung nhay cam (mang vui/roast) cho tre em — lop phong thu THU
          // 2, doc lap voi gate da lam o CompanionPersonalityEngine phia
          // client (xem translate.py::chat_stream_endpoint). Client van
          // giu nguyen gate cu, KHONG doi gi o day ngoai truong gui kem.
          'user_type': _userType,
        },
      );

      try {
        await for (final chunk in stream) {
          rawReply += chunk;
          final display = rawReply.replaceAllMapped(
              RegExp(r'\[NEW:([^\]]+)\]'), (m) => m.group(1)!);
          if (mounted) {
            setState(() => _messages[botIndex]['content'] = display);
            _scrollToBottom();
          }
        }
      } catch (streamErr) {
        if (streamErr.toString().contains('QUOTA_EXCEEDED')) {
          if (mounted) {
            setState(() {
              if (botIndex < _messages.length) _messages.removeAt(botIndex);
              _freeMessagesLeft = 0;
            });
            _showUpgradeDialog();
          }
          return;
        }
        rethrow;
      }

      final fixedReply = rawReply.replaceAllMapped(
        RegExp(r'\(([^)]+)\)'),
        (m) {
          var inner = m.group(1)!;
          inner = inner.replaceAll(RegExp(r'(?<=[^\s])(?=[A-ZÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ])'), ' ');
          return '($inner)';
        },
      );
      var displayReply = fixedReply.replaceAllMapped(RegExp(r'\[NEW:([^\]]+)\]'), (m) => m.group(1)!);
      _updateMood(displayReply);
      _extractNewVocab(rawReply);
        displayReply = _languageOrderGuard.apply(displayReply, _learningMode);
        await _cacheHanziConversion(displayReply);
        if (mounted) {
          setState(() {
            _messages[botIndex]['content'] = displayReply;
            _quickReplies = _generateQuickReplies(displayReply);
          });
        }
        _saveMessageToHistory('assistant', displayReply);
        if (_autoSpeak) _voiceController.speak(displayReply, aiGender: _aiGender, learningMode: _learningMode);
      _loadQuota();
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          if (mounted) { setState(() => _freeMessagesLeft = 0); _showUpgradeDialog(); }
          return;
        }
      }
      // ignore: avoid_print
      print('❌ CHAT DioException: type=${e.type}, message=${e.message}, response=${e.response?.data}');
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi: ${e.type} - ${e.message}'}));
    } catch (e, stack) {
      // ignore: avoid_print
      print('❌ CHAT ERROR: $e\n$stack');
      setState(() => _messages.add({'role': 'assistant', 'content': '⚠️ Lỗi: ${e.runtimeType} - $e'}));
    } finally {
      setState(() { _isLoading = false; _streamingText = ''; });
      _scrollToBottom();
    }
  }
  Future<void> _cacheHanziConversion(String text) async {
    final mode = ref.read(hanziModeProvider);
    if (mode == HanziMode.traditional) return;
    if (_hanziCache.containsKey(text)) return;
    final converted = await convertHanzi(text, mode);
    _hanziCache[text] = converted;
    if (mounted) setState(() {});
  }

  List<String> _generateQuickReplies(String aiReply) {
    final lower = aiReply.toLowerCase();
    if (lower.contains('?') || lower.contains('？')) {
      return ['Tôi hiểu rồi 👍', 'Cho tôi ví dụ khác', 'Giải thích thêm'];
    } else if (lower.contains('new:') || lower.contains('từ mới')) {
      return ['Lưu từ này 💾', 'Dùng từ này trong câu', 'Dạy thêm từ khác'];
    }
    return _defaultQuickReplies;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('⭐', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            const Text('Nâng cấp Pro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text('Hết tin nhắn miễn phí rồi!\nNâng cấp để chat không giới hạn!',
                textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey, height: 1.5)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(dialogCtx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VipScreen()));
              },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Text('⭐ Xem các gói VIP', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Để sau', style: TextStyle(color: _DS.textGrey))),
          ]),
        ),
      ),
    );
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(color: _DS.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              )),
              const Text('Cài đặt trợ lý AI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
              const SizedBox(height: 24),
              _settingLabel('Người bạn học'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _AiCard(
                  name: 'Yuki', sub: 'Giọng nữ · Năng động', emoji: '👩',
                  isSelected: _aiGender == 'female',
                  gradient: [_DS.indigo, _DS.indigoDark],
                  onTap: () { setModal(() {}); setState(() => _aiGender = 'female'); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _AiCard(
                  name: 'Kai', sub: 'Giọng nam · Điềm tĩnh', emoji: '👨',
                  isSelected: _aiGender == 'male',
                  gradient: [const Color(0xFF2979FF), const Color(0xFF1565C0)],
                  onTap: () { setModal(() {}); setState(() => _aiGender = 'male'); },
                )),
              ]),
              const SizedBox(height: 24),
              _settingLabel('Chế độ học'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.8,
                children: [
                  {'key': 'zh_vi', 'icon': '🇹🇼', 'label': 'Trung + Việt'},
                  {'key': 'zh_only', 'icon': '中', 'label': 'Chỉ tiếng Trung'},
                  {'key': 'en_vi', 'icon': '🇺🇸', 'label': 'Anh + Việt'},
                  {'key': 'en_only', 'icon': '🔤', 'label': 'Chỉ tiếng Anh'},
                ].map((item) => _ModeChip(
                  icon: item['icon']!, label: item['label']!,
                  isSelected: _learningMode == item['key'],
                  onTap: () { setModal(() {}); setState(() { _learningMode = item['key']!; _quickReplies = _defaultQuickReplies; }); },
                )).toList(),
              ),
              const SizedBox(height: 24),
              _settingLabel('Tôi là'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.8,
                children: [
                  {'key': 'kid', 'icon': '🧒', 'label': 'Trẻ em'},
                  {'key': 'student', 'icon': '🎓', 'label': 'Sinh viên'},
                  {'key': 'adult', 'icon': '💼', 'label': 'Người đi làm'},
                  {'key': 'elder', 'icon': '👴', 'label': 'Người lớn tuổi'},
                ].map((item) => _ModeChip(
                  icon: item['icon']!, label: item['label']!,
                  isSelected: _userType == item['key'],
                  onTap: () { setModal(() {}); setState(() => _userType = item['key']!); },
                )).toList(),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(_DS.radiusSm)),
                child: Row(children: [
                  const Icon(Icons.volume_up_rounded, color: _DS.textGrey),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Tự động đọc tin nhắn AI', style: TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark))),
                  Switch(value: _autoSpeak, activeColor: _DS.indigo,
                      onChanged: (v) { setModal(() {}); setState(() => _autoSpeak = v); }),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _startNewConversation();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFE),
                      borderRadius: BorderRadius.circular(_DS.radiusSm),
                      border: Border.all(color: _DS.indigo.withOpacity(0.3)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_comment_rounded, color: _DS.indigo, size: 18),
                      SizedBox(width: 8),
                      Text('Trò chuyện mới', style: TextStyle(color: _DS.indigo, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () { Navigator.pop(context); setState(() {}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                      borderRadius: BorderRadius.circular(_DS.radiusSm),
                      boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: const Text('Xong', textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
    setState(() {});
  }

  Widget _settingLabel(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gradient = _aiGradient;
    return Scaffold(
      backgroundColor: _DS.chatBg,
      body: SafeArea(
        child: Column(children: [
          _buildContextBar(gradient),
          Expanded(
            child: Stack(children: [
              // Subtle background pattern
              Positioned.fill(
                child: CustomPaint(painter: _HanziPatternPainter()),
              ),
              _messages.isEmpty
                  ? _buildWelcome(gradient)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _messages.length + (_isLoading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _messages.length) return _buildTyping(gradient);
                        final msg = _messages[i];
                        return _ChatBubble(
                          message: msg['content'] as String,
                          isUser: msg['role'] == 'user',
                          aiGender: _aiGender,
                          gradient: gradient,
                          aiMoodColor: _aiMoodColor,
                          learningMode: _learningMode,
                          hanziCache: _hanziCache,
                          onSpeak: () => _voiceController.speak(msg['content'] as String, aiGender: _aiGender, learningMode: _learningMode),
                          onStop: _voiceController.stopSpeaking,
                        );
                      },
                    ),
              if (_showXpPop)
                Positioned(
                  top: 16, left: 0, right: 0,
                  child: Center(
                    child: ScaleTransition(
                      scale: _xpPopAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        child: Text(_xpPopText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          if (_newVocabSuggestions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              color: _DS.greenLight,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('💾 Lưu từ mới:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.green)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _newVocabSuggestions.map((word) => GestureDetector(
                    onTap: () => _saveVocab(word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _DS.green.withOpacity(0.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(word, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _DS.green)),
                        const SizedBox(width: 4),
                        const Icon(Icons.add_circle_rounded, size: 14, color: _DS.green),
                      ]),
                    ),
                  )).toList(),
                ),
              ]),
            ),
          if (_voiceController.isListening)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _DS.indigoLight,
              child: Row(children: [
                const Icon(Icons.mic_rounded, color: _DS.indigo, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _liveTranscript.isNotEmpty ? _liveTranscript : 'Đang nghe...',
                  style: const TextStyle(color: _DS.indigo, fontStyle: FontStyle.italic, fontSize: 13),
                )),
              ]),
            ),
          if (!_isVip && _freeMessagesLeft <= 2 && _freeMessagesLeft > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _DS.yellowLight,
              child: Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: Text('Còn $_freeMessagesLeft tin nhắn miễn phí!',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.textDark))),
                GestureDetector(
                  onTap: _showUpgradeDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]), borderRadius: BorderRadius.circular(12)),
                    child: const Text('VIP ngay', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          _buildQuickReplies(),
          _buildInputBar(gradient),
        ]),
      ),
    );
  }

  // ── CONTEXT BAR — Indigo immersive ────────────────────────
  Widget _buildContextBar(List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _DS.indigoDeep,
        boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        // Avatar với mood indicator
        Stack(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              border: Border.all(color: _aiMoodColor, width: 2.5),
              boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(_aiMoodEmoji, style: const TextStyle(fontSize: 22))),
          ),
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: _DS.green,
                shape: BoxShape.circle,
                border: Border.all(color: _DS.indigoDeep, width: 2),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 12),

        // AI info
        Expanded(child: GestureDetector(
          onTap: _showSettings,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_aiName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Text(_getLearningModeLabel(), style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _DS.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _sessionMessages > 0
                        ? 'Đang online · $_aiMood · ${_relationshipLabel(_aiMemory)} · Đã trò chuyện $_sessionMessages tin trong phiên này'
                        : 'Đang online · $_aiMood · ${_relationshipLabel(_aiMemory)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ]),
        )),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoleplayScreen())),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('🎭', style: TextStyle(fontSize: 14)),
              SizedBox(width: 4),
              Text('Nhập vai', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        GestureDetector(
          onTap: _openHistory,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.history_rounded, size: 18, color: Colors.white70),
          ),
        ),

        // Quota + settings
        if (!_isVip)
          GestureDetector(
            onTap: _showUpgradeDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Text('💬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text('$_freeMessagesLeft', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showSettings,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune_rounded, size: 18, color: Colors.white70),
          ),
        ),
      ]),
    );
  }

  // ── WELCOME SCREEN ────────────────────────────────────────
  Widget _buildWelcome(List<Color> gradient) {
    final greetings = {
      'kid': 'Xin chào bạn nhỏ!\nMình là $_aiName, bạn thân của bạn! 👋',
      'student': 'Ê! Mình là $_aiName nè! 👋\nCùng học vui nhất có thể — no cap!',
      'adult': 'Xin chào! Tôi là $_aiName 👋\nGiúp bạn học ngôn ngữ thực tế.',
      'elder': 'Xin chào anh/chị!\nTôi là $_aiName, rất vui được đồng hành! 👋',
    };
    final suggestions = {
      'kid': ['Màu sắc tiếng Trung', 'Con mèo tiếng Trung là gì?', 'Đếm số 1-10', 'Gia đình tiếng Trung'],
      'student': ['Tao hay phát âm sai, giúp tao!', 'Dạy tao gọi món ở quán ăn', 'Cách nói chuyện với sếp', 'Văn hóa Đài Loan hay ho gì?'],
      'adult': ['Từ vựng công sở', 'Đi bệnh viện cần biết gì?', 'Hỏi thuê nhà tiếng Trung', 'Mở tài khoản ngân hàng'],
      'elder': ['Chào hỏi cơ bản', 'Mua sắm ở chợ', 'Hỏi đường', 'Gọi đồ uống'],
    };

    return SingleChildScrollView(
      child: Column(children: [
        // Top illustration — full width
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_DS.indigoDeep, gradient[0].withOpacity(0.8)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
          child: Column(children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: Image.asset('assets/images/Work_chat-bro.webp', fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),

            // Avatar
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Center(child: Text(_aiMoodEmoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 12),

            // Typing animation
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _TypingDot(delay: 0, color: Colors.white54, speed: 600),
              const SizedBox(width: 4),
              _TypingDot(delay: 150, color: Colors.white54, speed: 600),
              const SizedBox(width: 4),
              _TypingDot(delay: 300, color: Colors.white54, speed: 600),
              const SizedBox(width: 8),
              Text('$_aiName đang chờ bạn...', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            ]),
            const SizedBox(height: 20),
          ]),
        ),

        // Content section
        Container(
          color: _DS.chatBg,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greetings[_userType] ?? '', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textDark, height: 1.5)),
            const SizedBox(height: 6),
            const Center(child: Text('Bấm 🎤 để nói chuyện trực tiếp!', style: TextStyle(fontSize: 13, color: _DS.textGrey))),
            const SizedBox(height: 24),

            const Text('Thử hỏi nhé:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: (suggestions[_userType] ?? []).map((text) => GestureDetector(
                onTap: () => _send(voiceText: text),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _DS.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _DS.indigoLight),
                    boxShadow: [BoxShadow(color: _DS.indigo.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(text, style: const TextStyle(fontSize: 12, color: _DS.indigo, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── QUICK REPLIES ─────────────────────────────────────────
  Widget _buildQuickReplies() {
    if (_quickReplies.isEmpty || _isLoading) return const SizedBox.shrink();
    return Container(
      color: _DS.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SizedBox(
        height: 34,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _quickReplies.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _send(voiceText: _quickReplies[i]),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _DS.indigoLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _DS.indigo.withOpacity(0.2)),
              ),
              child: Text(_quickReplies[i],
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.indigo)),
            ),
          ),
        ),
      ),
    );
  }

  // ── TYPING ────────────────────────────────────────────────
  Widget _buildTyping(List<Color> gradient) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AiAvatar(gender: _aiGender, gradient: gradient, moodEmoji: _aiMoodEmoji, size: 36),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18),
              bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4),
            ),
            border: Border(left: BorderSide(color: _DS.indigo, width: 3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TypingDot(delay: 0, color: _DS.indigo, speed: _typingDotSpeed),
            const SizedBox(width: 4),
            _TypingDot(delay: 150, color: _DS.indigo, speed: _typingDotSpeed),
            const SizedBox(width: 4),
            _TypingDot(delay: 300, color: _DS.indigo, speed: _typingDotSpeed),
          ]),
        ),
        const SizedBox(width: 8),
        Text('$_aiName đang soạn...',
            style: TextStyle(fontSize: 10, color: _DS.textGrey.withOpacity(0.6), fontStyle: FontStyle.italic)),
      ]),
    );
  }

  // ── INPUT BAR ─────────────────────────────────────────────
  Widget _buildInputBar(List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: _DS.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        // Mic button — Indigo
        GestureDetector(
          onTap: (_isLoading || _voiceController.isProcessing) ? null : (_voiceController.isListening ? _voiceController.stopListening : _showMicOverlay),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: _voiceController.isListening
                  ? const LinearGradient(colors: [Colors.red, Color(0xFFB71C1C)])
                  : const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: (_voiceController.isListening ? Colors.red : _DS.indigo).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(_voiceController.isListening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 10),

        // Input field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _DS.bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _DS.indigoLight),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 3, minLines: 1,
              style: const TextStyle(fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                hintText: _voiceController.isListening ? '🎤 Đang nghe...' : 'Nhắn tin với $_aiName...',
                hintStyle: TextStyle(color: _DS.textGrey.withOpacity(0.7), fontSize: 14),
                filled: true, fillColor: _DS.bg,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Send button — Indigo gradient
        GestureDetector(
          onTap: _isLoading ? null : _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200])
                  : const LinearGradient(colors: [_DS.indigo, _DS.indigoDark]),
              shape: BoxShape.circle,
              boxShadow: [if (!_isLoading) BoxShadow(color: _DS.indigo.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: _isLoading
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HANZI BACKGROUND PATTERN
// ═══════════════════════════════════════════════════════════════
class _HanziPatternPainter extends CustomPainter {
  static const _chars = ['你', '好', '學', '習', '愛', '台', '灣', '語', '言', '朋', '友', '工', '作'];

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      fontSize: 28,
      color: const Color(0xFF5B5FEF).withOpacity(0.04),
      fontWeight: FontWeight.w900,
    );
    int charIndex = 0;
    for (double y = 0; y < size.height; y += 60) {
      for (double x = 0; x < size.width; x += 50) {
        final char = _chars[charIndex % _chars.length];
        final tp = TextPainter(
          text: TextSpan(text: char, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, y));
        charIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(_HanziPatternPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════
class _AiAvatar extends StatelessWidget {
  final String gender;
  final List<Color> gradient;
  final String moodEmoji;
  final double size;
  const _AiAvatar({required this.gender, required this.gradient, required this.moodEmoji, required this.size});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: gradient[0], width: 2),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: ClipOval(
          child: Image.asset(
            gender == 'female'
                ? 'assets/images/Work_chat-bro.webp'
                : 'assets/images/Digital_tools-rafiki.webp',
            fit: BoxFit.cover,
          ),
        ),
      ),
      // Mood indicator góc dưới phải
      Positioned(
        right: 0, bottom: 0,
        child: Container(
          width: size * 0.35, height: size * 0.35,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: gradient[0], width: 1),
          ),
          child: Center(child: Text(moodEmoji, style: TextStyle(fontSize: size * 0.18))),
        ),
      ),
    ],
  );
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final String aiGender;
  final List<Color> gradient;
  final Color aiMoodColor;
  final VoidCallback onSpeak;
  final VoidCallback onStop;
  final String learningMode;
  final Map<String, String> hanziCache;

  const _ChatBubble({
    required this.message, required this.isUser, required this.aiGender,
    required this.gradient, required this.aiMoodColor,
    required this.onSpeak, required this.onStop,
    required this.learningMode, required this.hanziCache,
  });

  void _showBubbleMenu(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.volume_up_rounded, color: _DS.indigo),
            title: const Text('Nghe phát âm', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); onSpeak(); },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: _DS.blue),
            title: const Text('Sao chép', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); Clipboard.setData(ClipboardData(text: message)); },
          ),
          if (!isUser)
            ListTile(
              leading: const Icon(Icons.stop_circle_rounded, color: _DS.textGrey),
              title: const Text('Dừng phát âm', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () { if (Navigator.canPop(context)) Navigator.pop(context); onStop(); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _buildHighlightedText(String text, Color highlightColor, String learningMode) {
    if (learningMode == 'en_only' || learningMode == 'en_vi') {
      return Text(text, style: const TextStyle(color: _DS.textDark, fontSize: 14, height: 1.7));
    }
    final spans = <TextSpan>[];
    final regex = RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf，。！？、：；「」『』【】…—]+');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: _DS.textDark.withOpacity(0.8), fontSize: 14, height: 1.7),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: highlightColor, fontSize: 17, fontWeight: FontWeight.w800, height: 1.7, fontFamily: 'NotoSansTC'),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: _DS.textDark.withOpacity(0.75), fontSize: 13, height: 1.7, fontStyle: FontStyle.italic),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _AiAvatar(gender: aiGender, gradient: gradient, moodEmoji: '😊', size: 34),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showBubbleMenu(context),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: isUser ? LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                      color: isUser ? null : _DS.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: isUser ? null : Border(left: BorderSide(color: aiMoodColor, width: 3)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: isUser
                        ? Text(message, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6))
                        : _buildHighlightedText(hanziCache[message] ?? message, gradient[0], learningMode),
                  ),
                  if (!isUser) ...[
                    const SizedBox(height: 5),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _ActionPill(icon: Icons.volume_up_rounded, label: 'Nghe', color: gradient[0], onTap: onSpeak),
                      const SizedBox(width: 6),
                      _ActionPill(icon: Icons.copy_rounded, label: 'Copy', color: _DS.textGrey,
                          onTap: () => Clipboard.setData(ClipboardData(text: message))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionPill({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

class _TypingDot extends StatefulWidget {
  final int delay, speed;
  final Color color;
  const _TypingDot({required this.delay, required this.color, required this.speed});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: Duration(milliseconds: widget.speed), vsync: this);
    _anim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.repeat(reverse: true); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, -5 * _anim.value),
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ),
  );
}

class _AiCard extends StatelessWidget {
  final String name, sub, emoji;
  final bool isSelected;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _AiCard({required this.name, required this.sub, required this.emoji,
      required this.isSelected, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isSelected ? LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        color: isSelected ? null : _DS.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200, width: 2),
        boxShadow: isSelected ? [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isSelected ? Colors.white : _DS.textDark)),
        Text(sub, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : _DS.textGrey)),
      ]),
    ),
  );
}

class _ModeChip extends StatelessWidget {
  final String icon, label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ModeChip({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? _DS.indigoLight : _DS.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? _DS.indigo : Colors.grey.shade200, width: isSelected ? 2 : 1),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 12,
          color: isSelected ? _DS.indigo : _DS.textDark,
        ), overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}

class _ChatPulseRing extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;
  final int delay;
  const _ChatPulseRing({required this.size, required this.color, required this.opacity, required this.delay});

  @override
  State<_ChatPulseRing> createState() => _ChatPulseRingState();
}

class _ChatPulseRingState extends State<_ChatPulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: widget.opacity, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.repeat(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Transform.scale(
      scale: _scale.value,
      child: Container(
        width: widget.size, height: widget.size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(_fade.value)),
      ),
    ),
  );
}
