import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:chinesemate/core/constants/api_constants.dart';
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
        '${ApiConstants.baseUrl}/translate/voice',
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

  // ============================================================
  // Buoc 4b (2026-08-15) — PHAT AM THANH STREAMING (Voice pipeline WS
  // moi), THEM MOI hoan toan, KHONG dong vao speak()/_speakSegments() o
  // tren (giu 100% khong doi cho nut "Nghe" hien co, 156+ test lien quan
  // — muc dich Buoc nay la MO RONG, khong phai sua lai logic cu).
  //
  // Ly do CAN 1 co che rieng, KHONG the goi speak() nhieu lan lien tiep
  // (1 lan/cau) nhu ban dau tuong: dong dau tien cua speak() la
  // `if (_isSpeaking) stopSpeaking();` — day CHINH LA co che Interrupt
  // (goi speak() lan 2 trong khi lan 1 con dang phat se CAT NGANG lan 1).
  // Neu dung nguyen speak() cho tung cau khi stream, cau 2 se CAT NGANG
  // cau 1 dang phat thay vi noi tiep sau — sai hoan toan tinh than
  // "phat lien tuc tung cau" ma streaming can.
  //
  // Thiet ke: dung 1 CHUOI Future (`_streamingChain`, noi tiep bang
  // .then()) thay vi 1 hang doi/con tro tuong minh — moi cau moi duoc
  // THEM VAO CUOI chuoi, dam bao chay TUAN TU (khong chong cheo, khong
  // cat ngang) du cau truoc do van dang fetch/phat khi cau moi den. Tai
  // su dung CHINH _fetchWithRetry()/_audioPlayer/webPlayAudio va CHINH
  // _segmenter (khong tao logic segment/fetch moi). Dung CHUNG bien
  // `_speakSession`/`_isSpeaking`/`stopSpeaking()` voi speak() — goi
  // stopSpeaking() giua 1 phien streaming dang phat VAN hoat dong dung
  // y het Interrupt (Lop 5 se dung lai chinh co che nay, khong viet lai).
  //
  // GIOI HAN DA BIET (ghi ro, khong che giau): KHONG prefetch cheo cau
  // (khac speak(), von prefetch segment N+1 trong luc segment N dang
  // phat) — moi cau streaming bat dau fetch audio CHI SAU KHI cau truoc
  // phat xong. Chap nhan duoc o buoc kiem chung ky thuat nay vi thoi
  // gian AI sinh text (giua 2 cau) thuong dai hon nhieu so voi 1 khoang
  // trang nho giua 2 lan fetch — neu do luong thuc te (yeu cau Buoc 4b)
  // cho thay day la nut that dang ke, se toi uu them o buoc sau.
  // ============================================================
  int? _streamingSession;
  Future<void>? _streamingChain;
  Stopwatch? _streamingStopwatch;
  Duration? _streamingTimeToFirstAudio;
  int _streamingSegmentCounter = 0;

  /// Do tre tu luc startStreamingSpeak() toi khi mieng audio DAU TIEN bat
  /// dau phat — doc SAU KHI phien streaming da hoan tat (finishStreamingSpeak
  /// + het hang doi) de so sanh voi TtsPlaybackResult.timeToFirstAudio cua
  /// speak() (Buoc 4a).
  Duration? get lastStreamingTimeToFirstAudio => _streamingTimeToFirstAudio;

  /// Bat dau 1 phien phat STREAMING moi — goi 1 LAN duy nhat truoc khi
  /// them cau dau tien qua appendStreamingSentence(). Neu dang co am
  /// thanh khac phat (speak() thuong hoac phien streaming truoc), NGAT
  /// truoc (dung chung stopSpeaking(), giong dung tinh than speak()).
  void startStreamingSpeak({required String aiGender}) {
    if (_disposed) return;
    if (_isSpeaking) stopSpeaking();
    _isSpeaking = true;
    _safeNotify();
    _streamingSession = ++_speakSession;
    _streamingChain = Future.value();
    _streamingStopwatch = Stopwatch()..start();
    _streamingTimeToFirstAudio = null;
    _streamingSegmentCounter = 0;
  }

  /// Khoang dung NGAN giua 2 segment lien tiep (Audit "Speech Naturalizer",
  /// 2026-08-24, muc C — "Segment + pause") — CHI ap dung cho duong
  /// streaming nay (Voice), KHONG dong vao _speakSegments()/speak() (nut
  /// "Nghe" cua Chat giu nguyen 100%). Ly do dat o CLIENT (khong phai
  /// SSML <break>): moi segment la 1 file audio DOC LAP tu 1 lan goi TTS
  /// rieng — SSML break chi co tac dung TRONG 1 lan goi, khong noi duoc
  /// giua 2 file, nen day la cach DUY NHAT tao khoang lang giua segment.
  static const _interSegmentPause = Duration(milliseconds: 180);

  /// Them 1 CAU DA XAC DINH XONG (co dau cau ket thuc, do CALLER tu gom
  /// tu cac chunk text — xem VoiceWebSocketService/orchestrator) vao CUOI
  /// hang doi dang phat. KHONG cat ngang cau dang phat truoc do — chi noi
  /// tiep sau. An toan de goi NHIEU LAN lien tiep ngay ca khi cau truoc
  /// van dang fetch/phat (moi lan chi noi vao CUOI chuoi).
  ///
  /// mood (Audit "Speech Naturalizer", 2026-08-24, OPTIONAL — mac dinh
  /// 'neutral'): caller (voice_chat_screen.dart) da boc tag [MOOD:...] tu
  /// CHINH cau nay (qua mood_tag_parser.dart) TRUOC khi goi ham nay —
  /// ham nay CHI nhan gia tri da chuan hoa san, khong tu parse gi them.
  void appendStreamingSentence(String sentenceText, {required String aiGender, String mood = 'neutral'}) {
    if (_disposed) return;
    final session = _streamingSession;
    if (session == null) return; // chua goi startStreamingSpeak()
    final ttsText = _cleanForTts(sentenceText);
    if (ttsText.isEmpty) return;
    final segments = _segmenter.segment(ttsText);
    if (segments.isEmpty) return;

    _streamingChain = (_streamingChain ?? Future.value()).then((_) async {
      for (final seg in segments) {
        if (_disposed || session != _speakSession) return; // bi interrupt hoac dispose
        final idx = _streamingSegmentCounter++;
        // Pause TRUOC segment (tru segment DAU TIEN cua CA phien, idx==0)
        // — KHONG phai SAU moi segment: tranh 1 khoang lang thua vo nghia
        // sau segment CUOI CUNG (truoc khi finishStreamingSpeak() danh dau
        // ket thuc), chi tao nhip nghi GIUA 2 segment/cau lien tiep — dung
        // dung tinh than "Segment + pause" (muc C), khong lam cham thoi
        // diem ket thuc mot cach vo ich.
        if (idx > 0) {
          if (_disposed || session != _speakSession) return;
          await Future.delayed(_interSegmentPause);
        }
        final bytes = await _fetchWithRetry(seg, aiGender, idx, mood: mood);
        if (_disposed || session != _speakSession) return;
        if (bytes == null) continue; // segment loi — bo qua, giong _speakSegments
        _streamingTimeToFirstAudio ??= _streamingStopwatch?.elapsed;
        if (_audioPlayer != null) {
          await _audioPlayer!(bytes);
        } else {
          await webPlayAudio(base64Encode(bytes));
        }
      }
    });
  }

  /// Bao hieu KHONG con cau nao nua se den (AI da gui is_final=true).
  /// Sau khi hang doi hien tai phat het, phien tu dong ket thuc
  /// (_isSpeaking=false), giong dung thoi diem speak() ket thuc binh
  /// thuong (khong bi interrupt).
  void finishStreamingSpeak() {
    if (_disposed) return;
    final session = _streamingSession;
    if (session == null) return;
    _streamingChain = (_streamingChain ?? Future.value()).then((_) {
      if (_disposed || session != _speakSession) return;
      _isSpeaking = false;
      _streamingStopwatch?.stop();
      _safeNotify();
    });
  }

  /// mood (Audit "Speech Naturalizer", 2026-08-24, OPTIONAL — mac dinh
  /// 'neutral', giu NGUYEN hanh vi cu cho nut "Nghe"/speak() vi cac call
  /// site do KHONG truyen mood): chi appendStreamingSentence() (Voice) moi
  /// truyen gia tri that. Da them vao cache key vi CUNG 1 text+lang nhung
  /// khac mood se cho ra audio SSML khac nhau — khong duoc dung nham cache.
  Future<List<int>?> _fetchSegmentAudio(TtsSegment segment, String aiGender, {String mood = 'neutral'}) {
    final key = '${segment.lang}_${segment.isPinyin}_${mood}_${segment.text}';
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
          bytes = await _defaultTtsFetch(segment.text, segment.lang, aiGender, token, mood: mood);
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
    String text, String lang, String gender, String token, {String mood = 'neutral'}
  ) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.post(
        '${ApiConstants.baseUrl}/translate/tts-mixed',
        data: {
          'text': text, 'gender': gender, 'lang': lang,
          // 'neutral' KHONG gui truong mood (giu request giong het truoc
          // day cho nut "Nghe") — backend cung coi thieu truong = neutral,
          // nhung khong gui gi khi khong can van la lua chon an toan hon.
          if (mood != 'neutral') 'mood': mood,
        },
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
  Future<List<int>?> _fetchWithRetry(TtsSegment segment, String aiGender, int index, {String mood = 'neutral'}) async {
    final first = await _fetchSegmentAudio(segment, aiGender, mood: mood);
    if (first != null) return first;
    debugPrint(
      '[CompanionVoiceController] TTS segment #$index (${segment.lang}'
      '${segment.isPinyin ? "/pinyin" : ""}) that bai lan 1, thu lai...',
    );
    final retry = await _fetchSegmentAudio(segment, aiGender, mood: mood);
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
