// ═══════════════════════════════════════════════════════════════
// VOCAB DETAIL SCREEN
// File: lib/features/learn/presentation/widgets/vocab_detail_screen.dart
//
// Màn hình chi tiết 1 từ vựng — gọi API /vocabulary/{id}/detail để lấy
// đồng nghĩa/đồng âm/ví dụ thêm. Lần đầu xem có thể chậm (AI sinh mới),
// các lần sau nhanh vì backend đã cache vào DB.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/features/learn/presentation/widgets/stroke_practice_screen.dart';

class VocabDetailScreen extends StatefulWidget {
  final Map<String, dynamic> word;
  final String lang;
  final Future<void> Function(String text) onSpeak;

  const VocabDetailScreen({
    super.key,
    required this.word,
    required this.lang,
    required this.onSpeak,
  });

  @override
  State<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends State<VocabDetailScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<String> _synonyms = [];
  List<String> _homophones = [];
  List<String> _extraExamples = [];
  String? _errorMsg;

  static const _orange = Color(0xFFFF6B35);
  static const _orange2 = Color(0xFFF57F17);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _purple = Color(0xFF7C4DFF);
  static const _blue = Color(0xFF2979FF);
  static const _bg = Color(0xFFF7F8FC);

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final vocabId = widget.word['vocabulary_id']?.toString() ?? widget.word['id']?.toString() ?? '';
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary/$vocabId/detail',
        queryParameters: {'lang': widget.lang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _synonyms = List<String>.from(response.data['synonyms'] ?? []);
        _homophones = List<String>.from(response.data['homophones'] ?? []);
        _extraExamples = List<String>.from(response.data['extra_examples'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _errorMsg = 'Không tải được dữ liệu. Thử lại nhé!'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final hanzi = w['chinese'] ?? w['word'] ?? w['english'] ?? '';
    final pinyin = w['pinyin'] ?? w['ipa'] ?? '';
    final meaning = w['vietnamese'] ?? w['meaning'] ?? '';
    final example = w['example_zh'] ?? w['example'] ?? '';
    final level = w['tocfl_level']?.toString() ?? w['cefr_level']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Chi tiết từ vựng',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          // Hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_orange, _orange2],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(children: [
              Text(hanzi, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'NotoSansTC')),
              const SizedBox(height: 4),
              if (pinyin.isNotEmpty) Text(pinyin, style: const TextStyle(fontSize: 17, fontStyle: FontStyle.italic, color: Colors.white70)),
              const SizedBox(height: 10),
              Text(meaning, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 12),
              if (level.isNotEmpty) Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(level, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GestureDetector(
                  onTap: () => widget.onSpeak(hanzi),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.volume_up_rounded, size: 16, color: _orange2),
                      SizedBox(width: 6),
                      Text('Nghe phát âm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _orange2)),
                    ]),
                  ),
                ),
                if (widget.lang != 'en') ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => StrokePracticeScreen(hanzi: hanzi, meaning: meaning),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded, size: 16, color: _orange2),
                        SizedBox(width: 6),
                        Text('Luyện viết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _orange2)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ]),
          ),

          // Ví dụ gốc
          if (example.isNotEmpty) _buildSection(
            title: 'Ví dụ câu',
            child: _buildExampleCard(example, ''),
          ),

          if (_isLoading) Padding(
            padding: const EdgeInsets.all(30),
            child: Column(children: [
              const CircularProgressIndicator(color: _orange, strokeWidth: 2),
              const SizedBox(height: 10),
              Text(
                'Đang tải thêm dữ liệu... (lần đầu xem có thể mất vài giây)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ]),
          )
          else if (_errorMsg != null) Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Text(_errorMsg!, style: const TextStyle(color: _muted)),
              const SizedBox(height: 10),
              TextButton(onPressed: _loadDetail, child: const Text('Thử lại')),
            ]),
          )
          else ...[
            if (_extraExamples.isNotEmpty) _buildSection(
              title: 'Ví dụ thêm',
              child: Column(children: _extraExamples.map((e) => _buildParsedExample(e)).toList()),
            ),
            if (_synonyms.isNotEmpty) _buildSection(
              title: 'Từ đồng nghĩa',
              child: _buildChipRow(_synonyms, _purple, const Color(0xFFEEE8FF)),
            ),
            if (_homophones.isNotEmpty) _buildSection(
              title: 'Từ đồng âm — dễ nhầm',
              child: _buildChipRow(_homophones, _blue, const Color(0xFFE3F2FD)),
            ),
          ],
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 0.4)),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Widget _buildExampleCard(String zh, String vi) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(zh, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink, fontFamily: 'NotoSansTC')),
      if (vi.isNotEmpty) ...[
        const SizedBox(height: 2),
        Text(vi, style: const TextStyle(fontSize: 12.5, color: _muted)),
      ],
    ]),
  );

  // "câu tiếng Trung (nghĩa tiếng Việt)" → tách ra 2 dòng
  Widget _buildParsedExample(String raw) {
    final match = RegExp(r'^(.*?)\s*\(([^)]*)\)\s*$').firstMatch(raw);
    if (match != null) {
      return _buildExampleCard(match.group(1) ?? raw, match.group(2) ?? '');
    }
    return _buildExampleCard(raw, '');
  }

  Widget _buildChipRow(List<String> items, Color textColor, Color bgColor) => Wrap(
    spacing: 8, runSpacing: 8,
    children: items.map((item) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor, fontFamily: 'NotoSansTC')),
    )).toList(),
  );
}