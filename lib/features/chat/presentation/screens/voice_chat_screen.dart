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
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/features/profile/presentation/screens/profile_screen.dart' show VipScreen;
import 'learning_mode_selection_screen.dart';

enum _VoiceUiState { idle, connecting, readyToTalk, recording, processing, aiSpeaking, error }

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
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

  /// Audit "Thiet ke lai UI Voice Chat" (2026-09-05) — bien do (dB) THAT tu
  /// mic, cap nhat moi 30ms trong luc "dang nghe" (xem _kAmplitudePollInterval)
  /// de driving vong pulsing quanh nut mic. Dung ValueNotifier (KHONG
  /// setState() toan man hinh moi tick — 30ms/lan la ~33 lan/giay, setState()
  /// ca cay se rebuild ca transcript/AppBar/... khong can thiet, gay lag tren
  /// thiet bi yeu/Safari cu) — chi widget bao boc trong ValueListenableBuilder
  /// (vong pulsing) rebuild theo tick nay, phan con lai cua man hinh khong
  /// dong toi. -60.0 = gia tri "im lang" mac dinh luc chua co du lieu that.
  final ValueNotifier<double> _amplitudeNotifier = ValueNotifier<double>(-60.0);

  /// AnimationController lap lien tuc (repeat-reverse, giong dung pattern
  /// _pulseCtrl da co san trong home_screen.dart) drive hieu ung "tho nhe"
  /// khi AI dang noi — CHI la hieu ung CACH DIEU (khong gan voi bien do
  /// audio TTS that, vi <audio> element khong co san du lieu muc am luong —
  /// them AnalyserNode That se can Web Audio API rieng, vuot pham vi "giu
  /// don gian" cua yeu cau thiet ke lai). Luon chay (re, vo hai) — CHI gia
  /// tri cua no duoc SU DUNG trong build() khi _uiState == aiSpeaking, cac
  /// trang thai khac bo qua hoan toan.
  late final AnimationController _aiSpeakingPulseCtrl;

  _VoiceUiState _uiState = _VoiceUiState.idle;
  String _transcriptText = '';
  String _aiText = '';
  String _errorMessage = '';

  /// Audit "Safari iOS: TTS khong phat am thanh" (2026-09-04) — dam bao
  /// webUnlockAudio() CHI duoc goi 1 LAN DUY NHAT trong ca phien Voice (lan
  /// dau tien bam mic), du webUnlockAudio() BEN TRONG da tu idempotent —
  /// tranh ca viec goi lai KHONG CAN THIET moi lan bam mic (vd moi lan
  /// Interrupt) o chinh diem goi, ro rang hon la dua hoan toan vao co che
  /// ben trong web_utils.
  bool _audioUnlockAttempted = false;

  /// Audit "khong thay CTA mua Voice tren man hinh test noi bo" (2026-09-02)
  /// — true khi server tu choi ket noi vi thieu/het han voice_access (xem
  /// onVoiceAccessRequired trong voice_websocket_service.dart). Khac voi
  /// cac loi KHAC trong _errorMessage (token/tai khoan khoa/da het 20 phut
  /// hom nay) — CHI truong hop nay moi can hien nut dieu huong toi VipScreen
  /// de mua, vi day la truong hop DUY NHAT nguoi dung co the tu giai quyet
  /// ngay tai cho bang cach mua goi.
  bool _voiceAccessRequired = false;

  /// Audit "canh bao cau qua ngan — Whisper hallucinate" (2026-08-30) —
  /// CANH BAO MEM (khac _errorMessage — mau/y nghia rieng, KHONG phai loi
  /// that) khi server bao "short_utterance_warning" (xem docstring
  /// _SHORT_UTTERANCE_WARNING_MS trong voice_ws.py) — luot van duoc AI tra
  /// loi binh thuong, CHI hien thi de nguoi dung tu can nhac muc do tin
  /// tuong ket qua nghe duoc, KHONG chan/huy gi ca.
  String _shortUtteranceWarning = '';

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
    WidgetsBinding.instance.addObserver(this);
    _aiSpeakingPulseCtrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);
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
    _wsService.onShortUtteranceWarning = (message) {
      if (!mounted) return;
      setState(() => _shortUtteranceWarning = message);
    };
    // Audit "gioi han 20 phut/ngay Voice + fix ket cung luc connect"
    // (2026-08-30) — chi CHUYEN sang _VoiceUiState.error khi dang o giua
    // luc connect (_uiState == connecting): day la cac truong hop server
    // TU CHOI ket noi va DONG NGAY SAU (token khong hop le, khong co
    // voice_access, da het 20 phut hom nay...) — KHONG con phien nao de
    // tiep tuc, dua UI ve trang thai loi ro rang de "Bat dau Voice" hien
    // lai. Cac trang thai KHAC (readyToTalk/recording/processing/
    // aiSpeaking) CHI hien message, KHONG ngat phien dang hoat dong —
    // day la loi vat nho giua session (vd audio_chunk hong), khong nen
    // coi nhu "chet phien".
    _wsService.onConnectionError = (message) {
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
        _voiceAccessRequired = false;
        if (_uiState == _VoiceUiState.connecting) {
          _uiState = _VoiceUiState.error;
        }
      });
    };
    // Audit "khong thay CTA mua Voice tren man hinh test noi bo" (2026-09-02)
    // — truoc day nhanh nay di chung onConnectionError (chi hien text do,
    // khong co cach nao dieu huong toi VipScreen de mua) — server gio gui
    // type rieng "voice_access_required" (xem voice_ws.py), tach callback
    // rieng de UI hien them nut "Mua gói Voice ngay".
    _wsService.onVoiceAccessRequired = (message) {
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
        _voiceAccessRequired = true;
        if (_uiState == _VoiceUiState.connecting) {
          _uiState = _VoiceUiState.error;
        }
      });
    };
    // Audit "gioi han 20 phut/ngay Voice" (2026-08-30) — server da GUI
    // message NAY roi TU DONG dong ket noi (xem docstring voice_ws.py) —
    // goi _stopSession() TRUOC (dung goi don dep sẵn co: huy VAD/mic,
    // ngat TTS, disconnect) roi MOI hien message, vi _stopSession() tu
    // reset _errorMessage='' trong chinh no — neu hien message TRUOC,
    // se bi xoa ngay sau do.
    _wsService.onVoiceTimeLimitReached = (message) async {
      if (!mounted) return;
      await _stopSession();
      if (!mounted) return;
      setState(() => _errorMessage = message);
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
        _voiceAccessRequired = false;
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
      _voiceAccessRequired = false;
      _transcriptText = '';
      _aiText = '';
      _shortUtteranceWarning = '';
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

    // Audit "Safari iOS: TTS khong phat am thanh" (2026-09-04) — goi
    // webUnlockAudio() DONG BO ngay tai day (TRUOC bat ky await nao ben
    // duoi), dung luc con nam trong user gesture that cua onTapDown — xem
    // docstring webUnlockAudio() (web_utils_impl.dart). CHI 1 LAN DUY NHAT
    // trong ca phien (lan dau bam mic): _audioUnlockAttempted chan cac lan
    // bam sau (vd Interrupt) khong goi lai, tranh vo tinh cat ngang audio
    // dang phat. Khong block ghi am neu that bai — STT/text van hoat dong
    // binh thuong du audio khong phat duoc, chi bao cho user biet ro thay
    // vi im lang.
    if (kIsWeb && !_audioUnlockAttempted) {
      _audioUnlockAttempted = true;
      final unlocked = await webUnlockAudio();
      if (!unlocked && mounted) {
        setState(() {
          _errorMessage = 'Trình duyệt không hỗ trợ phát âm thanh cho Voice. '
              'Vui lòng thử Chrome hoặc dùng app.';
        });
      }
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
    }
    // Audit "Thiet ke lai UI Voice Chat" (2026-09-05) — TRUOC DAY CHI
    // subscribe luc Interrupt (isInterruptAttempt) — gio LUON subscribe moi
    // lan bat dau ghi am (ca luot noi binh thuong), vi vong pulsing "dang
    // nghe" can du lieu bien do THAT o CA 2 truong hop, khong rieng Interrupt.
    // Dung 1 subscription DUY NHAT cho ca 2 muc dich (xem _onAmplitudeDb) —
    // KHONG mo 2 subscription song song toi CUNG 1 nguon (moi lan goi
    // onAmplitudeDb() tao 1 vong poll rieng ben duoi, lang phi neu trung lap).
    _ampSub?.cancel();
    _ampSub = _micRecorder.onAmplitudeDb(interval: _kAmplitudePollInterval).listen(_onAmplitudeDb);

    if (mounted) setState(() => _uiState = _VoiceUiState.recording);
  }

  /// Goi MOI lan co frame bien do moi trong luc dang ghi am (ca luot noi
  /// binh thuong LAN Interrupt) — luon cap nhat _amplitudeNotifier cho vong
  /// pulsing (khong setState() toan man hinh, xem docstring _amplitudeNotifier),
  /// CONG THEM xac nhan VAD Interrupt THAT (dung VoiceActivityDetector dung
  /// y nghia ban dau) CHI khi _isInterruptAttempt=true.
  void _onAmplitudeDb(double amplitudeDb) {
    _amplitudeNotifier.value = amplitudeDb;
    if (!_isInterruptAttempt) return;

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
    _amplitudeNotifier.value = -60.0; // reset vong pulsing ve trang thai im lang

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
        _shortUtteranceWarning = '';
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
    // dung THAT thay vi fallback co dinh.
    _wsService.sendAudioEnd(systemPrompt: _buildVoiceSystemPrompt(), learningMode: _learningMode);
  }

  /// Audit "Go chu fallback" (2026-08-30) — tach logic xay system_prompt
  /// (truoc day nam RIENG trong _onMicPressEnd()) thanh 1 ham dung CHUNG,
  /// de ca luot NOI (_onMicPressEnd) va luot GO CHU (_sendTypedText) deu
  /// xay CHINH XAC 1 system_prompt nhu nhau — dam bao AI ap dung dung
  /// luat/ngu canh bat ke input den tu giong noi hay chu go.
  ///
  /// currentUserText de rong vi ham nay duoc goi TRUOC khi biet noi dung
  /// cuoi cung (audio_end goi TRUOC khi backend transcribe xong — Voice
  /// khong co STT phia client; con luot go chu thi noi dung da go duoc
  /// gui rieng qua field 'text' cua text_input, khong can nhet vao day) —
  /// cac truong context khac dung mac dinh hop ly vi VoiceChatScreen chua
  /// theo doi day du nhu ChatScreen (gioi han da biet, xem docstring
  /// _personalityEngine o tren).
  String _buildVoiceSystemPrompt() {
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
    return result.prompt + kVoiceInteractiveTeachingInstruction + kVoiceNaturalizerInstruction;
  }

  /// Audit "Go chu fallback" (2026-08-30) — fallback UX kieu Duolingo (go
  /// chu la fallback HANG NHAT, khong phai loi) cho gioi han THAT cua STT
  /// voi cau ngan tron Viet-Trung chua hu tu ngu phap nhu 了/過/的 (xem
  /// docstring app/api/v1/voice_ws.py, test_voice_language_rule_garbled_
  /// input.py — KHONG the sua bang prompt/model). Gui THANG noi dung go
  /// qua text_input — backend BO QUA HOAN TOAN Whisper/Gate, di CHINH XAC
  /// 1 duong xu ly voi audio_end (_run_ai_turn ben backend), nen
  /// conversation_history/system_prompt/mood-override deu giong het — CHI
  /// khac o buoc NHAP LIEU (go thay vi noi).
  void _sendTypedText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _uiState = _VoiceUiState.processing;
      _transcriptText = trimmed;
      _aiText = '';
      _errorMessage = '';
      _voiceAccessRequired = false;
      _shortUtteranceWarning = '';
    });
    _wsService.sendTextInput(trimmed, systemPrompt: _buildVoiceSystemPrompt(), learningMode: _learningMode);
  }

  /// Hien 1 o nhap chu don gian (bottom sheet, KHONG phuc tap — giong ô
  /// chat text binh thuong nhu user yeu cau) de go thay vi noi. Dong lai
  /// va quay ve giao dien Voice binh thuong ngay khi gui (_sendTypedText
  /// tu chuyen UI sang "processing", giong het luong _onMicPressEnd()).
  void _showTypeTextSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 8,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Gõ câu bạn muốn nói...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (value) {
                    Navigator.pop(sheetContext);
                    _sendTypedText(value);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.indigo),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _sendTypedText(controller.text);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _stopSession() async {
    await _ampSub?.cancel();
    _ampSub = null;
    _amplitudeNotifier.value = -60.0;
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
      _voiceAccessRequired = false;
      _shortUtteranceWarning = '';
      _isInterruptAttempt = false;
      _interruptConfirmed = false;
    });
  }

  /// Audit "20 phut Voice het qua nhanh du chi noi vai cau" (2026-09-06) —
  /// gioi han 20 phut/ngay tinh theo THOI LUONG KET NOI WebSocket that su
  /// tu luc connect() toi luc disconnect() (Option B, quyet dinh CO CHU
  /// DICH da xac nhan voi user — xem docstring _DAILY_VOICE_MINUTES_LIMIT
  /// trong voice_ws.py), KHONG phai thoi luong noi THAT su. TRUOC DAY man
  /// hinh nay KHONG theo doi app lifecycle o bat ky dau — neu user dua app
  /// xuong NEN (chuyen app khac, khoa may) trong luc phien Voice VAN CON
  /// MO (vd sau khi noi vai cau, chua bam "Dung Voice"), ket noi WebSocket
  /// VAN SONG va tiep tuc tinh gio TRONG NEN — co the "an" gan het quota
  /// 20 phut ma user khong he biet vi khong con dang thuc su dung, dan toi
  /// bao cao that: "chi noi vai cau" nhung da bao het 20 phut. Dung phien
  /// NGAY khi app bi dua xuong nen thuc su (paused) — CHI paused (KHONG
  /// dung inactive, xay ra qua thuong xuyen/ngan cho cac giao dien tam
  /// thoi nhu dialog he thong/control center, se dung nham phien dang
  /// dung that) — dung LAI _stopSession() co san (dep dep mic/TTS/WS dung
  /// 1 duong, khong viet logic dong rieng).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _sessionActive) {
      _stopSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ampSub?.cancel();
    _aiSpeakingPulseCtrl.dispose();
    _amplitudeNotifier.dispose();
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
        return 'Giữ nút mic bên dưới để nói';
      case _VoiceUiState.recording:
        return 'Đang nghe... thả tay để gửi';
      case _VoiceUiState.processing:
        return 'Đang xử lý...';
      case _VoiceUiState.aiSpeaking:
        return 'AI đang nói... giữ mic để ngắt lời';
      case _VoiceUiState.error:
        return 'Lỗi';
    }
  }

  /// Audit "Thiet ke lai UI Voice Chat" (2026-09-05) — TRUOC DAY 6 mau
  /// Material chung chung khong lien quan (Colors.grey/orange/green/red/
  /// blue/purple), KHONG dong bo voi theme that cua app (user tu chon 1
  /// trong 7 mau primary + dark/light mode — xem theme_provider.dart). Gio
  /// lay TU CHINH ColorScheme cua context — tu dong dung mau/dung mode user
  /// da chon, khong bia mau moi. 4 trang thai chinh dung 4 role KHAC NHAU
  /// cua ColorScheme (primary/error/secondary/tertiary) de "de phan biet
  /// bang mat" nhu yeu cau, khong trung nhau.
  Color _stateColor(ColorScheme scheme) {
    switch (_uiState) {
      case _VoiceUiState.idle:
        return scheme.outline;
      case _VoiceUiState.connecting:
        return scheme.secondary;
      case _VoiceUiState.readyToTalk:
        return scheme.primary;
      case _VoiceUiState.recording:
        return scheme.error;
      case _VoiceUiState.processing:
        return scheme.secondary;
      case _VoiceUiState.aiSpeaking:
        return scheme.tertiary;
      case _VoiceUiState.error:
        return scheme.error;
    }
  }

  IconData get _micIcon {
    switch (_uiState) {
      case _VoiceUiState.recording:
        return Icons.mic;
      case _VoiceUiState.aiSpeaking:
        return Icons.graphic_eq;
      default:
        return Icons.mic_none;
    }
  }

  bool get _sessionActive => _uiState != _VoiceUiState.idle && _uiState != _VoiceUiState.error;

  bool get _micButtonEnabled =>
      _uiState == _VoiceUiState.readyToTalk || _uiState == _VoiceUiState.recording || _uiState == _VoiceUiState.aiSpeaking;

  /// Audit "Go chu fallback" (2026-08-30) — nut ban phim CHI bat khi dang
  /// "readyToTalk" (khac nut mic con dung ca luc AI dang noi de Interrupt)
  /// — go chu la 1 CACH KHOI DAU luot moi, khong co khai niem "ngat loi
  /// bang chu" o day.
  bool get _typeButtonEnabled => _uiState == _VoiceUiState.readyToTalk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stateColor = _stateColor(scheme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trò chuyện Voice'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              if (_errorMessage.isNotEmpty) ...[
                Text(_errorMessage, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                const SizedBox(height: 8),
              ],
              // Audit "khong thay CTA mua Voice tren man hinh test noi bo"
              // (2026-09-02) — TRUOC DAY thieu nut nay: user bi chan boi
              // _errorMessage o tren nhung KHONG co cach nao dieu huong toi
              // man hinh mua VIP Voice (VipScreen), phai tu tim duong sang
              // Profile. CHI hien khi _voiceAccessRequired=true (thieu/het
              // han voice_access) — cac loi KHAC (token/tai khoan khoa/da
              // dung het 20 phut hom nay) KHONG co nut nay vi khong giai
              // quyet duoc bang cach mua goi.
              if (_voiceAccessRequired) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VipScreen()),
                    ),
                    icon: const Icon(Icons.mic),
                    label: const Text('Mua gói Voice ngay'),
                    style: ElevatedButton.styleFrom(
                      // Giu NGUYEN mau tim/xanh nay (khong doi theo ColorScheme)
                      // — day CHINH LA mau da dung cho section "VIP Voice"
                      // trong VipScreen (profile_screen.dart), co chu dich
                      // tach biet voi mau cam VIP text-chat de tranh nham
                      // goi khi mua — doi mau o day se pha vo su nhat quan
                      // do.
                      backgroundColor: const Color(0xFF7C4DFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Audit "canh bao cau qua ngan — Whisper hallucinate" (2026-08-30)
              // — CO Y mau cam (KHONG dung do nhu _errorMessage) vi day la
              // CANH BAO MEM, khong phai loi that: luot van duoc AI tra loi
              // binh thuong (xem docstring _shortUtteranceWarning), chi giup
              // nguoi dung tu can nhac muc do tin tuong ket qua nghe duoc.
              if (_shortUtteranceWarning.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_shortUtteranceWarning, style: const TextStyle(color: Colors.orange, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Audit "Thiet ke lai UI Voice Chat" (2026-09-05) — thay khu
              // "Ban noi:/AI tra loi:" liet ke chu don thuan bang bong bong
              // chat that (Ban noi can PHAI, tint theo primary; AI tra loi
              // can TRAI, tint theo surfaceContainerHighest) — TAI SU DUNG
              // NGUYEN _transcriptText/_aiText, chi doi cach trinh bay.
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_transcriptText.isEmpty && _aiText.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Giữ nút mic bên dưới để bắt đầu trò chuyện cùng AI',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                          ),
                        ),
                      if (_transcriptText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _ChatBubble(
                            text: _transcriptText,
                            margin: const EdgeInsets.only(bottom: 10),
                            color: scheme.primary.withValues(alpha: 0.16),
                            textColor: scheme.onSurface,
                            radius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                        ),
                      if (_aiText.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ChatBubble(
                            text: _aiText,
                            color: scheme.surfaceContainerHighest,
                            textColor: scheme.onSurface,
                            radius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _statusText,
                  key: ValueKey(_uiState),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: stateColor),
                ),
              ),
              const SizedBox(height: 12),
              if (_sessionActive)
                // Audit "Layout vo hinh — nut Giu de noi" (2026-08-30, cap
                // nhat 2026-09-05 luc thiet ke lai UI) — BUG THAT tung xac
                // nhan qua console that (F12) + widget test that: 1 child
                // KHONG-flex cua Column co Expanded sibling (vung chat bubble
                // o tren) nhan rang buoc height UNBOUNDED tu Column — bat ky
                // widget con nao ben trong CAN 1 rang buoc height CO GIOI HAN
                // (truoc day la CrossAxisAlignment.stretch tren Row) se nem
                // loi "BoxConstraints forces an infinite height" NGAY trong
                // performLayout(). Van GIU NGUYEN nguyen tac fix da xac nhan
                // dung (SizedBox voi height CO DINH bao ngoai) cho khu nut mic
                // tron MOI nay — 220 du cho vong pulsing lon nhat (~190) +
                // le. Xem test/voice_chat_screen_mic_row_layout_test.dart
                // (van con hop le, cau truc SizedBox-bao-ngoai khong doi).
                SizedBox(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vong pulsing "dang nghe" — bien do dB THAT tu mic (xem
                      // docstring _amplitudeNotifier/_onAmplitudeDb).
                      if (_uiState == _VoiceUiState.recording)
                        ValueListenableBuilder<double>(
                          valueListenable: _amplitudeNotifier,
                          builder: (context, amplitudeDb, _) {
                            final normalized = ((amplitudeDb + 60) / 60).clamp(0.0, 1.0);
                            final ringSize = 132.0 + normalized * 60.0;
                            return Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.error.withValues(alpha: 0.10 + normalized * 0.18),
                              ),
                            );
                          },
                        ),
                      // Vong "tho nhe" cach dieu khi AI dang noi — KHONG gan
                      // voi bien do TTS that (xem docstring _aiSpeakingPulseCtrl).
                      if (_uiState == _VoiceUiState.aiSpeaking)
                        AnimatedBuilder(
                          animation: _aiSpeakingPulseCtrl,
                          builder: (context, _) {
                            final t = _aiSpeakingPulseCtrl.value;
                            final ringSize = 132.0 + t * 34.0;
                            return Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.tertiary.withValues(alpha: 0.10 + t * 0.14),
                              ),
                            );
                          },
                        ),
                      GestureDetector(
                        onTapDown: _micButtonEnabled ? (_) => _onMicPressStart() : null,
                        onTapUp: _micButtonEnabled ? (_) => _onMicPressEnd() : null,
                        onTapCancel: _micButtonEnabled ? _onMicPressEnd : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _uiState == _VoiceUiState.recording ? scheme.error : stateColor,
                            boxShadow: [
                              BoxShadow(
                                color: (_uiState == _VoiceUiState.recording ? scheme.error : stateColor)
                                    .withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _uiState == _VoiceUiState.processing
                                ? const SizedBox(
                                    key: ValueKey('spinner'),
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : Icon(_micIcon, key: ValueKey(_micIcon), color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                      // Audit "Go chu fallback" (2026-08-30, cap nhat khi
                      // thiet ke lai UI) — fallback khi STT nghe sai (xem
                      // docstring _sendTypedText) — gio la 1 icon tron NHO
                      // lech goc duoi-phai nut mic tron, KHONG con canh
                      // tranh su chu y voi nut mic chinh nhu truoc.
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _typeButtonEnabled ? _showTypeTextSheet : null,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                              backgroundColor: scheme.secondaryContainer,
                              disabledBackgroundColor: scheme.surfaceContainerHighest,
                              elevation: 2,
                            ),
                            child: Icon(Icons.keyboard, color: scheme.onSecondaryContainer, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _uiState == _VoiceUiState.connecting
                      ? null
                      : (_sessionActive ? _stopSession : _startSession),
                  icon: Icon(_sessionActive ? Icons.stop : Icons.play_arrow, size: 18),
                  label: Text(_sessionActive ? 'Dừng Voice' : 'Bắt đầu Voice'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audit "Thiet ke lai UI Voice Chat" (2026-09-05) — bong bong chat don
/// gian, tach rieng de tai su dung cho ca 2 phia (Ban noi/AI tra loi) thay
/// vi lap code Container 2 lan trong build().
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.color,
    required this.textColor,
    required this.radius,
    this.margin,
  });

  final String text;
  final Color color;
  final Color textColor;
  final BorderRadius radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: Text(text, style: TextStyle(fontSize: 15, color: textColor, height: 1.4)),
    );
  }
}
