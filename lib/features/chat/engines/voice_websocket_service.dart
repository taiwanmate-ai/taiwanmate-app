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

  void _onMessage(dynamic raw) {
    debugPrint('[VoiceWebSocketService] nhan message: $raw');
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
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
