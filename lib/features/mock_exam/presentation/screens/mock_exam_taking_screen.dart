import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chinesemate/core/constants/api_constants.dart';
import 'package:chinesemate/features/mock_exam/application/providers/mock_exam_session_provider.dart';
import 'package:chinesemate/features/mock_exam/domain/models/mock_exam_session_state.dart';
import 'package:chinesemate/features/mock_exam/presentation/widgets/mock_exam_design.dart';
import 'package:chinesemate/features/mock_exam/presentation/screens/mock_exam_result_screen.dart';

/// Man hinh lam bai — 1 cau/lan, server dieu phoi tuan tu (giong CAT V2
/// adaptive that su, KHONG phai danh sach co san de vuot/lui tuy y).
///
/// Nghe hieu: Stimulus 'audio' (da co audio TTS thuc — xem app/scripts/
/// seed_mock_exam_audio.py) phat qua AudioPlayer voi media_url thuc; 'text'
/// (fallback — item chua/khong co audio thuc, vd audio_status='failed')
/// dung flutter_tts doc transcript LUC BAM PHAT, khong hien thi chu bao gio
/// (xem app/api/v1/mock_exam.py + stimulus_playback_service.py).
class MockExamTakingScreen extends ConsumerStatefulWidget {
  final String? assessmentVersionId; // dung khi bat dau moi
  final String? resumeAttemptId; // dung khi resume attempt da co
  final int? totalQuestionCount;

  const MockExamTakingScreen.start({super.key, required String assessmentVersionId, this.totalQuestionCount})
      : assessmentVersionId = assessmentVersionId,
        resumeAttemptId = null;

  const MockExamTakingScreen.resume({super.key, required String attemptId, this.totalQuestionCount})
      : assessmentVersionId = null,
        resumeAttemptId = attemptId;

  @override
  ConsumerState<MockExamTakingScreen> createState() => _MockExamTakingScreenState();
}

class _MockExamTakingScreenState extends ConsumerState<MockExamTakingScreen> {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _lastSpokenNonce = 0;
  bool _navigatedToResult = false;

  bool _looksChinese(String text) {
    return RegExp(r'[一-鿿]').hasMatch(text);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(mockExamSessionProvider.notifier);
      if (widget.resumeAttemptId != null) {
        notifier.resumeAttempt(widget.resumeAttemptId!, totalQuestionCount: widget.totalQuestionCount);
      } else if (widget.assessmentVersionId != null) {
        notifier.startOrResume(widget.assessmentVersionId!, totalQuestionCount: widget.totalQuestionCount);
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage(_looksChinese(text) ? 'zh-TW' : 'en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> _playRealAudio(String mediaUrl) async {
    // media_url tu backend la duong dan tuong doi ("/static/audio/mock-exam/
    // ...") — server audio KHONG nam duoi /api/v1 nhu cac route API khac,
    // phai noi voi ApiConstants.origin (chi scheme+host), khong phai baseUrl.
    final fullUrl = mediaUrl.startsWith("http") ? mediaUrl : "${ApiConstants.origin}$mediaUrl";
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(fullUrl));
  }

  Future<void> _onPlayStimulus() async {
    await ref.read(mockExamSessionProvider.notifier).playCurrentStimulus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mockExamSessionProvider);

    // Phat audio/TTS khi co 1 lan PHAT THAT MOI (playbackNonce > 0 VA khac
    // lan truoc) — dieu kien "> 0" (khong chi "khac") de KHONG nham voi luc
    // sang cau moi tu reset playbackNonce ve 0 (clearPlaybackState trong
    // _loadNextQuestion() — xem docstring mock_exam_session_state.dart);
    // luc do nonce cu (vd 2) khac 0 nhung KHONG phai 1 lan phat that.
    ref.listen<MockExamSessionState>(mockExamSessionProvider, (prev, next) {
      if (next.playbackNonce > 0 && next.playbackNonce != _lastSpokenNonce) {
        _lastSpokenNonce = next.playbackNonce;
        final stimulus = next.currentQuestion?.stimulus;
        if (stimulus?.stimulusType == 'audio' && stimulus?.mediaUrl != null) {
          _playRealAudio(stimulus!.mediaUrl!);
        } else if (next.lastPlayedTranscript != null) {
          _speak(next.lastPlayedTranscript!);
        }
      }
      // Vấn đề 3: audio/TTS của câu CŨ trước đây chỉ bị dừng khi có 1 lần
      // PHÁT MỚI thật sự (bên trong _playRealAudio/_speak) — nếu câu tiếp
      // theo KHÔNG phải Listening (không phát gì mới), audio cũ tiếp tục
      // chạy vô thời hạn. Dừng CẢ HAI player NGAY khi chuyển sang câu khác
      // (id khác câu trước) hoặc khi nộp bài xong — bất kể câu mới có audio
      // hay không — TRƯỚC KHI xét có auto-play tiếp hay không.
      final newQuestionId = next.currentQuestion?.id;
      final prevQuestionId = prev?.currentQuestion?.id;
      final questionChanged = prevQuestionId != null && newQuestionId != prevQuestionId;
      if (questionChanged || next.phase == ExamPhase.finished) {
        _audioPlayer.stop();
        _tts.stop();
      }

      // Feature 4: tu dong phat khi vao 1 cau Listening MOI (id khac cau
      // truoc) — van goi playCurrentStimulus() y het bam nut thu cong, nen
      // TINH DUNG 1 luot trong replay_limit cua cau do (khong "mien phi"
      // ngoai quota — xac nhan san pham: replay_limit=2, auto-play la luot
      // 1, "Nghe lai" la luot 2 — xem docstring MockExamSessionState).
      if (newQuestionId != null &&
          newQuestionId != prevQuestionId &&
          next.currentQuestion?.stimulus != null &&
          next.phase == ExamPhase.inProgress) {
        ref.read(mockExamSessionProvider.notifier).playCurrentStimulus();
      }
      if (next.phase == ExamPhase.finished && next.finalResult != null && !_navigatedToResult) {
        _navigatedToResult = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MockExamResultScreen.fromResult(next.finalResult!),
          ));
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context);
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: ExamDS.bg,
        appBar: AppBar(
          backgroundColor: ExamDS.bg,
          elevation: 0,
          foregroundColor: ExamDS.textDark,
          title: _buildProgressTitle(state),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final leave = await _confirmLeave(context);
              if (leave && context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: SafeArea(child: _buildBody(state)),
      ),
    );
  }

  Future<bool> _confirmLeave(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát bài thi?'),
        content: const Text('Bài làm của bạn được lưu — bạn có thể tiếp tục sau. Thoát ngay bây giờ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ở lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thoát')),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildProgressTitle(MockExamSessionState state) {
    final total = state.totalQuestionCount;
    final answered = state.answeredCount;
    return Text(
      total != null ? 'Câu ${answered + 1} / ~$total' : 'Đang thi',
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
    );
  }

  Widget _buildBody(MockExamSessionState state) {
    switch (state.phase) {
      case ExamPhase.idle:
      case ExamPhase.loading:
        return const Center(child: CircularProgressIndicator(color: ExamDS.indigo));
      case ExamPhase.error:
        return _buildError(state.errorMessage ?? 'Có lỗi xảy ra');
      case ExamPhase.finished:
        return const Center(child: CircularProgressIndicator(color: ExamDS.indigo));
      case ExamPhase.inProgress:
      case ExamPhase.submitting:
        final question = state.currentQuestion;
        if (question == null) return const Center(child: CircularProgressIndicator(color: ExamDS.indigo));
        return _buildQuestion(state);
    }
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: ExamDS.textGrey)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: ExamDS.indigo),
            child: const Text('Quay lại', style: TextStyle(color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuestion(MockExamSessionState state) {
    final question = state.currentQuestion!;
    final isListening = question.stimulus != null;
    final submitting = state.phase == ExamPhase.submitting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (isListening) _buildListeningPlayer(state),
        if (!isListening && question.contextText != null && question.contextText!.trim().isNotEmpty)
          _buildPassage(question.contextText!),
        const SizedBox(height: 16),
        Text(question.promptText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ExamDS.textDark)),
        const SizedBox(height: 16),
        ...question.options.map((opt) {
          final selected = state.selectedOptionId == opt.id;
          return GestureDetector(
            onTap: submitting ? null : () => ref.read(mockExamSessionProvider.notifier).selectOption(opt.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? ExamDS.indigoLight : ExamDS.white,
                borderRadius: BorderRadius.circular(ExamDS.radiusSm),
                border: Border.all(color: selected ? ExamDS.indigo : const Color(0xFFE0E4F5), width: selected ? 2 : 1),
              ),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? ExamDS.indigo : ExamDS.textGrey, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(opt.optionText, style: const TextStyle(color: ExamDS.textDark))),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.canSubmit && !submitting
                ? () => ref.read(mockExamSessionProvider.notifier).submitAndAdvance()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ExamDS.indigo,
              disabledBackgroundColor: const Color(0xFFE0E4F5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ExamDS.radiusSm)),
            ),
            child: submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Nộp & câu tiếp theo',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPassage(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: ExamDS.white, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Text(text, style: const TextStyle(color: ExamDS.textDark, height: 1.5)),
    );
  }

  Widget _buildListeningPlayer(MockExamSessionState state) {
    final remaining = state.lastPlayedRemainingPlays;
    final hasPlayed = state.playbackNonce > 0;
    final exhausted = remaining != null && remaining <= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: ExamDS.indigoLight, borderRadius: BorderRadius.circular(ExamDS.radius)),
      child: Column(children: [
        const Text('🎧', style: TextStyle(fontSize: 36)),
        const SizedBox(height: 8),
        Text(
          exhausted ? 'Đã hết lượt phát' : (hasPlayed ? 'Đã phát — có thể nghe lại' : 'Đang tự động phát...'),
          style: const TextStyle(color: ExamDS.textGrey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: exhausted ? null : _onPlayStimulus,
          icon: const Icon(Icons.volume_up, color: Colors.white),
          label: Text(hasPlayed ? 'Nghe lại' : 'Phát',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(
            backgroundColor: ExamDS.indigo,
            disabledBackgroundColor: const Color(0xFFC4C8E8),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (remaining != null) ...[
          const SizedBox(height: 8),
          Text('Còn $remaining lượt phát', style: const TextStyle(fontSize: 11, color: ExamDS.textGrey)),
        ],
      ]),
    );
  }
}
