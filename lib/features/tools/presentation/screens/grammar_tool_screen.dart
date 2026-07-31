// ═══════════════════════════════════════════════════════════════
// GRAMMAR TOOL SCREEN — Công cụ Ngữ pháp chuyên sâu (zh + en)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'grammar_tool_screen.dart';

class GrammarToolScreen extends StatefulWidget {
  final String? initialQuery;
  const GrammarToolScreen({super.key, this.initialQuery});

  @override
  State<GrammarToolScreen> createState() => _GrammarToolScreenState();
}

class _GrammarToolScreenState extends State<GrammarToolScreen> {
  final _storage = const FlutterSecureStorage();
  final _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(widget.initialQuery!));
    }
  }

  static const _green = Color(0xFF00C853);
  static const _green2 = Color(0xFF2E7D32);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF7F8FC);
  static const _purple = Color(0xFF5B5FEF);
  static const _orange = Color(0xFFFF6B35);

  final List<String> _quickPrompts = [
    'Giải thích cấu trúc "把" sentence',
    'Phân biệt "have been" và "have gone"',
    'Phân biệt 的/地/得',
    'Khi nào dùng "了" trong tiếng Trung',
  ];

  Future<void> _ask(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    setState(() { _isLoading = true; _error = null; _result = null; });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 45), receiveTimeout: const Duration(seconds: 45)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tools/grammar',
        data: {'text': text.trim()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() { _result = Map<String, dynamic>.from(response.data); _isLoading = false; });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        setState(() { _error = 'Bạn đã dùng hết lượt miễn phí hôm nay. Nâng cấp VIP để dùng không giới hạn!'; _isLoading = false; });
        return;
      }
      setState(() { _error = 'Lỗi kết nối. Thử lại nhé!'; _isLoading = false; });
    } catch (_) {
      setState(() { _error = 'Lỗi kết nối. Thử lại nhé!'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('📖 Ngữ pháp chuyên sâu',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ô nhập câu hỏi
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Hỏi bất kỳ điểm ngữ pháp nào...',
                  border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: _ask,
              )),
              GestureDetector(
                onTap: () => _ask(_controller.text),
                child: Container(
                  margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [_green, _green2]), shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Gợi ý nhanh
          Wrap(spacing: 8, runSpacing: 8, children: _quickPrompts.map((p) => GestureDetector(
            onTap: () { _controller.text = p; _ask(p); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(p, style: const TextStyle(fontSize: 12, color: _green2, fontWeight: FontWeight.w600)),
            ),
          )).toList()),

          const SizedBox(height: 20),

          if (_isLoading) const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Column(children: [
              CircularProgressIndicator(color: _green),
              SizedBox(height: 12),
              Text('Đang phân tích chi tiết...', style: TextStyle(color: _muted, fontSize: 13)),
            ])),
          ),

          if (_error != null) Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Color(0xFF8A2E26))),
          ),

          if (_result != null) _buildResultCard(),
        ]),
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    final definition = r['definition'] as String? ?? '';
    final formula = r['formula'] as String? ?? '';
    final examples = (r['examples'] as List?) ?? [];
    final comparison = r['comparison'] as String? ?? '';
    final mistakes = r['common_mistakes'] as String? ?? '';
    final exceptions = r['exceptions'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (definition.isNotEmpty) ...[
            _sectionLabel('ĐỊNH NGHĨA'),
            Text(definition, style: const TextStyle(fontSize: 14.5, color: _ink, height: 1.6)),
            const SizedBox(height: 16),
          ],

          if (formula.isNotEmpty) ...[
            _sectionLabel('CÔNG THỨC'),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(formula, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _green2, fontFamily: 'NotoSansTC')),
            ),
            const SizedBox(height: 16),
          ],

          if (examples.isNotEmpty) ...[
            _sectionLabel('VÍ DỤ THỰC TẾ'),
            ...examples.map((e) => Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['text'] ?? '', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink, fontFamily: 'NotoSansTC')),
                if ((e['meaning'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(e['meaning'], style: const TextStyle(fontSize: 12.5, color: _muted)),
                ],
              ]),
            )),
            const SizedBox(height: 8),
          ],

          if (comparison.isNotEmpty) ...[
            _sectionLabel('SO SÁNH DỄ NHẦM'),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(comparison, style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5)),
            ),
            const SizedBox(height: 16),
          ],

          if (mistakes.isNotEmpty) ...[
            _sectionLabel('⚠️ LỖI HAY GẶP'),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(10),
                  border: const Border(left: BorderSide(color: Color(0xFFFF3D57), width: 3))),
              child: Text(mistakes, style: const TextStyle(fontSize: 13.5, color: Color(0xFF8A2E26), height: 1.5)),
            ),
            const SizedBox(height: 16),
          ],

          if (exceptions.isNotEmpty) ...[
            _sectionLabel('NGOẠI LỆ'),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: Text(exceptions, style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.4)),
  );
}