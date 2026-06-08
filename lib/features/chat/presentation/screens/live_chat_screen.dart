import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:go_router/go_router.dart';

const _wsBase = 'wss://taiwanmate-backend-production.up.railway.app';
const _cyan = Color(0xFF00E5FF);
const _cyanDark = Color(0xFF0097A7);
const _cyanGlow = Color(0xFF00BCD4);

class LiveChatScreen extends StatefulWidget {
  final String aiGender;
  final String userType;
  final String learningMode;

  const LiveChatScreen({
    super.key,
    this.aiGender = 'female',
    this.userType = 'student',
    this.learningMode = 'zh_vi',
  });

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen>
    with TickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  WebSocketChannel? _channel;

  bool _isConnected = false;
  bool _isListening = false;
  bool _aiSpeaking = false;
  bool _isConnecting = true;
  bool _upgradeDialogShown = false;
  String _statusText = 'INITIALIZING...';
  String _transcript = '';
  double _remainingMinutes = 0;
  double _sessionSeconds = 0;
  Timer? _sessionTimer;

  late AnimationController _hexController;
  late AnimationController _ringController;
  late AnimationController _glitchController;
  late AnimationController _scanController;
  late AnimationController _pulseController;

  // ── Audio recording ──
  html.MediaRecorder? _recorder;
  List<html.Blob> _audioChunks = [];
  Timer? _audioSendTimer;

  String get _aiName => widget.aiGender == 'female' ? '小美' : '小明';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _connect();
  }

  void _initAnimations() {
    _hexController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _glitchController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stopListening();
    _stopSessionTimer();
    _channel?.sink.close();
    _hexController.dispose();
    _ringController.dispose();
    _glitchController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── WebSocket ──────────────────────────────────────────────
  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _statusText = 'CONNECTING...';
    });
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        setState(() { _isConnecting = false; _statusText = 'NOT LOGGED IN'; });
        return;
      }
      final uri = Uri.parse(
        '$_wsBase/api/v1/live/session'
        '?token=$token'
        '&ai_gender=${widget.aiGender}'
        '&user_type=${widget.userType}'
        '&learning_mode=${widget.learningMode}',
      );
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _handleMessage,
        onError: (e) {
          if (mounted) setState(() { _isConnected = false; _statusText = 'CONNECTION ERROR'; });
        },
        onDone: () {
          if (mounted) setState(() { _isConnected = false; _statusText = 'SESSION ENDED'; });
          _stopSessionTimer();
        },
      );
    } catch (e) {
      if (mounted) setState(() { _isConnecting = false; _statusText = 'ERROR: $e'; });
    }
  }

  void _handleMessage(dynamic data) {
    if (!mounted) return;
    try {
      final msg = json.decode(data as String);
      switch (msg['type'] as String?) {
        case 'session_started':
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _remainingMinutes = (msg['remaining_minutes'] ?? 0).toDouble();
            _statusText = 'READY — HOLD TO SPEAK';
          });
          _startSessionTimer();
          _triggerGlitch();
          break;

        case 'audio':
          // Backend gửi PCM base64 → play qua Web Audio API
          _playPcmAudio(msg['data'] as String);
          setState(() { _aiSpeaking = true; _statusText = '$_aiName SPEAKING...'; });
          break;

        case 'transcript':
          setState(() => _transcript = msg['text'] ?? '');
          break;

        case 'turn_complete':
          setState(() { _aiSpeaking = false; _statusText = 'READY — HOLD TO SPEAK'; });
          break;

        case 'session_timeout':
          _showTimeoutDialog();
          break;

        case 'session_ended':
          final used = msg['minutes_used'] ?? 0;
          final remaining = msg['remaining_minutes'] ?? 0;
          setState(() {
            _remainingMinutes = (remaining as num).toDouble();
            _statusText = 'SESSION ENDED — ${used}m used';
          });
          break;

        case 'error':
          final errMsg = msg['message'] as String? ?? 'Unknown error';
          if (msg['upgrade_required'] == true && !_upgradeDialogShown) {
            _upgradeDialogShown = true;
            _showUpgradeDialog();
          } else if (msg['quota_exceeded'] == true) {
            setState(() => _statusText = 'HẾT PHÚT LIVE THÁNG NÀY');
          } else {
            setState(() => _statusText = 'LỖI: $errMsg');
          }
          break;
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
  }

  void _triggerGlitch() {
    _glitchController.forward(from: 0).then((_) => _glitchController.reverse());
  }

  // ── Play PCM audio từ Gemini ──────────────────────────────
  void _playPcmAudio(String b64) {
    try {
      // Gemini trả về raw PCM 16-bit little-endian, rate 24000Hz
      // Dùng Web Audio API để play
      final script = '''
(function() {
  try {
    var b64 = "$b64";
    var raw = atob(b64);
    var buf = new ArrayBuffer(raw.length);
    var view = new Uint8Array(buf);
    for (var i = 0; i < raw.length; i++) { view[i] = raw.charCodeAt(i); }
    
    var sampleRate = 24000;
    var numSamples = raw.length / 2;
    var audioCtx = window._taiwanmateAudioCtx || (window._taiwanmateAudioCtx = new AudioContext({sampleRate: sampleRate}));
    var audioBuffer = audioCtx.createBuffer(1, numSamples, sampleRate);
    var channelData = audioBuffer.getChannelData(0);
    var int16 = new Int16Array(buf);
    for (var i = 0; i < numSamples; i++) {
      channelData[i] = int16[i] / 32768.0;
    }
    var source = audioCtx.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(audioCtx.destination);
    source.start();
  } catch(e) { console.error('Audio play error:', e); }
})();
''';
      html.ScriptElement scriptEl = html.ScriptElement();
      // ignore: unsafe_html
      html.document.head!.append(scriptEl);
      // Dùng eval thay vì script tag để chạy ngay
      html.window.dispatchEvent(html.CustomEvent('_play_pcm', detail: b64));
    } catch (e) {
      debugPrint('Play error: $e');
    }
  }

  // ── Mic recording ─────────────────────────────────────────
  Future<void> _startListening() async {
    if (!_isConnected || _aiSpeaking || _isListening) return;
    try {
      final stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'audio': true, 'video': false});

      _audioChunks = [];

      // Dùng audio/webm vì browser chỉ support webm/ogg, backend nhận và forward lên Gemini
      final mimeType = html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
          ? 'audio/webm;codecs=opus'
          : 'audio/webm';

      _recorder = html.MediaRecorder(stream, {'mimeType': mimeType});

      _recorder!.addEventListener('dataavailable', (e) {
        final blob = (e as html.BlobEvent).data;
        if (blob != null && blob.size > 0) _audioChunks.add(blob);
      });

      // Gửi chunk mỗi 200ms
      _recorder!.start(200);

      setState(() { _isListening = true; _statusText = 'LISTENING...'; });

      // Gửi audio chunks lên server định kỳ
      _audioSendTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        _flushAudioChunks();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _flushAudioChunks() {
    if (_audioChunks.isEmpty || _channel == null) return;
    final chunks = List<html.Blob>.from(_audioChunks);
    _audioChunks.clear();
    final combined = html.Blob(chunks, 'audio/webm');
    final reader = html.FileReader();
    reader.readAsArrayBuffer(combined);
    reader.onLoadEnd.listen((_) {
      if (reader.result == null) return;
      try {
        final bytes = reader.result as List<int>;
        final b64 = base64Encode(bytes);
        _channel?.sink.add(json.encode({'type': 'audio', 'data': b64}));
      } catch (e) {
        debugPrint('Send audio error: $e');
      }
    });
  }

  void _stopListening() {
    if (!_isListening) return;
    _audioSendTimer?.cancel();
    _audioSendTimer = null;

    try {
      _recorder?.stop();
      _recorder?.stream?.getTracks().forEach((t) => t.stop());
    } catch (e) {
      debugPrint('Stop recorder error: $e');
    }
    _recorder = null;

    // Gửi nốt chunk còn lại
    _flushAudioChunks();

    if (mounted) setState(() { _isListening = false; _statusText = 'PROCESSING...'; });
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSeconds++);
    });
  }

  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  String get _sessionTime {
    final mins = (_sessionSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_sessionSeconds % 60).toInt().toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _endSession() {
    try {
      _channel?.sink.add(json.encode({'type': 'end_session'}));
    } catch (e) {
      debugPrint('End session error: $e');
    }
    _stopListening();
    _stopSessionTimer();
    if (mounted) context.pop();
  }

  // ── Dialogs ───────────────────────────────────────────────
  void _showTimeoutDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _cyan, width: 1),
        ),
        title: const Text('SESSION TIMEOUT',
            style: TextStyle(color: _cyan, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: const Text('Phiên 10 phút đã kết thúc.\nBắt đầu phiên mới để tiếp tục.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.of(context).pop(); context.pop(); },
            style: ElevatedButton.styleFrom(backgroundColor: _cyanDark),
            child: const Text('ĐÓNG'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 1),
        ),
        title: const Text('NÂNG CẤP VIP',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 2)),
        content: const Text(
          'Tính năng Live Chat chỉ dành cho VIP.\nNâng cấp để trò chuyện trực tiếp với 小美 và 小明!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); context.pop(); },
            child: const Text('ĐỂ SAU', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/profile');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('NÂNG CẤP NGAY'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020810),
      body: Stack(
        children: [
          CustomPaint(
            size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
            painter: _HexGridPainter(_hexController),
          ),
          AnimatedBuilder(
            animation: _scanController,
            builder: (_, __) => Positioned(
              top: _scanController.value * MediaQuery.of(context).size.height,
              left: 0, right: 0,
              child: Container(height: 2, color: _cyan.withOpacity(0.06)),
            ),
          ),
          SafeArea(
            child: Column(children: [
              _buildHUD(),
              Expanded(child: SingleChildScrollView(child: _buildCenter())),
              _buildControls(),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: _endSession,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: _cyan.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.close_rounded, color: _cyan, size: 18),
          ),
        ),
        Column(children: [
          Text('LIVE SESSION',
              style: TextStyle(color: _cyan.withOpacity(0.7), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _isConnected ? Colors.red : Colors.grey,
                shape: BoxShape.circle,
                boxShadow: _isConnected ? [const BoxShadow(color: Colors.red, blurRadius: 6)] : [],
              ),
            ),
            const SizedBox(width: 6),
            Text(_sessionTime,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ]),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _cyan.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text('${_remainingMinutes.toInt()}',
                style: const TextStyle(color: _cyan, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('MIN', style: TextStyle(color: _cyan.withOpacity(0.5), fontSize: 8, letterSpacing: 2)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCenter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(alignment: Alignment.center, children: [
            ...List.generate(3, (i) => AnimatedBuilder(
              animation: _ringController,
              builder: (_, __) {
                final progress = (_ringController.value + i * 0.33) % 1.0;
                final size = 180.0 + progress * 60;
                return Container(
                  width: size, height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _cyan.withOpacity((1 - progress) * 0.3), width: 1),
                  ),
                );
              },
            )),
            AnimatedBuilder(
              animation: _hexController,
              builder: (_, __) => CustomPaint(
                size: const Size(180, 180),
                painter: _HexBorderPainter(_hexController.value, _isListening, _aiSpeaking),
              ),
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 150, height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF020810),
                  border: Border.all(
                    color: _isListening
                        ? Colors.red.withOpacity(0.8)
                        : _aiSpeaking
                            ? _cyan.withOpacity(0.8)
                            : _cyan.withOpacity(0.3 + _pulseController.value * 0.2),
                    width: 2,
                  ),
                  boxShadow: [BoxShadow(
                    color: (_isListening ? Colors.red : _cyan)
                        .withOpacity(0.2 + _pulseController.value * 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )],
                ),
                child: AnimatedBuilder(
                  animation: _glitchController,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(_glitchController.value * 3, 0),
                    child: Center(child: Text(
                      widget.aiGender == 'female' ? '👩' : '👨',
                      style: const TextStyle(fontSize: 72),
                    )),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _scanController,
              builder: (_, __) => ClipOval(
                child: Container(
                  width: 150, height: 150,
                  alignment: Alignment(0, -1 + _scanController.value * 2),
                  child: Container(height: 1, color: _cyan.withOpacity(0.3)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text(_aiName,
            style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white,
              shadows: [Shadow(color: _cyan, blurRadius: 20)],
            )),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: _cyan.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(4),
            color: _cyan.withOpacity(0.04),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _statusText,
              key: ValueKey(_statusText),
              style: TextStyle(
                fontSize: 11,
                color: _isListening ? Colors.red : _isConnecting ? Colors.white38 : _cyan,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_aiSpeaking) const _HologramWaveform(),
        if (_transcript.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cyan.withOpacity(0.15)),
            ),
            child: Text(
              _transcript,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
            ),
          ),
      ]),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
      child: Column(children: [
        GestureDetector(
          onTapDown: (_) => _startListening(),
          onTapUp: (_) => _stopListening(),
          onTapCancel: () => _stopListening(),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: _isListening ? 90 : 72,
              height: _isListening ? 90 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF020810),
                border: Border.all(color: _isListening ? Colors.red : _cyan, width: 2),
                boxShadow: [BoxShadow(
                  color: (_isListening ? Colors.red : _cyan)
                      .withOpacity(0.3 + _pulseController.value * 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )],
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? Colors.red : _cyan,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isListening ? 'RELEASE TO SEND' : 'HOLD TO SPEAK',
          style: TextStyle(
            color: _isListening ? Colors.red.withOpacity(0.8) : _cyan.withOpacity(0.5),
            fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _endSession,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4),
              color: Colors.red.withOpacity(0.05),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_end_rounded, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text('END SESSION',
                  style: TextStyle(color: Colors.red, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─── Hex Grid Background ──────────────────────────────────────
class _HexGridPainter extends CustomPainter {
  final Animation<double> animation;
  _HexGridPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyan.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    const hexSize = 30.0;
    final cols = (size.width / (hexSize * 1.5)).ceil() + 2;
    final rows = (size.height / (hexSize * math.sqrt(3))).ceil() + 2;
    for (int col = -1; col < cols; col++) {
      for (int row = -1; row < rows; row++) {
        final x = col * hexSize * 1.5;
        final y = row * hexSize * math.sqrt(3) + (col.isOdd ? hexSize * math.sqrt(3) / 2 : 0);
        _drawHex(canvas, paint, x, y, hexSize * 0.9);
      }
    }
  }

  void _drawHex(Canvas canvas, Paint paint, double cx, double cy, double size) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = cx + size * math.cos(angle);
      final y = cy + size * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexGridPainter old) => false;
}

// ─── Hex Border ───────────────────────────────────────────────
class _HexBorderPainter extends CustomPainter {
  final double progress;
  final bool isListening;
  final bool isSpeaking;
  _HexBorderPainter(this.progress, this.isListening, this.isSpeaking);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i < 6; i++) {
      final startAngle = progress * 2 * math.pi + i * math.pi / 3;
      final color = isListening ? Colors.red : isSpeaking ? _cyanGlow : _cyan;
      paint.color = color.withOpacity(0.4 + (i % 2) * 0.3);
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, math.pi / 4, false, paint);
    }
    for (int i = 0; i < 6; i++) {
      final angle = progress * 2 * math.pi + i * math.pi / 3;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 3,
          Paint()..color = _cyan.withOpacity(0.8)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) =>
      old.progress != progress || old.isListening != isListening || old.isSpeaking != isSpeaking;
}

// ─── Waveform ─────────────────────────────────────────────────
class _HologramWaveform extends StatefulWidget {
  const _HologramWaveform();
  @override
  State<_HologramWaveform> createState() => _HologramWaveformState();
}

class _HologramWaveformState extends State<_HologramWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(16, (i) {
            final height = 4.0 + 28 * math.sin(_ctrl.value * math.pi + i * 0.4).abs();
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 4)],
              ),
            );
          }),
        ),
      ),
    );
  }
}