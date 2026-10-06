import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/learn/presentation/widgets/quick_review_screen.dart';

/// "Hôm nay" v1 (thiết kế 2026-10-04, Phase 2 gốc — buổi học 10-15 phút): gộp 3 lối đi CÓ SẴN
/// thành 1 luồng tuần tự, KHÔNG ghi mastery riêng (mọi điểm vẫn qua record_learning_event như
/// cũ, màn này chỉ là lớp điều hướng):
///   (a) Nhớ lại — đọc, không bấm gì. Ưu tiên last_taught_content (chat-sửa-lỗi), fallback 3 từ
///       đầu của unit HOÀN THÀNH gần nhất (GET /learn/today, xem app/api/v1/learn_today.py).
///       Ẩn hẳn card nếu không có gì (gần như luôn vậy lúc này — nguồn ghi content_snapshot còn
///       hẹp, đã nói rõ khi thiết kế).
///   (b) Ôn SRS đến hạn — KHÔNG gọi API riêng, dùng ĐÚNG `vocabulary`/getters đã tải sẵn ở
///       LearnScreen (nơi duy nhất đang giữ danh sách này), lọc is_review==true, giới hạn 8 thẻ.
///   (c) Tiếp tục unit kế tiếp — mở thẳng CurriculumTab(initialUnitId) (xem curriculum_tab.dart).
/// Đo lường (không migration): GET /learn/today tự ghi log "opened" ở backend; `_logEvent()` ở
/// đây chỉ ghi khi user THỰC SỰ bấm vào 1 bước (step=review|unit), fire-and-forget, không chặn
/// điều hướng nếu lỗi/mạng chậm.
class TodaySessionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> vocabulary;
  final String lang;
  final String Function(Map<String, dynamic>) getWord;
  final String Function(Map<String, dynamic>) getPinyin;
  final String Function(Map<String, dynamic>) getMeaning;
  final String Function(Map<String, dynamic>) getExample;
  final String Function(Map<String, dynamic>) getVocabId;
  final bool Function(Map<String, dynamic>) isReview;
  final int Function(Map<String, dynamic>) getSrsLevel;
  final VoidCallback onStudied;
  final Future<void> Function(String, bool) onUpdateSRS;
  // Chi de test: thay phu thuoc mang/luu tru (dung y het mau da co o placement_card.dart).
  final Dio? dio;
  final Future<String?> Function()? readToken;

  const TodaySessionScreen({
    super.key,
    required this.vocabulary,
    required this.lang,
    required this.getWord,
    required this.getPinyin,
    required this.getMeaning,
    required this.getExample,
    required this.getVocabId,
    required this.isReview,
    required this.getSrsLevel,
    required this.onStudied,
    required this.onUpdateSRS,
    this.dio,
    this.readToken,
  });

  @override
  State<TodaySessionScreen> createState() => _TodaySessionScreenState();
}

const _kMaxReviewCards = 8; // "10-15 phut" — gioi han so the on, khop README thiet ke

class _TodaySessionScreenState extends State<TodaySessionScreen> {
  static const _storage = FlutterSecureStorage();
  late final Dio _dio = widget.dio ?? Dio();

  bool _isLoading = true;
  bool _error = false;
  Map<String, dynamic>? _recall;
  Map<String, dynamic>? _nextUnit;
  bool _curriculumCompleted = false;
  final Set<String> _revealedWordIds = {}; // card (a) fallback unit_words — cham de lo pinyin/nghia

  static const _purple = Color(0xFF5B5FEF);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF0F4FF);

  List<Map<String, dynamic>> get _dueWords =>
      widget.vocabulary.where(widget.isReview).take(_kMaxReviewCards).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> get _token async => (widget.readToken ?? () => _storage.read(key: 'access_token'))();

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = false; });
    try {
      final token = await _token;
      final res = await _dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/learn/today',
        queryParameters: {'language': widget.lang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _recall = res.data['recall'] as Map<String, dynamic>?;
        _nextUnit = res.data['next_unit'] as Map<String, dynamic>?;
        _curriculumCompleted = res.data['curriculum_completed'] == true;
      });
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logEvent(String step) async {
    try {
      final token = await _token;
      await _dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/learn/today/event',
        data: {'step': step, 'action': 'tap'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort — khong chan dieu huong neu loi/mang cham.
    }
  }

  void _openReview() {
    _logEvent('review');
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuickReviewScreen(
      vocabulary: _dueWords, lang: widget.lang, getWord: widget.getWord, getPinyin: widget.getPinyin,
      getMeaning: widget.getMeaning, getExample: widget.getExample, getVocabId: widget.getVocabId,
      isReview: widget.isReview, getSrsLevel: widget.getSrsLevel, onStudied: widget.onStudied,
      onUpdateSRS: widget.onUpdateSRS,
    )));
  }

  void _openNextUnit() {
    final unit = _nextUnit;
    if (unit == null) return;
    _logEvent('unit');
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('Lộ trình học',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: CurriculumTab(
        initialLanguage: widget.lang, initialLevel: unit['level'] as String?,
        initialUnitId: unit['unit_id'] as String?,
        // Chuyen tiep CHINH dio/readToken cua man nay (null = Dio/secure storage thuc o
        // production) — tranh CurriculumTab tu tao 1 Dio THAT rieng khi dang chay test voi
        // dio gia o day (xem today_session_screen_test.dart).
        dio: widget.dio, readToken: widget.readToken,
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('Học hôm nay',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_error) _buildErrorCard(),
                if (!_error && _recall != null) _buildRecallCard(_recall!),
                _buildReviewCard(),
                if (!_error) _buildNextUnitCard(),
              ],
            ),
    );
  }

  Widget _card({required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _cta(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity,
      decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(12)),
      child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
    ),
  );

  Widget _buildErrorCard() => _card(children: [
    const Text('Không tải được gợi ý hôm nay', style: TextStyle(color: _textDark, fontWeight: FontWeight.w700)),
    const SizedBox(height: 4),
    const Text('Vẫn ôn được từ vựng bên dưới nhé.', style: TextStyle(color: _textGrey, fontSize: 12)),
    _cta('Thử lại', _load),
  ]);

  Widget _buildRecallCard(Map<String, dynamic> recall) {
    if (recall['type'] == 'unit_words') {
      final words = List<Map<String, dynamic>>.from(recall['words'] ?? []);
      return _card(children: [
        Text('Nhớ lại: ${recall['unit_topic_vi'] ?? ''}',
            style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('Chạm vào từ để xem phiên âm và nghĩa', style: TextStyle(color: _textGrey, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in words) _buildRecallWordChip(w),
        ]),
      ]);
    }
    // type == 'taught'
    return _card(children: [
      Text('Nhớ lại: ${recall['label'] ?? ''}',
          style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 6),
      Text(recall['content'] ?? '', style: const TextStyle(color: _textGrey, fontSize: 13, height: 1.4)),
    ]);
  }

  Widget _buildRecallWordChip(Map<String, dynamic> w) {
    final id = (w['id'] ?? '').toString();
    final revealed = _revealedWordIds.contains(id);
    return GestureDetector(
      onTap: () => setState(() => _revealedWordIds.add(id)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(w['word'] ?? '', style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 15)),
          if (revealed) ...[
            const SizedBox(height: 2),
            Text(w['pinyin_or_ipa'] ?? '', style: const TextStyle(color: _purple, fontSize: 12)),
            Text(w['meaning'] ?? '', style: const TextStyle(color: _textGrey, fontSize: 12)),
          ],
        ]),
      ),
    );
  }

  Widget _buildReviewCard() {
    final due = _dueWords;
    return _card(children: [
      const Text('Ôn từ vựng', style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 4),
      Text(
        due.isEmpty ? 'Không có thẻ cần ôn hôm nay 🎉' : '${due.length} thẻ cần ôn hôm nay',
        style: const TextStyle(color: _textGrey, fontSize: 12),
      ),
      if (due.isNotEmpty) _cta('Ôn ngay', _openReview),
    ]);
  }

  Widget _buildNextUnitCard() {
    if (_curriculumCompleted) {
      return _card(children: const [
        Text('Tiếp tục lộ trình', style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 14)),
        SizedBox(height: 4),
        Text('Bạn đã học hết lộ trình rồi! 🎉', style: TextStyle(color: _textGrey, fontSize: 12)),
      ]);
    }
    final unit = _nextUnit;
    if (unit == null) return const SizedBox.shrink();
    return _card(children: [
      const Text('Tiếp tục lộ trình', style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 4),
      Text(unit['topic_vi'] ?? '', style: const TextStyle(color: _textGrey, fontSize: 12)),
      _cta('Học bài này', _openNextUnit),
    ]);
  }
}
