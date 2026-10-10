// ═══════════════════════════════════════════════════════════════
// GRAMMAR TOOL SCREEN — Công cụ Ngữ pháp chuyên sâu (zh + en)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GrammarToolScreen extends StatefulWidget {
  final String? initialQuery;
  // Chi de test: thay phu thuoc mang/luu tru (dung y het mau da co o placement_card.dart).
  final Dio? dio;
  final Future<String?> Function()? readToken;
  const GrammarToolScreen({super.key, this.initialQuery, this.dio, this.readToken});

  @override
  State<GrammarToolScreen> createState() => _GrammarToolScreenState();
}

class _GrammarToolScreenState extends State<GrammarToolScreen> {
  final _storage = const FlutterSecureStorage();
  final _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _isLoading = false;
  String? _error;
  final Set<int> _shownAnswers = {}; // chi so cau luyen tap da bam 'Xem dap an'

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
    setState(() { _isLoading = true; _error = null; _result = null; _shownAnswers.clear(); });
    try {
      final token = await (widget.readToken ?? () => _storage.read(key: 'access_token'))();
      // Bai giang CHUYEN SAU lan dau phai sinh moi bang gpt-4.1 (2 phan song song + giam khao, ~15-40s) nen
      // nang receiveTimeout len 120s (truoc day 45s). Backend cung nang timeout rieng cho route nay.
      final dio = widget.dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 120)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tools/grammar',
        data: {'text': text.trim()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() { _result = Map<String, dynamic>.from(response.data); _isLoading = false; });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Het luot TAO MOI bai giang (feature=grammar_deep) co thong diep rieng tu backend (bai da co san van xem duoc).
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        final msg = (detail is Map && detail['feature'] == 'grammar_deep' && detail['message'] is String)
            ? detail['message'] as String
            : 'Bạn đã dùng hết lượt miễn phí hôm nay. Nâng cấp VIP để dùng không giới hạn!';
        setState(() { _error = msg; _isLoading = false; });
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
              Text('Đang soạn bài giảng chi tiết… (lần đầu khoảng 30 giây)', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13)),
            ])),
          ),

          if (_error != null) Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: const TextStyle(color: Color(0xFF8A2E26))),
          ),

          if (_result != null) _buildResultSection(),
        ]),
      ),
    );
  }

  /// Bug production (2026-10-06) — AI (OpenAI, response_format=json_object) chi dam bao JSON
  /// HOP LE VE CU PHAP, KHONG dam bao DUNG SCHEMA da mo ta trong prompt (xem
  /// app/services/openai_service.py::explain_grammar_tool — json.loads() tra thang ve, KHONG
  /// validate gi ca). Da tai hien THAT bang widget test (xem
  /// grammar_tool_screen_repro_test.dart): AI tra "examples" la List<String> thay vi dung
  /// List<Map{text,meaning}> nhu prompt yeu cau -> e['text'] (String khong co operator[] theo
  /// key) -> throw NGAY TRONG build() -> Scaffold/AppBar/nut back o duoi KHONG BAO GIO duoc tao
  /// (Dart danh gia het tham so truoc khi goi ham) -> Flutter thay CA Element nay bang
  /// ErrorWidget rong (web release) -> dung y "man trang hoan toan, khong nut back" da bao cao.
  ///
  /// Sua 2 lop: (1) _parseResult() ep kieu AN TOAN tung field (khong "as String?"/"as List?"
  /// tin blind theo schema, dung .toString()/kiem tra kieu tung phan tu) o ngay duoi day; (2)
  /// VAN boc them try/catch o day lam luoi an toan cuoi — du sau nay AI doi schema kieu khac
  /// nua ma _parseResult() chua luong het, loi van CHI o PHAN KET QUA (hien the bang loi), con
  /// Scaffold/AppBar/nut back o build() PHIA TREN van luon duoc tao TRUOC do, khong bao gio
  /// con man trang khong loi thoat.
  Widget _buildResultSection() {
    try {
      if (_result!['version'] == 2) return _buildDeepCard(parseDeepGrammar(_result!));
      return _buildResultCard(_parseResult(_result!));
    } catch (_) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(12)),
        child: const Text('Không hiển thị được kết quả cho câu hỏi này. Thử câu hỏi khác nhé!',
            style: TextStyle(color: Color(0xFF8A2E26))),
      );
    }
  }

  /// Ep kieu AN TOAN — KHONG dung "as String?"/"as List?" (throw neu AI tra sai kieu, du la
  /// null hop le), dung .toString() (khong bao gio throw, moi kieu deu stringify duoc) cho
  /// field dang la text; voi "examples", CHAP NHAN CA 2 dang (Map{text,meaning} dung schema,
  /// hoac 1 String bare — van HIEN DUNG noi dung AI tra ve thay vi bo qua) va bo qua phan tu
  /// nao khong doc duoc (khong lam vo ca danh sach vi 1 phan tu la).
  Map<String, dynamic> _parseResult(Map<String, dynamic> r) {
    final examplesRaw = (r['examples'] is List) ? r['examples'] as List : const [];
    final examples = examplesRaw.map((e) {
      if (e is Map) return {'text': e['text']?.toString() ?? '', 'meaning': e['meaning']?.toString() ?? ''};
      if (e is String) return {'text': e, 'meaning': ''};
      return {'text': '', 'meaning': ''};
    }).where((e) => (e['text'] ?? '').isNotEmpty).toList();
    return {
      'definition': r['definition']?.toString() ?? '',
      'formula': r['formula']?.toString() ?? '',
      'examples': examples,
      'comparison': r['comparison']?.toString() ?? '',
      'common_mistakes': r['common_mistakes']?.toString() ?? '',
      'exceptions': r['exceptions']?.toString() ?? '',
    };
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final definition = r['definition'] as String;
    final formula = r['formula'] as String;
    final examples = r['examples'] as List;
    final comparison = r['comparison'] as String;
    final mistakes = r['common_mistakes'] as String;
    final exceptions = r['exceptions'] as String;

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

  // ───────────────────────── Bai giang CHUYEN SAU (version 2) ─────────────────────────
  // Hien TOM TAT truoc; cac phan con lai la ExpansionTile thu gon. Du lieu cu (khong co version) van di nhanh cu.
  Widget _buildDeepCard(Map<String, dynamic> d) {
    final nuance = d['nuance'] as Map<String, String>;
    final formula = d['formula'] as Map<String, dynamic>;
    final points = d['points'] as List<Map<String, dynamic>>;
    final mistakes = d['mistakes'] as List<Map<String, String>>;
    final cmp = d['comparison'] as Map<String, dynamic>;
    final examples = d['examples'] as List<Map<String, String>>;
    final practice = d['practice'] as List<Map<String, dynamic>>;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((d['title'] as String).isNotEmpty) Text(d['title'] as String,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green2, fontFamily: 'NotoSansTC')),
          if ((d['title'] as String).isNotEmpty) const SizedBox(height: 8),
          _sectionLabel('TÓM TẮT'),
          Text(d['summary'] as String, style: const TextStyle(fontSize: 15, color: _ink, height: 1.6)),
          if (d['partial'] == true) ...[
            const SizedBox(height: 10),
            const Text('Bài giảng này chưa qua đủ bước kiểm tra nên có thể thiếu một số mục.',
                style: TextStyle(fontSize: 12, color: _muted, fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      if (nuance.values.any((v) => v.isNotEmpty))
        _deepSection('Ý nghĩa & sắc thái', [
          _kv('Ý nghĩa cốt lõi', nuance['meaning']!), _kv('Khi nào dùng / không dùng', nuance['when_to_use']!),
          _kv('Sắc thái', nuance['tone']!), _kv('Văn nói & văn viết', nuance['spoken_vs_written']!),
          _kv('Đài Loan / vùng khác', nuance['regional']!),
        ]),
      if ((formula['affirmative'] as String).isNotEmpty)
        _deepSection('Công thức đầy đủ', [
          _formulaBox('Khẳng định', formula['affirmative'] as String),
          _formulaBox('Phủ định', formula['negative'] as String),
          _formulaBox('Nghi vấn', formula['interrogative'] as String),
          _kv('Vị trí trong câu', formula['position'] as String),
          if ((formula['variants'] as List<String>).isNotEmpty) ...[
            _sectionLabel('BIẾN THỂ'),
            ...(formula['variants'] as List<String>).map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $v', style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5, fontFamily: 'NotoSansTC')),
            )),
          ],
        ]),
      if (points.isNotEmpty)
        _deepSection('Điểm cần chú ý (${points.length})', points.asMap().entries.map((en) {
          final p = en.value;
          final ex = p['example'] as Map<String, String>;
          return Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${en.key + 1}. ${p['title']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              if ((p['explanation'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p['explanation'] as String, style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5)),
              ],
              if (ex['text']!.isNotEmpty) ...[const SizedBox(height: 8), _exampleLines(ex['text']!, ex['pinyin']!, ex['meaning']!)],
            ]),
          );
        }).toList()),
      if (mistakes.isNotEmpty)
        _deepSection('⚠️ Lỗi người Việt hay mắc (${mistakes.length})', mistakes.map((m) => Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF0EE), borderRadius: BorderRadius.circular(10),
              border: const Border(left: BorderSide(color: Color(0xFFFF3D57), width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('✗ ${m['wrong']}', style: const TextStyle(fontSize: 14.5, color: Color(0xFF8A2E26), fontFamily: 'NotoSansTC')),
            const SizedBox(height: 3),
            Text('✓ ${m['correct']}', style: const TextStyle(fontSize: 14.5, color: _green2, fontWeight: FontWeight.w700, fontFamily: 'NotoSansTC')),
            if ((m['why'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(m['why']!, style: const TextStyle(fontSize: 13, color: _ink, height: 1.5)),
            ],
          ]),
        )).toList()),
      if ((cmp['rows'] as List).isNotEmpty) _deepSection('So sánh cấu trúc dễ nhầm', [_comparisonTable(cmp)]),
      if (examples.isNotEmpty)
        _deepSection('Ví dụ từ dễ đến khó (${examples.length})', examples.map((e) => Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((e['level'] ?? '').isNotEmpty || (e['context'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text([_levelLabel(e['level'] ?? ''), e['context'] ?? ''].where((x) => x.isNotEmpty).join(' · '),
                    style: const TextStyle(fontSize: 11.5, color: _purple, fontWeight: FontWeight.w700)),
              ),
            _exampleLines(e['text']!, e['pinyin']!, e['meaning']!),
          ]),
        )).toList()),
      if (practice.isNotEmpty)
        _deepSection('Luyện tập nhanh (${practice.length})', practice.asMap().entries.map((en) {
          final i = en.key;
          final q = en.value;
          final shown = _shownAnswers.contains(i);
          return Container(
            width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${q['question']}', style: const TextStyle(fontSize: 14, color: _ink, height: 1.5, fontFamily: 'NotoSansTC')),
              ...(q['options'] as List<String>).map((o) => Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text(o, style: const TextStyle(fontSize: 14, color: _ink, height: 1.4, fontFamily: 'NotoSansTC')),
              )),
              const SizedBox(height: 6),
              if (!shown)
                TextButton(
                  key: Key('practice_show_$i'),
                  onPressed: () => setState(() => _shownAnswers.add(i)),
                  child: const Text('Xem đáp án'),
                )
              else
                Column(key: Key('practice_answer_$i'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Đáp án: ${q['answer']}',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _green2, fontFamily: 'NotoSansTC')),
                  if ((q['explanation'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(q['explanation']!, style: const TextStyle(fontSize: 13, color: _ink, height: 1.5)),
                  ],
                ]),
            ]),
          );
        }).toList()),
      _deepFooter(d),
    ]);
  }

  // Cuoi bai: canh bao AI + nut bao loi (ghi log phia backend de kiem tra chat luong sau).
  Widget _deepFooter(Map<String, dynamic> d) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const Text('Bài giảng do AI soạn, có thể có sai sót',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _muted, fontStyle: FontStyle.italic)),
      if ((d['key'] as String).isNotEmpty)
        TextButton.icon(
          key: const Key('report_button'),
          onPressed: () => _showReportDialog(d),
          icon: const Icon(Icons.flag_outlined, size: 16),
          label: const Text('Báo lỗi bài giảng'),
        ),
    ]),
  );

  Future<void> _showReportDialog(Map<String, dynamic> d) async {
    final controller = TextEditingController();
    String? err;
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Báo lỗi bài giảng'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chỗ nào trong bài giảng bị sai hoặc khó hiểu?', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('report_note'),
            controller: controller, maxLines: 4, maxLength: 1000, autofocus: true,
            decoration: InputDecoration(border: const OutlineInputBorder(), errorText: err, hintText: 'Ví dụ: câu 我吃了飯了 thực ra đúng'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            key: const Key('report_send'),
            onPressed: () {
              final t = controller.text.trim();
              if (t.length < 3) { setD(() => err = 'Vui lòng mô tả ngắn chỗ bị sai'); return; }
              Navigator.pop(ctx, t);
            },
            child: const Text('Gửi'),
          ),
        ],
      )),
    );
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await (widget.readToken ?? () => _storage.read(key: 'access_token'))();
      final dio = widget.dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 20)));
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tools/grammar/report',
        data: {'structure_key': d['key'], 'prompt_version': d['promptVersion'], 'note': note},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Đã gửi báo lỗi. Cảm ơn bạn!')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Chưa gửi được báo lỗi, thử lại nhé!')));
    }
  }

  Widget _deepSection(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
    // Material (khong phai DecoratedBox mau) lam nen: ListTile ben trong ExpansionTile ve nen/ink len Material gan nhat.
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey<String>('deep_$title'), // KHONG dung PageStorageKey: dung chung o luu voi SingleChildScrollView ngang cua bang so sanh (bool vs double -> crash)
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _ink)),
          children: children,
        ),
      ),
    ),
  );

  Widget _kv(String label, String value) => value.isEmpty ? const SizedBox.shrink() : Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel(label.toUpperCase()),
      Text(value, style: const TextStyle(fontSize: 14, color: _ink, height: 1.55)),
    ]),
  );

  Widget _formulaBox(String label, String value) => value.isEmpty ? const SizedBox.shrink() : Container(
    width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _green2, fontFamily: 'NotoSansTC')),
    ]),
  );

  Widget _exampleLines(String text, String pinyin, String meaning) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink, fontFamily: 'NotoSansTC', height: 1.5)),
    if (pinyin.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
        child: Text(pinyin, style: const TextStyle(fontSize: 12.5, color: _purple, height: 1.4))),
    if (meaning.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
        child: Text(meaning, style: const TextStyle(fontSize: 12.5, color: _muted, height: 1.4))),
  ]);

  Widget _comparisonTable(Map<String, dynamic> cmp) {
    final structures = cmp['structures'] as List<String>;
    final rows = cmp['rows'] as List<Map<String, dynamic>>;
    final cols = structures.isEmpty ? 1 : structures.length;
    const border = BorderSide(color: Color(0xFFE3E5EF));
    Widget cell(String t, {bool head = false}) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(t, style: TextStyle(fontSize: 12.5, height: 1.45, color: _ink,
          fontWeight: head ? FontWeight.w800 : FontWeight.w400, fontFamily: 'NotoSansTC')),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(170),
          columnWidths: const {0: FixedColumnWidth(95)},
          border: const TableBorder(horizontalInside: border, bottom: border, top: border, left: border, right: border, verticalInside: border),
          children: [
            TableRow(decoration: BoxDecoration(color: _purple.withOpacity(0.08)), children: [
              cell('Tiêu chí', head: true),
              for (var c = 0; c < cols; c++) cell(c < structures.length ? structures[c] : '', head: true),
            ]),
            for (final r in rows)
              TableRow(children: [
                cell(r['aspect'] as String, head: true),
                for (var c = 0; c < cols; c++)
                  cell(c < (r['values'] as List<String>).length ? (r['values'] as List<String>)[c] : ''),
              ]),
          ],
        ),
      ),
      if ((cmp['note'] as String).isNotEmpty) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Kết luận: ${cmp['note']}', style: const TextStyle(fontSize: 13.5, color: _ink, height: 1.5, fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  String _levelLabel(String l) => switch (l) { 'easy' => 'Dễ', 'medium' => 'Vừa', 'hard' => 'Khó', _ => '' };

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.4)),
  );
}

/// Doc an toan payload version 2 (bai giang chuyen sau). KHONG tin blind kieu du lieu (bai hoc 2026-10-06): moi truong
/// ep qua toString()/kiem tra kieu; phan tu sai kieu bi bo, khong lam vo ca man hinh. Public de test.
Map<String, dynamic> parseDeepGrammar(Map<String, dynamic> r) {
  String str(dynamic v) => v == null ? '' : v.toString().trim();
  List<dynamic> list(dynamic v) => v is List ? v : const [];
  Map<String, dynamic> map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  List<String> strs(dynamic v) => (v is List ? v : (v is String ? [v] : const [])).map(str).where((x) => x.isNotEmpty).toList();
  Map<String, String> example(dynamic e) {
    final m = map(e);
    return {'text': str(m['text']), 'pinyin': str(m['pinyin']), 'meaning': str(m['meaning'] ?? m['vi'])};
  }

  final nu = map(r['nuance']);
  final fo = map(r['formula_detail']);
  final cmp = map(r['comparison_table']);
  return {
    'title': str(r['title']),
    'key': str(r['key']),
    'promptVersion': r['prompt_version'] is int ? r['prompt_version'] : null,
    'summary': str(r['summary'] ?? r['definition']),
    'partial': r['partial'] == true,
    'nuance': <String, String>{for (final k in ['meaning', 'when_to_use', 'tone', 'spoken_vs_written', 'regional']) k: str(nu[k])},
    'formula': <String, dynamic>{
      'affirmative': str(fo['affirmative']), 'negative': str(fo['negative']), 'interrogative': str(fo['interrogative']),
      'position': str(fo['position']), 'variants': strs(fo['variants']),
    },
    'points': list(r['attention_points']).where((p) => p is Map).map((p) {
      final m = map(p);
      return <String, dynamic>{'title': str(m['title']), 'explanation': str(m['explanation']), 'example': example(m['example'])};
    }).where((p) => (p['title'] as String).isNotEmpty || (p['explanation'] as String).isNotEmpty).toList(),
    'mistakes': list(r['learner_mistakes']).where((m) => m is Map).map((m) {
      final x = map(m);
      return <String, String>{'wrong': str(x['wrong']), 'correct': str(x['correct']), 'why': str(x['why'])};
    }).where((m) => m['wrong']!.isNotEmpty || m['correct']!.isNotEmpty).toList(),
    'comparison': <String, dynamic>{
      'structures': strs(cmp['structures']),
      'note': str(cmp['note']),
      'rows': list(cmp['rows']).where((x) => x is Map).map((x) {
        final m = map(x);
        return <String, dynamic>{'aspect': str(m['aspect']), 'values': list(m['values']).map(str).toList()};
      }).where((x) => (x['aspect'] as String).isNotEmpty).toList(),
    },
    'examples': list(r['examples']).map((e) {
      if (e is String) return <String, String>{'level': '', 'context': '', 'text': str(e), 'pinyin': '', 'meaning': ''};
      final m = map(e);
      return <String, String>{'level': str(m['level']), 'context': str(m['context']), ...example(m)};
    }).where((e) => e['text']!.isNotEmpty).toList(),
    'practice': list(r['practice']).where((q) => q is Map).map((q) {
      final m = map(q);
      return <String, dynamic>{
        'question': str(m['question']), 'options': strs(m['options']),
        'answer': str(m['answer']), 'explanation': str(m['explanation']),
      };
    }).where((q) => (q['question'] as String).isNotEmpty).toList(),
  };
}
