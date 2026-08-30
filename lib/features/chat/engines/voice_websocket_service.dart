/// VoiceWebSocketService — Phase 2 Voice, Buoc 1 (2026-08-15).
///
/// CHI xay khung ket noi WebSocket toi /ws/voice — CHUA xu ly audio/VAD.
/// Muc dich: chung minh duong ong ket noi thong suot (connect, xac thuc
/// qua JWT, ping/pong, mat ket noi + tu ket noi lai) truoc khi buoc sau
/// them audio streaming that. KHONG co UI — chi log trang thai qua
/// debugPrint (theo dung yeu cau "chua can UI, chi can chay duoc va log
/// ro rang").
///
/// Dung package `web_socket_channel` (co san trong pubspec.yaml, CHUA
/// tung duoc dung o dau trong lib/ truoc gio) — cross-platform (web +
/// native) qua 1 API duy nhat WebSocketChannel.connect(), KHONG can tach
/// web_utils_impl/stub nhu cac tinh nang browser-only khac trong app nay.
///
/// Buoc 3+4a (2026-08-15): them xu ly nhan {"type":"transcript"/
/// "transcript_error"} (server-side STT, xem app/api/v1/voice_ws.py) va
/// {"type":"ai_text_response"/"ai_text_response_error"} (server-side AI
/// response, Buoc 4a — CHUA stream, gui 1 lan sau khi AI sinh xong).
///
/// Buoc 4b (2026-08-15): NANG CAP — server KHONG con gui
/// {"type":"ai_text_response"} nua (xem docstring app/api/v1/voice_ws.py),
/// thay bang {"type":"ai_text_response_chunk","text":"...",
/// "is_final":false/true} gui LIEN TUC tung phan. onAiTextResponse (cu) bi
/// XOA, thay bang onAiTextResponseChunk(text, isFinal) — text rong khi
/// isFinal=true (chunk cuoi CHI de danh dau ket thuc, khong mang noi
/// dung). onAiTextResponseError GIU NGUYEN (van dung cho truong hop AI
/// khong sinh duoc chunk nao ngay tu dau).
/// Expose qua CAC CALLBACK RIENG (khong goi truc tiep CompanionVoiceController
/// tu trong service nay) — giu service nay CHI lo protocol/ket noi, TACH
/// BIET voi logic phat TTS (CompanionVoiceController) giong dung tinh
/// than "moi lop 1 trach nhiem" da dung xuyen suot app nay. Noi day 2 lop
/// lai la viec cua CALLER (vd 1 man hinh/orchestrator sau nay o Lop 6):
///   voiceWsService.onAiTextResponseChunk = (text, isFinal) { ... }
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:chinesemate/core/constants/api_constants.dart';

enum VoiceConnectionState { disconnected, connecting, connected, error }

class VoiceWebSocketService extends ChangeNotifier {
  VoiceWebSocketService({required Future<String?> Function() tokenProvider})
      : _tokenProvider = tokenProvider;

  final Future<String?> Function() _tokenProvider;

  /// Goi khi server bao {"type":"transcript"} (STT thanh cong, Buoc 3).
  void Function(String text)? onTranscript;

  /// Audit "canh bao cau qua ngan — Whisper hallucinate" (2026-08-30) —
  /// goi khi message "transcript" kem "short_utterance_warning": true (xem
  /// docstring _SHORT_UTTERANCE_WARNING_MS trong voice_ws.py — benchmark
  /// THAT tren 45 cau xac nhan cau <=4 tu sai 100%, Confidence Gate KHONG
  /// bat duoc phan lon vi model "tu tin nhung sai"). Day la CANH BAO MEM
  /// (KHONG phai transcript_error) — transcript VAN duoc coi la hop le va
  /// AI VAN tra loi binh thuong (khac han transcript_error/transcript_
  /// low_confidence, ca 2 deu CHAN luot khong cho AI tra loi) — CALLER chi
  /// nen HIEN THI [message] de nguoi dung tu can nhac muc do tin tuong ket
  /// qua, KHONG duoc chan/huy luot.
  void Function(String message)? onShortUtteranceWarning;

  /// Goi khi server bao {"type":"transcript_error"} (STT that bai/audio
  /// khong ro tieng noi, Buoc 3) — client nen bao user noi lai.
  void Function(String message)? onTranscriptError;

  /// Goi khi server bao {"type":"transcript_low_confidence"} (Whisper
  /// Confidence Gate, 2026-08-15 — xem docstring app/api/v1/voice_ws.py)
  /// — CO nghe duoc text nhung KHONG chac chan (avg_logprob/
  /// compression_ratio vuot nguong). Backend KHONG goi AI cho luot nay —
  /// CALLER nen phat lai [message] qua TTS (giong phan ung nguoi that xin
  /// noi lai) roi quay ve trang thai lang nghe, KHONG coi [text] la cau
  /// tra loi dang tin cay de xu ly tiep.
  void Function(String text, String message)? onTranscriptLowConfidence;

  /// Goi khi server bao {"type":"ai_text_response_chunk"} (AI streaming,
  /// Buoc 4b) — moi lan goi la 1 doan delta text moi (isFinal=false), lan
  /// cuoi cung (isFinal=true) text LUON rong, chi de danh dau da het
  /// stream. CALLER tu quyet dinh lam gi (vd don vao SentenceAccumulator
  /// roi goi CompanionVoiceController.appendStreamingSentence()).
  void Function(String text, bool isFinal)? onAiTextResponseChunk;

  /// Goi khi server bao {"type":"ai_text_response_error"} (AI khong sinh
  /// duoc chunk nao ngay tu dau).
  void Function(String message)? onAiTextResponseError;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _manuallyDisconnected = true;

  VoiceConnectionState _state = VoiceConnectionState.disconnected;
  VoiceConnectionState get state => _state;
  bool get isConnected => _state == VoiceConnectionState.connected;

  // Retry don gian: tang dan theo so lan (1s, 2s, 3s...), gioi han 10s —
  // KHONG can thuat toan backoff phuc tap o buoc nay (yeu cau "retry don
  // gian, khong can phuc tap").
  static const _baseRetryDelay = Duration(seconds: 1);
  static const _maxRetryDelay = Duration(seconds: 10);

  void _setState(VoiceConnectionState s) {
    if (_state == s) return;
    _state = s;
    debugPrint('[VoiceWebSocketService] trang thai ket noi -> $s');
    notifyListeners();
  }

  /// Mo ket noi (va tu dong thu lai neu that bai/mat ket noi sau do, cho
  /// toi khi disconnect() duoc goi ro rang).
  Future<void> connect() async {
    _manuallyDisconnected = false;
    _retryTimer?.cancel();
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_manuallyDisconnected) return;
    _setState(VoiceConnectionState.connecting);

    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      debugPrint('[VoiceWebSocketService] khong co access token — dung ket noi');
      _setState(VoiceConnectionState.error);
      return;
    }

    final wsBase = ApiConstants.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/ws/voice?token=$token');

    try {
      debugPrint('[VoiceWebSocketService] dang ket noi toi ${uri.replace(query: 'token=***')}');
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _retryAttempt = 0;
      _setState(VoiceConnectionState.connected);

      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: _onError,
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[VoiceWebSocketService] loi khi ket noi: $e');
      _setState(VoiceConnectionState.error);
      _scheduleRetry();
    }
  }

  void _onMessage(dynamic raw) => handleRawMessageForTesting(raw as String);

  /// Xu ly 1 message JSON tho — TACH RIENG khoi listener that de test
  /// duoc bang cach "gia lap" 1 message den ma KHONG can mo ket noi
  /// WebSocket that (dung @visibleForTesting, khong goi tu code san xuat
  /// ngoai file nay/test).
  @visibleForTesting
  void handleRawMessageForTesting(String raw) {
    debugPrint('[VoiceWebSocketService] nhan message: $raw');
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[VoiceWebSocketService] khong parse duoc JSON: $e');
      return;
    }
    switch (data['type']) {
      case 'pong':
        debugPrint('[VoiceWebSocketService] pong nhan duoc — ket noi con song');
        break;
      case 'error':
        debugPrint('[VoiceWebSocketService] server bao loi: ${data['message']}');
        break;
      case 'transcript':
        final text = data['text'] as String? ?? '';
        debugPrint('[VoiceWebSocketService] transcript: $text');
        onTranscript?.call(text);
        if (data['short_utterance_warning'] == true) {
          final warningMessage = data['short_utterance_warning_message'] as String? ?? '';
          debugPrint('[VoiceWebSocketService] short_utterance_warning: $warningMessage');
          if (warningMessage.isNotEmpty) onShortUtteranceWarning?.call(warningMessage);
        }
        break;
      case 'transcript_error':
        final message = data['message'] as String? ?? 'Không nhận diện được giọng nói';
        debugPrint('[VoiceWebSocketService] transcript_error: $message');
        onTranscriptError?.call(message);
        break;
      case 'transcript_low_confidence':
        final text = data['text'] as String? ?? '';
        final message = data['message'] as String? ?? 'Mình nghe chưa rõ lắm, bạn nói lại được không?';
        debugPrint('[VoiceWebSocketService] transcript_low_confidence: text=$text message=$message');
        onTranscriptLowConfidence?.call(text, message);
        break;
      case 'ai_text_response_chunk':
        final text = data['text'] as String? ?? '';
        final isFinal = data['is_final'] as bool? ?? false;
        debugPrint('[VoiceWebSocketService] ai_text_response_chunk: $text (is_final=$isFinal)');
        onAiTextResponseChunk?.call(text, isFinal);
        break;
      case 'ai_text_response_error':
        final message = data['message'] as String? ?? 'Không tạo được câu trả lời';
        debugPrint('[VoiceWebSocketService] ai_text_response_error: $message');
        onAiTextResponseError?.call(message);
        break;
      // audio_received/audio_chunk-related server messages (Buoc 2) CHUA
      // can xu ly rieng o Flutter — server tu quan ly buffer, Flutter chi
      // CAN GUI audio_chunk/audio_end (se noi day khi VAD that duoc noi
      // vao WebSocket, ngoai pham vi Buoc 4a).
      default:
        debugPrint('[VoiceWebSocketService] message type khong xac dinh: ${data['type']}');
    }
  }

  void _onDisconnected() {
    debugPrint('[VoiceWebSocketService] ket noi da dong (server hoac mang)');
    _subscription = null;
    _channel = null;
    if (_manuallyDisconnected) {
      _setState(VoiceConnectionState.disconnected);
      return;
    }
    _setState(VoiceConnectionState.disconnected);
    _scheduleRetry();
  }

  void _onError(dynamic error) {
    debugPrint('[VoiceWebSocketService] loi tren luong WebSocket: $error');
    _setState(VoiceConnectionState.error);
    if (!_manuallyDisconnected) _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_manuallyDisconnected) return;
    _retryTimer?.cancel();
    _retryAttempt++;
    final seconds = (_baseRetryDelay.inSeconds * _retryAttempt).clamp(1, _maxRetryDelay.inSeconds);
    final delay = Duration(seconds: seconds);
    debugPrint('[VoiceWebSocketService] se thu ket noi lai sau ${delay.inSeconds}s (lan thu $_retryAttempt)');
    _retryTimer = Timer(delay, _connectInternal);
  }

  /// Gui {"type": "ping"} — dung de kiem tra thu cong o buoc nay (chua co
  /// UI, goi truc tiep tu code/console khi can).
  void sendPing() {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('[VoiceWebSocketService] chua ket noi — khong the gui ping');
      return;
    }
    debugPrint('[VoiceWebSocketService] gui ping');
    channel.sink.add(jsonEncode({'type': 'ping'}));
  }

  /// Lop 6 (2026-08-15) — Gui {"type": "audio_chunk", "data": "<base64>"}
  /// (giao thuc Buoc 2) — dung boi man hinh Voice that de gui audio da
  /// ghi tu mic (qua VoiceMicRecorder) sau khi VoiceActivityDetector phat
  /// hien ket thuc 1 luot noi.
  void sendAudioChunk(String audioBase64) {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('[VoiceWebSocketService] chua ket noi — khong the gui audio_chunk');
      return;
    }
    channel.sink.add(jsonEncode({'type': 'audio_chunk', 'data': audioBase64}));
  }

  /// Lop 6 (2026-08-15) — Gui {"type": "audio_end"} (giao thuc Buoc 2),
  /// bao server ghep buffer va bat dau STT.
  ///
  /// Buoc C (2026-08-20) — kem theo [systemPrompt]/[learningMode] THAT
  /// (do VoiceChatScreen xay qua CompanionPersonalityEngine.buildSystemPromptV2,
  /// dung chung engine voi Chat) de backend dung DUNG lua chon cua user
  /// thay vi prompt/mode co dinh — xem docstring app/api/v1/voice_ws.py.
  void sendAudioEnd({String? systemPrompt, String? learningMode}) {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('[VoiceWebSocketService] chua ket noi — khong the gui audio_end');
      return;
    }
    debugPrint('[VoiceWebSocketService] gui audio_end (learningMode=$learningMode)');
    channel.sink.add(jsonEncode({
      'type': 'audio_end',
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (learningMode != null) 'learning_mode': learningMode,
    }));
  }

  /// Audit "Go chu fallback" (2026-08-30) — Gui {"type": "text_input",
  /// "text": "...", "system_prompt": "...", "learning_mode": "..."} —
  /// dung khi user go chu thay vi noi (fallback cho gioi han that cua STT
  /// voi cau ngan tron Viet-Trung chua hu tu ngu phap, xem docstring
  /// app/api/v1/voice_ws.py). Backend BO QUA HOAN TOAN Whisper/Gate cho
  /// duong nay, di THANG vao CUNG 1 ham xu ly AI voi audio_end
  /// (_run_ai_turn) — cung dinh dang system_prompt/learning_mode voi
  /// sendAudioEnd() o tren, CHI khac field 'text' thay vi phai doi qua
  /// audio_chunk/audio_end.
  void sendTextInput(String text, {String? systemPrompt, String? learningMode}) {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('[VoiceWebSocketService] chua ket noi — khong the gui text_input');
      return;
    }
    debugPrint('[VoiceWebSocketService] gui text_input (go chu, learningMode=$learningMode)');
    channel.sink.add(jsonEncode({
      'type': 'text_input',
      'text': text,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      if (learningMode != null) 'learning_mode': learningMode,
    }));
  }

  /// Lop 5 (2026-08-15) — Gui {"type": "interrupt"} — goi khi VAD (Lop 1)
  /// phat hien user BAT DAU NOI trong luc AI van dang streaming cau tra
  /// loi, de backend DUNG GUI TIEP cac chunk con lai (xem docstring
  /// app/api/v1/voice_ws.py, phan Lop 5). CALLER (orchestrator/man hinh)
  /// van PHAI tu goi CompanionVoiceController.stopSpeaking() NGAY LAP TUC
  /// O PHIA CLIENT — KHONG cho toi khi co phan hoi tu server (do tre
  /// mang round-trip la khong can thiet cho hanh dong CUC BO nhu dung
  /// phat audio dang co san trong loa).
  void sendInterrupt() {
    final channel = _channel;
    if (!isConnected || channel == null) {
      debugPrint('[VoiceWebSocketService] chua ket noi — khong the gui interrupt');
      return;
    }
    debugPrint('[VoiceWebSocketService] gui interrupt');
    channel.sink.add(jsonEncode({'type': 'interrupt'}));
  }

  /// Ngat ket noi CHU DINH — sau loi goi nay se KHONG tu dong thu lai nua
  /// cho toi khi connect() duoc goi lai.
  void disconnect() {
    _manuallyDisconnected = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setState(VoiceConnectionState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
