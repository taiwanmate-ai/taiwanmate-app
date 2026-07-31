import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/features/chat/engines/language_order_guard.dart';

/// CompanionVoiceController — quan ly toan bo lifecycle ghi am/TTS cho
/// AI Companion. ChangeNotifier, KHONG dung BuildContext, KHONG doc
/// FlutterSecureStorage truc tiep (nhan tokenProvider tu ben ngoai).
/// Nguon su that duy nhat cho isListening/isProcessing/isSpeaking.
class CompanionVoiceController extends ChangeNotifier {
  CompanionVoiceController({
    required Future<String?> Function() tokenProvider,
  }) : _tokenProvider = tokenProvider;

  final Future<String?> Function() _tokenProvider;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String? _lastError;
  bool _disposed = false;
  int _speakSession = 0;

  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  String? get lastError => _lastError;

  static const _languageOrderGuard = LanguageOrderGuard();
  final Map<String, String> _audioCache = {};
  final Map<String, Future<String?>> _audioFetchInFlight = {};

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Bat dau nghe. Neu dang speaking, ngat TTS truoc (Interrupt).
  Future<void> startListening({
    required void Function(String transcript) onTranscript,
    required void Function(String error) onError,
  }) async {
    if (_disposed) return;
    if (_isSpeaking) {
      stopSpeaking();
    }
    _isListening = true;
    _lastError = null;
    _safeNotify();

    await webStartRecordingAutoStop(
      (audioBase64) async {
        if (_disposed) return;
        _isListening = false;
        _isProcessing = true;
        _safeNotify();
        await _transcribe(audioBase64, onTranscript, onError);
      },
      (error) {
        if (_disposed) return;
        _isListening = false;
        _lastError = error;
        _safeNotify();
        onError(error);
      },
    );
  }

  /// Nguoi dung bam dung tay. Chi goi webStopRecording — KHONG doi state
  /// o day. Chuyen sang processing xay ra trong callback onData (tren)
  /// khi du lieu am thanh thuc su ve, tranh nhay ve idle qua som.
  void stopListening() {
    if (_disposed) return;
    webStopRecording();
  }

  Future<void> _transcribe(
    String audioBase64,
    void Function(String) onTranscript,
    void Function(String) onError,
  ) async {
    try {
      final token = await _tokenProvider();
      if (_disposed) return;
      if (token == null || token.isEmpty) {
        _isProcessing = false;
        _lastError = 'Phiên đăng nhập đã hết hạn';
        _safeNotify();
        onError('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
        return;
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/voice',
        data: {'audio_base64': audioBase64, 'target_lang': 'vi'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (_disposed) return;
      _isProcessing = false;
      _safeNotify();
      onTranscript(response.data['transcript'] as String? ?? '');
    } catch (e) {
      if (_disposed) return;
      _isProcessing = false;
      _lastError = 'Lỗi xử lý giọng nói';
      _safeNotify();
      onError('Lỗi xử lý giọng nói. Thử lại nhé!');
    }
  }

  /// Phat TTS. Neu dang speaking, dung ngay truoc khi phat cai moi.
  Future<void> speak(
    String text, {
    required String aiGender,
    required String learningMode,
  }) async {
    if (_disposed) return;
    if (_isSpeaking) stopSpeaking();
    final ttsText = _cleanForTts(text);
    if (ttsText.isEmpty) return;
    final chunks = _splitTextForTts(ttsText);
    if (chunks.isEmpty) return;
    _isSpeaking = true;
    _safeNotify();
    final session = ++_speakSession;
    _speakChunks(text, chunks, 0, session, aiGender, learningMode);
  }

  void stopSpeaking() {
    _speakSession++; // vo hieu moi chunk dang cho
    _isSpeaking = false;
    _safeNotify();
    try {
      webStopAudio();
    } catch (e) {}
  }

  Future<String?> _fetchTtsBase64(
    String fullText, List<String> chunks, int index, String aiGender, String learningMode,
  ) {
    final key = '${fullText.hashCode}_$index';
    final cached = _audioCache[key];
    if (cached != null) return Future.value(cached);
    return _audioFetchInFlight.putIfAbsent(key, () async {
      try {
        final token = await _tokenProvider();
        if (token == null || token.isEmpty) return null;
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          responseType: ResponseType.bytes,
        ));
        final response = await dio.post(
          'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts-mixed',
          data: {'text': chunks[index], 'gender': aiGender, 'learning_mode': learningMode},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final b64 = base64Encode(response.data as List<int>);
        if (_audioCache.length > 60) _audioCache.clear();
        _audioCache[key] = b64;
        return b64;
      } catch (e) {
        return null;
      } finally {
        _audioFetchInFlight.remove(key);
      }
    });
  }

  Future<void> _speakChunks(
    String fullText, List<String> chunks, int index, int session, String aiGender, String learningMode,
  ) async {
    if (_disposed) return;
    if (session != _speakSession) return;
    if (index >= chunks.length) {
      _isSpeaking = false;
      _safeNotify();
      return;
    }
    try {
      final currentFuture = _fetchTtsBase64(fullText, chunks, index, aiGender, learningMode);
      if (index + 1 < chunks.length) {
        _fetchTtsBase64(fullText, chunks, index + 1, aiGender, learningMode);
      }
      final b64 = await currentFuture;
      if (_disposed || session != _speakSession) return;
      if (b64 == null) {
        _speakChunks(fullText, chunks, index + 1, session, aiGender, learningMode);
        return;
      }
      await webPlayAudio(b64);
      if (_disposed || session != _speakSession) return;
      _speakChunks(fullText, chunks, index + 1, session, aiGender, learningMode);
    } catch (e) {
      if (_disposed) return;
      if (session == _speakSession) {
        _speakChunks(fullText, chunks, index + 1, session, aiGender, learningMode);
      } else {
        _isSpeaking = false;
        _safeNotify();
      }
    }
  }

  String _cleanForTts(String text) {
    text = text.replaceAll(RegExp(r'\[NEW:([^\]]+)\]'), r'\1');
    text = text.replaceAll(RegExp(r'\([^)]*\)'), '');
    text = _languageOrderGuard.stripOrphanVietnameseForTts(text);
    text = text.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'\*+'), '');
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    return text.trim();
  }

  List<String> _splitTextForTts(String text) {
    final chunks = <String>[];
    final parts = text.split(RegExp(r'(?<=[。！？!?\n])'));
    String current = '';
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if ((current + trimmed).length > 100) {
        if (current.isNotEmpty) chunks.add(current.trim());
        current = trimmed;
      } else {
        current += trimmed;
      }
    }
    if (current.trim().isNotEmpty) chunks.add(current.trim());
    if (chunks.isEmpty && text.isNotEmpty) {
      for (int i = 0; i < text.length; i += 100) {
        chunks.add(text.substring(i, (i + 100).clamp(0, text.length)));
      }
    }
    return chunks;
  }

  @override
  void dispose() {
    _disposed = true;
    _speakSession++;
    webStopRecording();
    try {
      webStopAudio();
    } catch (e) {}
    super.dispose();
  }
}