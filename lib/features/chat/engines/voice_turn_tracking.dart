/// Voice — theo doi LUOT noi (nut "Noi lai") + do do tre phia app (2026-10-12, Dot 1 muc 3-4).
///
/// Hai lop THUAN Dart (khong phu thuoc Flutter/WebSocket) de test duoc rieng, man hinh Voice chi noi day:
///  - [VoiceTurnState]: luot hien tai (turn_id server cap trong message "transcript"), co cho bam "Noi lai" khong, va dang
///    cho ack `turn_discarded` cua server (trong luc do PHAI bo qua cac ai_text_response_chunk con sot lai cua luot bi bo).
///  - [VoiceLatencyTracker]: cac moc tha nut -> nhan transcript -> nhan audio dau tien -> bat dau phat. Gui 1 bao cao
///    {"type":"client_latency",...} cho backend (log `[ws/voice][CLIENT_LATENCY]`) de tinh p50/p95 tren production.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';

class VoiceTurnState {
  int? _turnId;
  String _transcript = '';
  bool _fromMic = false;
  int _pendingDiscardAcks = 0;

  int? get turnId => _turnId;
  String get transcript => _transcript;

  /// Chi luot noi bang mic co turn_id (server moi) moi co nut "Noi lai" (luot go chu thi user tu go lai).
  bool get canRedo => _fromMic && _turnId != null && _transcript.isNotEmpty;

  /// True khi da gui discard_turn ma chua nhan `turn_discarded` — server co the van dang gui not chunk cua luot bi bo.
  bool get shouldIgnoreAiChunks => _pendingDiscardAcks > 0;

  void onTranscript(String text, int? turnId, {required bool fromMic}) {
    _transcript = text;
    _turnId = turnId;
    _fromMic = fromMic;
  }

  /// User bam "Noi lai". Tra ve turn_id can gui `discard_turn`, hoac null neu khong the (khong co luot / server cu khong gui turn_id).
  int? requestRedo() {
    if (!canRedo) return null;
    final id = _turnId!;
    _pendingDiscardAcks++;
    _turnId = null;
    _transcript = '';
    _fromMic = false;
    return id;
  }

  /// Server tra {"type":"turn_discarded"} (moi discard_turn deu duoc ack: in_flight / removed / unknown). Ack luon den TRUOC
  /// moi message cua luot ke tiep (server xu ly theo thu tu), nen dem don gian la du.
  void onDiscardAck() {
    if (_pendingDiscardAcks > 0) _pendingDiscardAcks--;
  }

  /// Ket thuc/huy phien (dung session, mat ket noi): bo moi trang thai, ke ca ack dang cho (ket noi moi se khong gui ack cu).
  void reset() {
    _turnId = null;
    _transcript = '';
    _fromMic = false;
    _pendingDiscardAcks = 0;
  }
}

class VoiceLatencyTracker {
  VoiceLatencyTracker({
    required this.platform,
    required this.sendReport,
    int Function()? nowMs,
    void Function(String line)? log,
  })  : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _log = log ?? ((l) => debugPrint(l));

  final String platform;

  /// Gui bao cao len backend (VoiceWebSocketService.sendClientLatency). Loi/ket noi dong thi bo qua im lang o ben goi.
  final void Function(Map<String, dynamic> report) sendReport;
  final int Function() _nowMs;
  final void Function(String line) _log;

  int? _release;
  int? _transcriptAt;
  int? _firstAudioAt;
  int? _playbackAt;
  int? _turnId;
  bool _active = false;

  bool get isActive => _active;
  bool get hasPlaybackStarted => _playbackAt != null;

  /// Moc 1: user THA nut mic (bat dau luot do do tre). Goi lai = bat dau luot moi (luot cu chua bao cao bi bo qua).
  void markRelease() {
    _release = _nowMs();
    _transcriptAt = _firstAudioAt = _playbackAt = null;
    _turnId = null;
    _active = true;
  }

  /// Moc 2: nhan transcript tu server.
  void markTranscript(int? turnId) {
    if (!_active || _transcriptAt != null) return;
    _transcriptAt = _nowMs();
    _turnId = turnId;
  }

  /// Moc 3: nhan audio DAU TIEN (byte TTS cua cau dau da ve tay app).
  void markFirstAudio() {
    if (!_active || _firstAudioAt != null) return;
    _firstAudioAt = _nowMs();
  }

  /// Moc 4: bat dau phat audio dau tien -> bao cao day du roi ket thuc luot do.
  void markPlaybackStart() {
    if (!_active || _playbackAt != null) return;
    _playbackAt = _nowMs();
    _emit();
  }

  /// Luot ket thuc ma KHONG toi duoc buoc phat (loi, "Noi lai", dung phien...): neu da co it nhat moc transcript thi van bao cao
  /// phan do duoc (cac moc con lai = null) de p50/p95 cua transcript khong bi lech; chua co gi thi bo.
  void abandon() {
    if (_active && _transcriptAt != null) _emit();
    _active = false;
  }

  Map<String, dynamic> buildReport() {
    int? d(int? t) => (t != null && _release != null) ? t - _release! : null;
    return {
      'type': 'client_latency',
      'turn_id': _turnId,
      'release_to_transcript_ms': d(_transcriptAt),
      'release_to_first_audio_ms': d(_firstAudioAt),
      'release_to_playback_ms': d(_playbackAt),
      'platform': platform,
    };
  }

  void _emit() {
    final report = buildReport();
    _active = false;
    _log('[VOICE_LATENCY] ${jsonEncode(report)}');
    try {
      sendReport(report);
    } catch (_) {}
  }
}

/// Noi [VoiceTurnState] + [VoiceLatencyTracker] voi hanh dong that cua nut "Noi lai" (man hinh Voice chi them phan UI).
class VoiceTurnCoordinator {
  VoiceTurnCoordinator({
    required this.state,
    required this.latency,
    required this.stopSpeaking,
    required this.sendDiscardTurn,
  });

  final VoiceTurnState state;
  final VoiceLatencyTracker latency;
  final VoidCallback stopSpeaking;
  final void Function(int turnId) sendDiscardTurn;

  /// Tra ve true neu da bo luot (va gui discard_turn); false neu khong co luot nao bo duoc.
  bool redo() {
    final turnId = state.requestRedo();
    if (turnId == null) return false;
    latency.abandon();
    stopSpeaking();
    sendDiscardTurn(turnId);
    return true;
  }
}
