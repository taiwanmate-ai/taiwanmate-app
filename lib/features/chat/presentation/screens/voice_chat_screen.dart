/// VoiceChatScreen — Lop 6 (2026-08-15): khung UI TOI THIEU de test THAT
/// bang mic/loa — noi day toan bo cac lop truoc do (mic that, WebSocket,
/// STT, AI streaming, TTS streaming, Interrupt) thanh 1 luong hoan chinh.
/// KHONG dep, chi can chay dung va de doc trang thai khi test.
///
/// TODO (paywall Voice — CHUA xay he thong VIP Voice/Polar/Play Billing
/// rieng cho tinh nang nay o buoc nay, de danh cho luc launch that): man
/// hinh nay hien KHONG gioi han phut/kiem tra VIP cho BAT KY user nao —
/// moi user vao duoc thoai mai. Khi he thong VIP Voice san sang, THEM
/// kiem tra o day (vd goi API check quota truoc _startSession(), hien thi
/// dialog nang cap neu het quota) — giong dung cach RoleplayScreen dang
/// lam voi _isVip/_showVipRequiredDialog().
///
/// QUYET DINH KIEN TRUC (2026-08-15, sau 7 Phase cai thien VAD/Confidence
/// Gate van khong giai quyet duoc GOC RE Whisper hallucination — xac nhan
/// qua test that: AI van tra loi tu tin dua tren transcript sai, Gate
/// khong kich hoat): CHUYEN TU VAD tu dong (hands-free, tu doan
/// speechStarted/speechEnded) SANG PUSH-TO-TALK (bam giu de noi, tha tay
/// de gui NGAY LAP TUC) — giong het luong ghi am GOC truoc Phase 2, chi
/// khac la gui qua WebSocket streaming (audio_chunk/audio_end) thay vi 1
/// file REST. Loai bo HOAN TOAN nguon goc loi: audio gui di CHINH XAC
/// dung khoang thoi gian user CHU DONG bam giu, khong con phu thuoc may
/// tu doan thoi diem bat dau/ket thuc noi.
///
/// VoiceActivityDetector/VoiceMicRecorder/Confidence Gate backend GIU
/// NGUYEN (KHONG xoa) — VAD gio CHI dung cho 1 muc dich DUY NHAT: XAC
/// NHAN Interrupt la THAT (khong phai bam nham) khi user bam giu nut mic
/// TRONG LUC AI dang noi — dung VAD DUNG voi y nghia ban dau cua no
/// (phat hien giong noi that su), khong con dung de tu dong phat hien
/// TOAN BO ranh gioi 1 luot noi nua. Confidence Gate backend van giu lam
/// luoi an toan cuoi cho truong hop bam nham/audio ngan/nhieu.
library;

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/constants/api_constants.dart';
import 'package:chinesemate/core/providers/learning_mode_provider.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';
import 'package:chinesemate/features/chat/engines/mood_tag_parser.dart';
import 'package:chinesemate/features/chat/engines/voice_teaching_instruction.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';
import 'package:chinesemate/features/chat/engines/companion_voice_controller.dart';
import 'package:chinesemate/features/chat/engines/voice_mic_recorder.dart';
import 'package:chinesemate/features/chat/engines/voice_activity_detector.dart';
import 'package:chinesemate/features/chat/engines/sentence_accumulator.dart';
import 'learning_mode_selection_screen.dart';

enum _VoiceUiState { idle, connecting, readyToTalk, recording, processing, aiSpeaking, error }

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen> {
  final _storage = const FlutterSecureStorage();
  late final VoiceWebSocketService _wsService;
  late final CompanionVoiceController _voiceController;
  final VoiceMicRecorder _micRecorder = VoiceMicRecorder();

  /// VAD — CHI dung de xac nhan Interrupt that (xem docstring dau file).
  /// Dung fixedSpeechThresholdDb (BO QUA adaptive noise floor): luc user
  /// bam giu de ngat loi AI, ho BAT DAU NOI GAN NHU NGAY LAP TUC — KHONG
  /// co 1 khoang "im lang nen" tu nhien o dau de calibrate (khac han
  /// luong hands-free cu, luon co vai giay cho truoc khi user noi).
  /// Nguong -35dB KHOP DUNG gia tri da proven-working truoc day (nut mic
  /// GOC, webStartRecordingAutoStop). initialGracePeriod=0 — muon xac
  /// nhan CANG SOM CANG TOT, khong can doi (khac VAD hands-free cu can
  /// grace period de tranh tieng dong luc vua mo mic).
  final VoiceActivityDetector _interruptVad = VoiceActivityDetector(
    fixedSpeechThresholdDb: -35.0,
    initialGracePeriod: Duration.zero,
  );
  final SentenceAccumulator _sentenceAccumulator = SentenceAccumulator();

  StreamSubscription<double>? _ampSub;
  _VoiceUiState _uiState = _VoiceUiState.idle;
  String _transcriptText = '';
  String _aiText = '';
  String _errorMessage = '';

  /// True trong luc dang ghi am do BAM GIU XUAT PHAT TU luc AI dang noi
  /// (co the la Interrupt that, co the la bam nham) — phan biet voi 1
  /// lan bam giu binh thuong (readyToTalk -> recording, khong can VAD).
  bool _isInterruptAttempt = false;

  /// True neu VAD DA xac nhan day la giong noi that trong luot bam giu
  /// hien tai (chi co y nghia khi _isInterruptAttempt=true).
  bool _interruptConfirmed = false;

  // Bo qua cac ai_text_response_chunk con lai cua 1 luot AI VUA BI
  // INTERRUPT (server co the van dang gui not phan con trong hang doi
  // truoc khi kip nhan {"type":"interrupt"}) — tranh "hoi sinh" 1 cau tra
  // loi user da chu dong ngat. Duoc CLEAR khi chunk is_final:true cua
  // CHINH luot bi ngat do den (server luon gui du is_final sau interrupt,
  // xem docstring backend voice_ws.py).
  bool _ignoreCurrentAiTurn = false;

  static const _aiGender = 'female';

  /// 2026-08-20: doc tu learningModeProvider (nguon duy nhat, dung chung
  /// Chat+Voice — xem docstring learning_mode_provider.dart). TRUOC DAY
  /// hardcode 'zh_vi' o ca 2 noi goi speak() ben duoi — CHUA co lua chon
  /// nao ca, du learningMode() hien VAN la tham so vestigial (KHONG anh
  /// huong hanh vi speak() that su, xem grep xac nhan trong
  /// companion_voice_controller.dart) — cap nhat de nhat quan VA san sang
  /// cho Phan C (noi rule ngon ngu that vao backend Voice, CHUA lam).
  String _learningMode = 'zh_vi';

  /// Audit "Giao vien tuong tac that" (2026-08-27) — TRUOC DAY VoiceChatScreen
  /// KHONG bao gio goi /auth/me nen chineseLevel LUON null khi goi
  /// buildSystemPromptV2() (khac ChatScreen da fetch tu lau, xem _loadUserProfile()
  /// duoi day, dung Y HET pattern cua chat_screen.dart) — nghia la quy tac
  /// i+1 (do kho theo trinh do +1 bac) truoc gio KHONG CO GI de tinh toan
  /// cho Voice. Null an toan (buildSystemPromptV2 tu xu ly, mac dinh coi
  /// nhu beginner trong instruction moi — xem voice_teaching_instruction.dart).
  String? _chineseLevel;

  /// Buoc C (2026-08-20) — dung CHUNG engine voi Chat de xay system_prompt
  /// THAT gui kem audio_end, thay vi prompt co dinh backend tu bia
  /// (_FALLBACK_SYSTEM_PROMPT, xem docstring voice_ws.py). Voice CHUA theo
  /// doi day du context nhu ChatScreen (sessionMessages/mistakes/aiMemory...)
  /// nen dung gia tri mac dinh hop ly cho cac truong con thieu — gioi han
  /// da biet, chua co ca nhan hoa/tri nho sau nhu Chat.
  static const _personalityEngine = CompanionPersonalityEngine();

  /// Chu ky poll bien do (dB) tu mic khi dang xac nhan Interrupt — can
  /// nhanh de VAD co du "frame" tinh consecutive-frame/speech-ratio (xem
  /// docstring voice_activity_detector.dart).
  static const _kAmplitudePollInterval = Duration(milliseconds: 30);

  @override
  void initState() {
    super.initState();
    _learningMode = ref.read(learningModeProvider) ?? 'zh_vi';
    _loadUserProfile();
    _wsService = VoiceWebSocketService(tokenProvider: () => _storage.read(key: 'access_token'));
    _voiceController = CompanionVoiceController(
      tokenProvider: () => _storage.read(key: 'access_token'),
    );
    _voiceController.addListener(_onVoiceControllerChanged);

    _wsService.onTranscript = (text) {
      if (!mounted) return;
      setState(() => _transcriptText = text);
    };
    _wsService.onTranscriptError = (message) {
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
        _uiState = _VoiceUiState.readyToTalk;
      });
    };
    _wsService.onTranscriptLowConfidence = (text, message) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '';
        _transcriptText = text;
        _aiText = message;
        _uiState = _VoiceUiState.aiSpeaking;
      });
      // Phat lai message xac nhan qua TTS (giong phan ung nguoi that xin
      // noi lai) — dung LAI speak() don gian (KHONG can co che streaming
      // — day la 1 cau CO DINH, ngan, khong phai AI sinh nhieu cau).
      // _onVoiceControllerChanged() se tu dua UI ve "readyToTalk" khi
      // phat xong, giong het duong di AI tra loi binh thuong.
      _voiceController.speak(message, aiGender: _aiGender, learningMode: _learningMode);
    };
    _wsService.onAiTextResponseChunk = _onAiTextResponseChunk;
    _wsService.onAiTextResponseError = (message) {
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
        _uiState = _VoiceUiState.readyToTalk;
      });
    };
  }

  /// Audit "Giao vien tuong tac that" (2026-08-27) — dung Y HET pattern cua
  /// ChatScreen._loadUserProfile() (chat_screen.dart) de vá gap chineseLevel
  /// (xem docstring _chineseLevel o tren). Loi mang/loi bat ky deu im lang
  /// bo qua (giu _chineseLevel = null, buildSystemPromptV2 tu xu ly an toan)
  /// — giong dung tinh than cac ham _load*() khac trong app nay.
  Future<void> _loadUserProfile() async {
    try {
      if (!mounted) return;
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.me}',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (!mounted) return;
      final chineseLevel = response.data['chinese_level'] as String?;
      if (chineseLevel != null) {
        setState(() => _chineseLevel = chineseLevel);
      }
    } catch (e) {}
  }

  void _onAiTextResponseChunk(String text, bool isFinal) {
    if (_ignoreCurrentAiTurn) {
      if (isFinal) _ignoreCurrentAiTurn = false;
      return;
    }

    if (isFinal) {
      final remainder = _sentenceAccumulator.flush();
      if (remainder.isNotEmpty) {
        final extracted = extractMoodTag(remainder);
        _voiceController.appendStreamingSentence(extracted.text, aiGender: _aiGender, mood: extracted.mood);
      }
      _voiceController.finishStreamingSpeak();
      return;
    }

    if (_uiState != _VoiceUiState.aiSpeaking) {
      _voiceController.startStreamingSpeak(aiGender: _aiGender);
      if (mounted) {
        setState(() {
          _uiState = _VoiceUiState.aiSpeaking;
          _aiText = '';
        });
      }
    }
    // Audit "Speech Naturalizer" (2026-08-24) — _aiText la text HIEN THI
    // tren man hinh (dong 476), PHAI boc sach tag [MOOD:...] truoc khi
    // hien, khac voi `text` (delta THO) van duoc dua nguyen ven vao
    // SentenceAccumulator ben duoi (SentenceAccumulator/extractMoodTag can
    // tag nguyen ven o cap do CAU de bóc dung, khong lien quan bien hien
    // thi nay).
    if (mounted) setState(() => _aiText = stripMoodTagsForDisplay(_aiText + text));
    final sentences = _sentenceAccumulator.addDelta(text);
    for (final s in sentences) {
      final extracted = extractMoodTag(s);
      _voiceController.appendStreamingSentence(extracted.text, aiGender: _aiGender, mood: extracted.mood);
    }
  }

  void _onVoiceControllerChanged() {
    // AI noi xong TU NHIEN (khong phai do Interrupt — Interrupt da tu
    // chuyen _uiState sang "recording" truoc do trong _onInterruptVadAmplitude(),
    // luc do dieu kien duoi day se KHONG khop, tranh chuyen state sai).
    if (!_voiceController.isSpeaking && _uiState == _VoiceUiState.aiSpeaking && mounted) {
      setState(() => _uiState = _VoiceUiState.readyToTalk);
    }
  }

  Future<void> _startSession() async {
    setState(() {
      _uiState = _VoiceUiState.connecting;
      _errorMessage = '';
      _transcriptText = '';
      _aiText = '';
    });

    await _wsService.connect();
    if (!mounted) return;
    if (!_wsService.isConnected) {
      setState(() {
        _uiState = _VoiceUiState.error;
        _errorMessage = 'Không kết nối được server. Kiểm tra mạng và thử lại.';
      });
      return;
    }

    setState(() => _uiState = _VoiceUiState.readyToTalk);
  }

  /// Bam GIU nut mic — bat dau ghi am NGAY LAP TUC. Neu bam trong luc AI
  /// dang noi, day la 1 NO LUC Interrupt — can VAD xac nhan giong noi
  /// that TRUOC KHI thuc su ngat AI (xem _onInterruptVadAmplitude()).
  Future<void> _onMicPressStart() async {
    final isInterruptAttempt = _uiState == _VoiceUiState.aiSpeaking;
    if (!isInterruptAttempt && _uiState != _VoiceUiState.readyToTalk) {
      return; // chi cho bam khi dang san sang HOAC AI dang noi (de ngat)
    }

    _isInterruptAttempt = isInterruptAttempt;
    _interruptConfirmed = false;

    final started = await _micRecorder.start();
    if (!mounted) return;
    if (!started) {
      setState(() {
        _errorMessage = 'Không có quyền micro hoặc lỗi micro.';
      });
      _isInterruptAttempt = false;
      return;
    }

    if (isInterruptAttempt) {
      _interruptVad.reset();
      _interruptVad.start(DateTime.now());
      _ampSub?.cancel();
      _ampSub = _micRecorder.onAmplitudeDb(interval: _kAmplitudePollInterval).listen(_onInterruptVadAmplitude);
    }

    if (mounted) setState(() => _uiState = _VoiceUiState.recording);
  }

  /// CHI duoc goi trong luc dang xac nhan Interrupt (bam giu tu trang
  /// thai aiSpeaking) — dung VoiceActivityDetector DUNG voi y nghia ban
  /// dau: xac nhan giong noi THAT (khong phai bam nham) truoc khi ngat AI.
  void _onInterruptVadAmplitude(double amplitudeDb) {
    final event = _interruptVad.processAmplitude(amplitudeDb, DateTime.now());
    if (event != VadEvent.speechStarted) return;

    _interruptConfirmed = true;
    _ignoreCurrentAiTurn = true;
    _wsService.sendInterrupt();
    _voiceController.stopSpeaking();
    if (mounted) setState(() => _aiText = '');
  }

  /// THA tay khoi nut mic — gui audio_end NGAY LAP TUC (khong con doi VAD
  /// tu doan ket thuc noi nua). Neu day la 1 no luc Interrupt CHUA duoc
  /// VAD xac nhan (bam nham thoang qua trong luc AI dang noi) -> HUY BO
  /// HOAN TOAN, KHONG gui gi ca, AI tiep tuc noi binh thuong.
  Future<void> _onMicPressEnd() async {
    if (_uiState != _VoiceUiState.recording) return;
    await _ampSub?.cancel();
    _ampSub = null;

    if (_isInterruptAttempt && !_interruptConfirmed) {
      // Bam nham thoang qua — VAD CHUA kip xac nhan la giong noi that.
      await _micRecorder.cancel();
      _interruptVad.reset();
      _isInterruptAttempt = false;
      if (mounted) setState(() => _uiState = _VoiceUiState.aiSpeaking);
      return;
    }
    _isInterruptAttempt = false;

    if (mounted) {
      setState(() {
        _uiState = _VoiceUiState.processing;
        _transcriptText = '';
        _aiText = '';
      });
    }

    final bytes = await _micRecorder.stop();
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _uiState = _VoiceUiState.readyToTalk);
      return;
    }

    _wsService.sendAudioChunk(base64Encode(bytes));

    // Buoc C — xay system_prompt THAT theo dung _learningMode nguoi dung
    // da chon (qua CHINH engine cua Chat), gui kem audio_end de backend
    // dung THAT thay vi fallback co dinh. currentUserText de rong vi
    // audio_end duoc gui TRUOC khi backend transcribe xong (Voice khong
    // co STT phia client) — cac truong context khac dung mac dinh hop ly
    // vi VoiceChatScreen chua theo doi day du nhu ChatScreen (gioi han da
    // biet, xem docstring _personalityEngine o tren).
    final result = _personalityEngine.buildSystemPromptV2(
      learningMode: _learningMode,
      userType: 'student',
      sessionMessages: 0,
      mistakes: const [],
      userFrustrated: false,
      aiMemory: const {},
      nextAction: null,
      aiName: _aiGender == 'female' ? 'Yuki' : 'Kai',
      aiGender: _aiGender,
      isVip: false,
      now: DateTime.now(),
      currentUserText: '',
      recentlySuggestedTrendPhraseIds: const {},
      chineseLevel: _chineseLevel,
    );
    // Audit "Giao vien tuong tac that" (2026-08-27) — noi THEM (khong sua)
    // quy tac IRF + Comprehensible Input i+1, CHI cho Voice, TRUOC
    // kVoiceNaturalizerInstruction (cau truc/noi dung luot noi truoc, giong
    // dieu/mood sau — xem docstring voice_teaching_instruction.dart, bao
    // gom giai thich xung dot voi rule 15 "cau hoi rong" da phat hien va
    // xu ly rieng cho Voice o do).
    //
    // Audit "Speech Naturalizer" (2026-08-24) — noi THEM (khong sua)
    // huong dan noi tu nhien + yeu cau mood tag, CHI cho Voice (Chat
    // KHONG goi doan nay — buildSystemPromptV2()/companion_personality_
    // engine.dart giu nguyen 100%). Xem docstring kVoiceNaturalizerInstruction.
    final voiceSystemPrompt = result.prompt + kVoiceInteractiveTeachingInstruction + kVoiceNaturalizerInstruction;
    _wsService.sendAudioEnd(systemPrompt: voiceSystemPrompt, learningMode: _learningMode);
  }

  Future<void> _stopSession() async {
    await _ampSub?.cancel();
    _ampSub = null;
    _interruptVad.reset();
    await _micRecorder.cancel();
    _voiceController.stopSpeaking();
    _wsService.disconnect();
    if (!mounted) return;
    setState(() {
      _uiState = _VoiceUiState.idle;
      _transcriptText = '';
      _aiText = '';
      _errorMessage = '';
      _isInterruptAttempt = false;
      _interruptConfirmed = false;
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _micRecorder.dispose();
    _voiceController.removeListener(_onVoiceControllerChanged);
    _voiceController.dispose();
    _wsService.dispose();
    super.dispose();
  }

  String get _statusText {
    switch (_uiState) {
      case _VoiceUiState.idle:
        return 'Chưa bắt đầu';
      case _VoiceUiState.connecting:
        return 'Đang kết nối...';
      case _VoiceUiState.readyToTalk:
        return '🎤 Giữ nút bên dưới để nói';
      case _VoiceUiState.recording:
        return '🔴 Đang ghi âm... (thả tay để gửi)';
      case _VoiceUiState.processing:
        return '⏳ Đang xử lý...';
      case _VoiceUiState.aiSpeaking:
        return '🔊 AI đang nói... (giữ mic để ngắt lời)';
      case _VoiceUiState.error:
        return '⚠️ Lỗi';
    }
  }

  Color get _statusColor {
    switch (_uiState) {
      case _VoiceUiState.idle:
        return Colors.grey;
      case _VoiceUiState.connecting:
        return Colors.orange;
      case _VoiceUiState.readyToTalk:
        return Colors.green;
      case _VoiceUiState.recording:
        return Colors.red;
      case _VoiceUiState.processing:
        return Colors.blue;
      case _VoiceUiState.aiSpeaking:
        return Colors.purple;
      case _VoiceUiState.error:
        return Colors.red;
    }
  }

  bool get _sessionActive => _uiState != _VoiceUiState.idle && _uiState != _VoiceUiState.error;

  bool get _micButtonEnabled =>
      _uiState == _VoiceUiState.readyToTalk || _uiState == _VoiceUiState.recording || _uiState == _VoiceUiState.aiSpeaking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trò chuyện trực tiếp (Voice) — test nội bộ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Đổi chế độ học',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LearningModeSelectionScreen(isFirstTime: false)),
              );
              // Doc lai SAU KHI quay ve (co the da doi trong man hinh vua
              // push) — dung ref.read (khong watch/listen lien tuc) vi CHI
              // can gia tri tuoi nhat tai thoi diem nay, giong dung tinh
              // than "ref.read, khong watch" da dung trong initState().
              if (!mounted) return;
              setState(() => _learningMode = ref.read(learningModeProvider) ?? 'zh_vi');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _statusColor, width: 2),
                ),
                width: double.infinity,
                child: Text(
                  _statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _statusColor),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bạn nói:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(_transcriptText.isEmpty ? '(chưa có)' : _transcriptText, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      const Text('AI trả lời:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(_aiText.isEmpty ? '(chưa có)' : _aiText, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_sessionActive)
                GestureDetector(
                  onTapDown: _micButtonEnabled ? (_) => _onMicPressStart() : null,
                  onTapUp: _micButtonEnabled ? (_) => _onMicPressEnd() : null,
                  onTapCancel: _micButtonEnabled ? _onMicPressEnd : null,
                  child: Container(
                    width: double.infinity,
                    height: 88,
                    decoration: BoxDecoration(
                      color: _uiState == _VoiceUiState.recording ? Colors.red : Colors.indigo,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_uiState == _VoiceUiState.recording ? Icons.mic : Icons.mic_none, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          _uiState == _VoiceUiState.recording ? 'Đang ghi... thả để gửi' : 'Giữ để nói',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _uiState == _VoiceUiState.connecting
                      ? null
                      : (_sessionActive ? _stopSession : _startSession),
                  icon: Icon(_sessionActive ? Icons.stop : Icons.mic),
                  label: Text(_sessionActive ? 'Dừng Voice' : 'Bắt đầu Voice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sessionActive ? Colors.grey.shade700 : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
