import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/features/chat/engines/multilingual_tts_segmenter.dart';

/// Ket qua 1 lan speak() — dung de bao cao do tre (time-to-first-audio,
/// total playback time) va tinh day du (segment mong doi vs thuc phat)
/// theo yeu cau do luong cua FIX-TTS-02. KHONG anh huong hanh vi phat
/// audio — chi la du lieu quan sat duoc tra ve them.
class TtsPlaybackResult {
  const TtsPlaybackResult({
    required this.expectedSegments,
    required this.playedSegments,
    required this.failedSegments,
    required this.timeToFirstAudio,
    required this.totalPlaybackTime,
    required this.interrupted,
  });

  factory TtsPlaybackResult.empty() => const TtsPlaybackResult(
        expectedSegments: 0,
        playedSegments: 0,
        failedSegments: 0,
        timeToFirstAudio: null,
        totalPlaybackTime: Duration.zero,
        interrupted: false,
      );

  final int expectedSegments;
  final int playedSegments;
  final int failedSegments;
  final Duration? timeToFirstAudio;
  final Duration totalPlaybackTime;
  final bool interrupted;
}

/// CompanionVoiceController — quan ly toan bo lifecycle ghi am/TTS cho
/// AI Companion. ChangeNotifier, KHONG dung BuildContext, KHONG doc
/// FlutterSecureStorage truc tiep (nhan tokenProvider tu ben ngoai).
/// Nguon su that duy nhat cho isListening/isProcessing/isSpeaking.
///
/// FIX-TTS-02: dung chung MultilingualTtsSegmenter cho ca nut "Nghe" va
/// (sau nay) Voice Chat — KHONG tao logic tach ngon ngu rieng o noi khac.
class CompanionVoiceController extends ChangeNotifier {
  CompanionVoiceController({
    required Future<String?> Function() tokenProvider,
    Future<List<int>?> Function(String text, String lang, String gender, String token)?
        ttsFetcher,
    Future<bool> Function(List<int> audioBytes)? audioPlayer,
  })  : _tokenProvider = tokenProvider,
        _ttsFetcher = ttsFetcher,
        _audioPlayer = audioPlayer;

  final Future<String?> Function() _tokenProvider;
  final Future<List<int>?> Function(String text, String lang, String gender, String token)?
      _ttsFetcher;
  final Future<bool> Function(List<int> audioBytes)? _audioPlayer;

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

  static const _segmenter = MultilingualTtsSegmenter();
  final Map<String, List<int>> _audioCache = {};
  final Map<String, Future<List<int>?>> _audioFetchInFlight = {};

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
  /// Tach cau bang MultilingualTtsSegmenter (vi/zh-TW/en/pinyin), goi TTS
  /// dung giong cho tung segment, phat lien tuc theo dung thu tu (hang
  /// doi + prefetch 1 segment ke tiep trong luc segment hien tai dang
  /// phat, giu nguyen co che khong chong tieng/khong trung lap tu ban
  /// cu). Tra ve TtsPlaybackResult de do time-to-first-audio, total
  /// playback time, va so segment mong doi/thuc phat (FIX-TTS-02 muc
  /// 21-24) — khong bat buoc caller phai dung gia tri tra ve.
  Future<TtsPlaybackResult> speak(
    String text, {
    required String aiGender,
    required String learningMode,
  }) async {
    if (_disposed) return TtsPlaybackResult.empty();
    if (_isSpeaking) stopSpeaking();
    final ttsText = _cleanForTts(text);
    if (ttsText.isEmpty) return TtsPlaybackResult.empty();
    final segments = _segmenter.segment(ttsText);
    if (segments.isEmpty) return TtsPlaybackResult.empty();
    _isSpeaking = true;
    _safeNotify();
    final session = ++_speakSession;
    final stopwatch = Stopwatch()..start();
    return _speakSegments(segments, 0, session, aiGender, stopwatch, 0, 0, null);
  }

  void stopSpeaking() {
    _speakSession++; // vo hieu moi segment dang cho
    _isSpeaking = false;
    _safeNotify();
    try {
      webStopAudio();
    } catch (e) {}
  }

  Future<List<int>?> _fetchSegmentAudio(TtsSegment segment, String aiGender) {
    final key = '${segment.lang}_${segment.isPinyin}_${segment.text}';
    final cached = _audioCache[key];
    if (cached != null) return Future.value(cached);
    return _audioFetchInFlight.putIfAbsent(key, () async {
      try {
        final token = await _tokenProvider();
        if (token == null || token.isEmpty) return null;
        List<int>? bytes;
        if (_ttsFetcher != null) {
          bytes = await _ttsFetcher!(segment.text, segment.lang, aiGender, token);
        } else {
          bytes = await _defaultTtsFetch(segment.text, segment.lang, aiGender, token);
        }
        if (bytes == null || bytes.isEmpty) return null;
        if (_audioCache.length > 60) _audioCache.clear();
        _audioCache[key] = bytes;
        return bytes;
      } finally {
        _audioFetchInFlight.remove(key);
      }
    });
  }

  Future<List<int>?> _defaultTtsFetch(
    String text, String lang, String gender, String token,
  ) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts-mixed',
        data: {'text': text, 'gender': gender, 'lang': lang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data as List<int>;
    } catch (e) {
      return null;
    }
  }

  /// Goi 1 segment audio, co retry 1 lan neu that bai — KHONG duoc am
  /// tham bo qua ma khong log (yeu cau #9/#10 cua FIX-TTS-02). Backend
  /// (text_to_speech_segment) da tu fallback sang giong trung tinh neu
  /// giong dung ngon ngu loi; retry o day chi de bat loi mang tam thoi.
  Future<List<int>?> _fetchWithRetry(TtsSegment segment, String aiGender, int index) async {
    final first = await _fetchSegmentAudio(segment, aiGender);
    if (first != null) return first;
    debugPrint(
      '[CompanionVoiceController] TTS segment #$index (${segment.lang}'
      '${segment.isPinyin ? "/pinyin" : ""}) that bai lan 1, thu lai...',
    );
    final retry = await _fetchSegmentAudio(segment, aiGender);
    if (retry == null) {
      debugPrint(
        '[CompanionVoiceController] TTS segment #$index (${segment.lang}) '
        'that bai ca sau retry — BO QUA segment nay, cac segment khac van '
        'tiep tuc phat binh thuong. Text da mat audio: "${segment.text}"',
      );
    }
    return retry;
  }

  Future<TtsPlaybackResult> _speakSegments(
    List<TtsSegment> segments,
    int index,
    int session,
    String aiGender,
    Stopwatch stopwatch,
    int played,
    int failed,
    Duration? timeToFirstAudio,
  ) async {
    if (_disposed || session != _speakSession) {
      return TtsPlaybackResult(
        expectedSegments: segments.length,
        playedSegments: played,
        failedSegments: failed,
        timeToFirstAudio: timeToFirstAudio,
        totalPlaybackTime: stopwatch.elapsed,
        interrupted: true,
      );
    }
    if (index >= segments.length) {
      _isSpeaking = false;
      _safeNotify();
      stopwatch.stop();
      return TtsPlaybackResult(
        expectedSegments: segments.length,
        playedSegments: played,
        failedSegments: failed,
        timeToFirstAudio: timeToFirstAudio,
        totalPlaybackTime: stopwatch.elapsed,
        interrupted: false,
      );
    }
    try {
      final currentFuture = _fetchWithRetry(segments[index], aiGender, index);
      if (index + 1 < segments.length) {
        // Prefetch 1 segment ke tiep trong luc segment hien tai dang xu
        // ly — giu dung co che cu, tranh khoang lang giua 2 segment.
        _fetchWithRetry(segments[index + 1], aiGender, index + 1);
      }
      final bytes = await currentFuture;
      if (_disposed || session != _speakSession) {
        return TtsPlaybackResult(
          expectedSegments: segments.length,
          playedSegments: played,
          failedSegments: failed,
          timeToFirstAudio: timeToFirstAudio,
          totalPlaybackTime: stopwatch.elapsed,
          interrupted: true,
        );
      }
      if (bytes == null) {
        return _speakSegments(segments, index + 1, session, aiGender, stopwatch,
            played, failed + 1, timeToFirstAudio);
      }
      timeToFirstAudio ??= stopwatch.elapsed;
      if (_audioPlayer != null) {
        await _audioPlayer!(bytes);
      } else {
        await webPlayAudio(base64Encode(bytes));
      }
      if (_disposed || session != _speakSession) {
        return TtsPlaybackResult(
          expectedSegments: segments.length,
          playedSegments: played + 1,
          failedSegments: failed,
          timeToFirstAudio: timeToFirstAudio,
          totalPlaybackTime: stopwatch.elapsed,
          interrupted: true,
        );
      }
      return _speakSegments(segments, index + 1, session, aiGender, stopwatch,
          played + 1, failed, timeToFirstAudio);
    } catch (e) {
      if (_disposed) {
        return TtsPlaybackResult(
          expectedSegments: segments.length,
          playedSegments: played,
          failedSegments: failed,
          timeToFirstAudio: timeToFirstAudio,
          totalPlaybackTime: stopwatch.elapsed,
          interrupted: true,
        );
      }
      if (session == _speakSession) {
        debugPrint('[CompanionVoiceController] Loi khong mong doi o segment #$index: $e');
        return _speakSegments(segments, index + 1, session, aiGender, stopwatch,
            played, failed + 1, timeToFirstAudio);
      }
      _isSpeaking = false;
      _safeNotify();
      return TtsPlaybackResult(
        expectedSegments: segments.length,
        playedSegments: played,
        failedSegments: failed,
        timeToFirstAudio: timeToFirstAudio,
        totalPlaybackTime: stopwatch.elapsed,
        interrupted: true,
      );
    }
  }

  String _cleanForTts(String text) {
    text = text.replaceAll(RegExp(r'\[NEW:([^\]]+)\]'), r'\1');
    text = text.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '');
    text = text.replaceAll(RegExp(r'\*+'), '');
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    return text.trim();
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
