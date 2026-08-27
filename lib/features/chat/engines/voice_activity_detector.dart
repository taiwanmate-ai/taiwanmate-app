/// VoiceActivityDetector — Phase 2 Voice, Lop 1 (2026-08-15).
///
/// Ham thuan (pure state machine): nhan gia tri BIEN DO (dB) tai 1 thoi
/// diem, tra ve su kien chuyen trang thai (bat dau noi / ket thuc luot
/// noi) neu co, KHONG phu thuoc BuildContext/mic that/WebSocket — de test
/// duoc bang cach gia lap chuoi gia tri bien do (khong can mic that),
/// dung tinh than cac lop pure-function da co san trong app nay
/// (CompanionLearningEngine, MultilingualTtsSegmenter).
///
/// NANG CAP (2026-08-15, chong Whisper hallucination tren audio gan-
/// silence do VAD kich hoat nham — xem bao cao dieu tra Phase 1): BAN
/// DAU class nay chi so sanh 1 gia tri dB tuc thoi voi 1 nguong CO DINH
/// -35dB. Thay bang:
///   - A1 Adaptive noise floor: 500ms dau moi phien (khop initial grace
///     period cu) dung de LAY MAU nen — KHONG danh gia speech trong luc
///     nay — tinh median cua cac mau do lam noise floor. Nguong bat dau
///     noi = noiseFloor + startMarginDb (co CLAMP boi
///     minAbsoluteStartThresholdDb — an toan cho phong that yen tinh,
///     tranh nguong qua nhay).
///   - A4 Hysteresis: nguong DUNG (stopThreshold) THAP HON nguong BAT
///     DAU (startThreshold) dung `startMarginDb - stopMarginDb` dB — de
///     mot dip am luong nho tu nhien giua cau KHONG bi hieu la ket thuc
///     noi (khac han truoc day dung CHUNG 1 nguong cho ca 2 chieu).
///   - A3 Consecutive frames: can >= minConsecutiveSpeechFrames frame
///     LIEN TIEP vuot nguong BAT DAU moi duoc xac nhan speechStarted —
///     1 spike don le (tieng gat/click) KHONG du.
///   - A2 Speech frame ratio: THEM 1 dieu kien nua — trong `frameRatioWindow`
///     frame GAN NHAT, ti le frame vuot nguong phai >= minSpeechFrameRatio
///     — bat tay voi consecutive-frame de loc bot truong hop 1 chuoi
///     ngan vua du dai nhung nam giua nen deu la nhieu/im lang (frame
///     GAN NHAT du dieu kien nhung LICH SU GAN DAY van chu yeu la im
///     lang).
///
/// GIOI HAN KY THUAT DA XAC NHAN (khong che giau): package `record` CHI
/// cung cap 1 gia tri dB PEAK moi lan poll onAmplitudeChanged(interval)
/// (xem VoiceMicRecorder) — KHONG phai RMS chuan, KHONG phai mang PCM
/// tho. "Frame" o day = 1 lan poll (VoiceChatScreen poll voi interval
/// NHO — xem _kAmplitudePollInterval trong voice_chat_screen.dart, khac
/// interval 200ms truoc day dung cho UI thong thuong) — la XAP XI hop ly
/// cho frame-level analysis, KHONG phai RMS-per-20ms-window dung nghia
/// audio-processing. Muon RMS that can doi sang AudioRecorder.startStream
/// (pcm16bits) — thay doi kien truc lon hon, ngoai pham vi buoc nay.
///
/// TAT CA nguong/thoi luong deu la CONSTRUCTOR PARAM voi gia tri MAC DINH
/// — CAC GIA TRI MAC DINH LA UOC LUONG HOP LY BAN DAU, CHUA duoc xac nhan
/// bang du lieu test thuc te tren dien rong (dung tinh than "khong tu y
/// chot gia tri production truoc khi kiem tra test thuc te" — se tinh
/// chinh sau khi co du lieu tu structured logging, Phase 6).
///
/// silenceDuration GIU NGUYEN 1500ms (KHONG doi mu quang xuong 700-
/// 1200ms nhu de xuat trong tai lieu ke hoach — LY DO: khong co du lieu
/// thuc te ve pattern pause tu nhien cua user de chon so cu the co can
/// cu, giam bua co the cat mat pause giua cau that. Van CONFIGURABLE de
/// tune sau khi co du lieu logging that.
library;

import 'dart:collection';
import 'dart:math' as math;

enum VadState { idle, speaking, trailingSilence }

enum VadEvent { speechStarted, speechEnded }

class VoiceActivityDetector {
  VoiceActivityDetector({
    this.noiseFloorCalibrationDuration = const Duration(milliseconds: 500),
    this.startMarginDb = 15.0,
    this.stopMarginDb = 8.0,
    this.minAbsoluteStartThresholdDb = -50.0,
    this.minConsecutiveSpeechFrames = 3,
    this.frameRatioWindow = 6,
    this.minSpeechFrameRatio = 0.5,
    this.silenceDuration = const Duration(milliseconds: 1500),
    this.initialGracePeriod = const Duration(milliseconds: 500),
    this.fixedSpeechThresholdDb,
  })  : assert(stopMarginDb <= startMarginDb, 'stopMarginDb phai <= startMarginDb de dam bao hysteresis dung chieu'),
        assert(minConsecutiveSpeechFrames >= 1),
        assert(frameRatioWindow >= 1),
        assert(minSpeechFrameRatio >= 0 && minSpeechFrameRatio <= 1);

  /// Khoang thoi gian dau moi phien dung de LAY MAU nen tinh noise floor
  /// — KHONG danh gia speech trong luc nay. Nen <= initialGracePeriod
  /// (mau lay xong truoc khi bat dau danh gia).
  final Duration noiseFloorCalibrationDuration;

  /// So dB CONG THEM vao noise floor de ra nguong BAT DAU noi.
  final double startMarginDb;

  /// So dB CONG THEM vao noise floor de ra nguong DUNG noi (PHAI <=
  /// startMarginDb — day chinh la hysteresis, nguong dung LUON <= nguong
  /// bat dau, tranh 1 dip am luong nho giua cau bi hieu nham la ket
  /// thuc).
  final double stopMarginDb;

  /// San AN TOAN tuyet doi cho nguong bat dau — DU noise floor tinh ra
  /// qua thap (phong qua yen tinh), nguong bat dau KHONG duoc thap hon
  /// gia tri nay (tranh qua nhay, bat ca tieng dong ho/quat rat nho).
  final double minAbsoluteStartThresholdDb;

  /// So frame LIEN TIEP phai vuot nguong bat dau truoc khi xac nhan
  /// speechStarted — chan 1 spike don le (tieng gat/click chuot).
  final int minConsecutiveSpeechFrames;

  /// Kich thuoc cua so (so frame gan nhat) de tinh speech frame ratio.
  final int frameRatioWindow;

  /// Ti le toi thieu frame vuot nguong trong frameRatioWindow de duoc
  /// tinh la co speech that su (bo sung cho minConsecutiveSpeechFrames).
  final double minSpeechFrameRatio;

  /// Im lang lien tuc BAO LAU (sau khi da phat hien noi) thi coi la ket
  /// thuc luot noi.
  final Duration silenceDuration;

  /// Bo qua DANH GIA SPEECH trong khoang thoi gian dau sau start() —
  /// tranh kich hoat gia do tieng on/click luc vua mo mic. PHAI >=
  /// noiseFloorCalibrationDuration (mau can lay xong truoc khi danh gia).
  final Duration initialGracePeriod;

  /// ESCAPE HATCH (mac dinh null = dung adaptive noise floor): neu duoc
  /// dat, BO QUA hoan toan tinh toan noise floor, dung dung 1 gia tri dB
  /// co dinh nay lam nguong bat dau (van co hysteresis: nguong dung =
  /// fixedSpeechThresholdDb - (startMarginDb - stopMarginDb)). Dung de
  /// so sanh A/B voi che do adaptive, hoac fallback neu adaptive gay van
  /// de o 1 nhom thiet bi cu the — KHONG phai huong di mac dinh.
  final double? fixedSpeechThresholdDb;

  VadState _state = VadState.idle;
  VadState get state => _state;

  DateTime? _sessionStartedAt;
  DateTime? _silenceStartedAt;
  double? _noiseFloorDb;
  final List<double> _calibrationSamples = [];
  final Queue<bool> _recentFrames = Queue<bool>();
  int _consecutiveAboveStart = 0;

  /// Noise floor da tinh duoc cho phien hien tai — null neu chua calibrate
  /// xong (con trong noiseFloorCalibrationDuration) hoac chua start().
  /// Expose de logging/debug (Phase 6), KHONG anh huong logic.
  double? get noiseFloorDb => _noiseFloorDb;

  double? get currentStartThresholdDb {
    if (fixedSpeechThresholdDb != null) return fixedSpeechThresholdDb;
    final floor = _noiseFloorDb;
    if (floor == null) return null;
    return math.max(floor + startMarginDb, minAbsoluteStartThresholdDb);
  }

  double? get currentStopThresholdDb {
    final start = currentStartThresholdDb;
    if (start == null) return null;
    return start - (startMarginDb - stopMarginDb);
  }

  /// Bat dau 1 phien lang nghe MOI — reset toan bo trang thai noi bo
  /// (bao gom noise floor — tinh lai tu dau moi phien, KHONG giu qua cac
  /// lan start() khac nhau vi moi truong xung quanh co the da doi).
  void start(DateTime now) {
    _state = VadState.idle;
    _sessionStartedAt = now;
    _silenceStartedAt = null;
    _noiseFloorDb = null;
    _calibrationSamples.clear();
    _recentFrames.clear();
    _consecutiveAboveStart = 0;
  }

  /// Dat lai ve trang thai chua khoi tao (chua goi start()) — dung khi
  /// dong hoan toan phien VAD (vd dong WebSocket).
  void reset() {
    _state = VadState.idle;
    _sessionStartedAt = null;
    _silenceStartedAt = null;
    _noiseFloorDb = null;
    _calibrationSamples.clear();
    _recentFrames.clear();
    _consecutiveAboveStart = 0;
  }

  void _calibrateNoiseFloorIfNeeded() {
    if (_noiseFloorDb != null) return;
    if (_calibrationSamples.isEmpty) {
      // Khong lay duoc mau nao (vd start() va processAmplitude() dau
      // tien den ngay SAU khi da qua calibration window) — fallback AN
      // TOAN: coi nhu noise floor thap, de startThreshold roi ve dung
      // minAbsoluteStartThresholdDb qua phep clamp.
      _noiseFloorDb = minAbsoluteStartThresholdDb - startMarginDb;
      return;
    }
    final sorted = List<double>.from(_calibrationSamples)..sort();
    // Median — ben vung hon mean truoc 1-2 mau bat thuong (vd 1 tieng
    // click luc vua mo mic) trong so mau calibration.
    final mid = sorted.length ~/ 2;
    _noiseFloorDb = sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  /// Nhan 1 gia tri bien do (dB) tai thoi diem [now]. Tra ve VadEvent NEU
  /// co chuyen trang thai can xu ly o tang goi (vd bat dau gui audio_chunk,
  /// gui audio_end) — null neu khong co gi thay doi.
  VadEvent? processAmplitude(double amplitudeDb, DateTime now) {
    final sessionStart = _sessionStartedAt;
    if (sessionStart == null) return null; // chua goi start()

    final elapsed = now.difference(sessionStart);

    if (fixedSpeechThresholdDb == null && elapsed < noiseFloorCalibrationDuration) {
      _calibrationSamples.add(amplitudeDb);
      return null;
    }
    if (fixedSpeechThresholdDb == null) {
      _calibrateNoiseFloorIfNeeded();
    }

    if (elapsed < initialGracePeriod) return null;

    final startThreshold = currentStartThresholdDb!;
    final stopThreshold = currentStopThresholdDb!;

    final isAboveStart = amplitudeDb > startThreshold;
    _recentFrames.addLast(isAboveStart);
    while (_recentFrames.length > frameRatioWindow) {
      _recentFrames.removeFirst();
    }

    if (_state == VadState.idle) {
      _consecutiveAboveStart = isAboveStart ? _consecutiveAboveStart + 1 : 0;
      if (_consecutiveAboveStart < minConsecutiveSpeechFrames) return null;
      final aboveCount = _recentFrames.where((f) => f).length;
      final frameRatio = aboveCount / _recentFrames.length;
      if (frameRatio < minSpeechFrameRatio) return null;

      _state = VadState.speaking;
      _silenceStartedAt = null;
      _consecutiveAboveStart = 0;
      return VadEvent.speechStarted;
    }

    // _state la speaking hoac trailingSilence — da tung phat hien noi
    // trong phien nay. Dung STOP threshold (thap hon, hysteresis) de xet
    // tiep tuc coi la dang noi.
    final isAboveStop = amplitudeDb > stopThreshold;
    if (isAboveStop) {
      _state = VadState.speaking;
      _silenceStartedAt = null;
      return null;
    }

    _silenceStartedAt ??= now;
    _state = VadState.trailingSilence;
    if (now.difference(_silenceStartedAt!) >= silenceDuration) {
      _state = VadState.idle;
      _silenceStartedAt = null;
      _consecutiveAboveStart = 0;
      return VadEvent.speechEnded;
    }
    return null;
  }
}
