import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/tools/presentation/screens/grammar_tool_screen.dart';

/// Audit chuan bi Phase 2 (2026-09-30, muc F) — 2 thay doi so voi ban goc:
///
/// 1. Trang thai RONG (da so user hien tai — audit production luc viet chi ~10/tong so user co
///    BAT KY diem mastery nao): truoc day chi la 1 dong text nhac Boss/Chat (da lac hau tu khi
///    Phase 1 them SRS/unit lam nguon), khong co hanh dong nao ca. Gio doi noi dung + them 1 nut
///    CTA DUY NHAT "Học ngay" -> mo CurriculumTab — con duong sinh diem mastery dau tien NHANH
///    NHAT hien co the mo tu file nay ma khong them do phuc tap dang ke (ngay ca man "On tap
///    nhanh"/SRS thuan tuy — quick_review_screen.dart — can 9 tham so + danh sach tu vung tai
///    truoc trong _LearnScreenState, khong the mo thang tu day; CurriculumTab thi mo duoc
///    KHONG THAM SO nhu chinh learn_hub_tab.dart dang lam).
/// 2. Danh sach CO du lieu: GOM NHOM theo feature_type backend tra ve (them o /mastery/profile
///    cung dot audit nay — xem app/api/v1/mastery.py) + GIOI HAN hien thi (nut "Xem them" moi
///    nhom) + CTA bam duoc cho dong CO dich hanh dong that (dung field feature_type/reference_id/
///    cta_text da co san tu backend, KHONG tu hardcode lai 1 ban sao bang topic_feature_mapping
///    o day — tranh 2 nguon su that lech nhau ve sau).
class MasteryProfileTab extends StatefulWidget {
  // Chi de test: thay phu thuoc mang/luu tru/dieu huong (dung y het mau da co o placement_card.dart).
  final Dio? dio;
  final Future<String?> Function()? readToken;
  final VoidCallback? onOpenCurriculum;
  final void Function(Map<String, dynamic> topic)? onCta;

  const MasteryProfileTab({super.key, this.dio, this.readToken, this.onOpenCurriculum, this.onCta});
  @override
  State<MasteryProfileTab> createState() => _MasteryProfileTabState();
}

// Thu tu nhom co dinh (KHONG theo thu tu xuat hien trong response) de UI on dinh giua cac lan
// tai — "Tu vung" dung dau vi la nguon THUONG XUYEN nhat (SRS/unit).
const _kGroupOrder = ['Từ vựng', 'Ngữ pháp', 'Đấu Trường Boss', 'Thi thử', 'Khác'];
const _kCollapsedLimit = 5; // moi nhom hien toi da 5 dong truoc khi can bam "Xem them"

String groupForMasteryTopic(Map<String, dynamic> t) {
  switch (t['feature_type']) {
    case 'boss_arena':
      return 'Đấu Trường Boss';
    case 'grammar_tool':
      return 'Ngữ pháp';
  }
  final tag = (t['topic_tag'] ?? '') as String;
  if (tag.startsWith('vocab_')) return 'Từ vựng';
  if (tag.startsWith('skill_')) return 'Thi thử';
  return 'Khác'; // du phong — khong co tag nao hien tai roi vao day
}

class _MasteryProfileTabState extends State<MasteryProfileTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _storage = FlutterSecureStorage();
  late final Dio _dio = widget.dio ?? Dio();
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _expandedGroups = {};

  static const _purple = Color(0xFF5B5FEF);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF0F4FF);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await (widget.readToken ?? () => _storage.read(key: 'access_token'))();
      final res = await _dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/mastery/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _topics = List<Map<String, dynamic>>.from(res.data['topics'] ?? []);
      });
    } catch (e) {
      setState(() => _error = 'Không tải được dữ liệu, thử lại nhé.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _colorForScore(double score) {
    if (score >= 70) return const Color(0xFF00C853);
    if (score >= 40) return const Color(0xFFFFB300);
    return const Color(0xFFFF3D57);
  }

  void _openCurriculum() {
    if (widget.onOpenCurriculum != null) {
      widget.onOpenCurriculum!();
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        title: const Text('Lộ trình học',
            style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: const CurriculumTab(),
    )));
  }

  void _handleCta(Map<String, dynamic> t) {
    if (widget.onCta != null) {
      widget.onCta!(t);
      return;
    }
    switch (t['feature_type']) {
      case 'grammar_tool':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => GrammarToolScreen(initialQuery: t['reference_id'] as String?),
        ));
        return;
      case 'boss_arena':
        // Dau Truong Boss song trong tab "Dau Truong" (route /live, xem app_router.dart) — CHUA
        // co loi vao cong khai thang toi 1 tran dau cu the tu ngoai file do (man hinh tran dau
        // la widget rieng trong live_chat_screen.dart), nen dieu huong toi dung TAB thay vi co
        // mo thang tran dau — don gian, an toan, khong dong vao file live_chat_screen.dart on
        // dinh chi de phuc vu 1 nut CTA phu o day.
        context.go('/live');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _purple));
    }

    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: _textGrey)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(12)),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]));
    }

    if (_topics.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Năng lực của bạn sẽ hiện ở đây khi bạn bắt đầu học',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textDark, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mỗi từ vựng, mỗi bài luyện đều được tính — chưa cần đạt gì to tát, cứ học là có.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textGrey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _openCurriculum,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Học ngay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ]),
      ));
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in _topics) {
      grouped.putIfAbsent(groupForMasteryTopic(t), () => []).add(t);
    }
    final orderedGroups = [
      ..._kGroupOrder.where(grouped.containsKey),
      ...grouped.keys.where((g) => !_kGroupOrder.contains(g)), // du phong, khong bo sot nhom la
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          for (final group in orderedGroups) ..._buildGroupSection(group, grouped[group]!),
        ],
      ),
    );
  }

  List<Widget> _buildGroupSection(String group, List<Map<String, dynamic>> items) {
    final expanded = _expandedGroups.contains(group);
    final visible = expanded ? items : items.take(_kCollapsedLimit).toList();
    final hiddenCount = items.length - visible.length;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(group, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textGrey)),
      ),
      for (final t in visible) _buildTopicCard(t),
      if (hiddenCount > 0)
        GestureDetector(
          onTap: () => setState(() => _expandedGroups.add(group)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Xem thêm ($hiddenCount)',
                style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      const SizedBox(height: 6),
    ];
  }

  Widget _buildTopicCard(Map<String, dynamic> t) {
    final score = (t['mastery_score'] as num).toDouble();
    final color = _colorForScore(score);
    final ctaText = t['cta_text'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t['label'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark))),
          Text('${score.round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (ctaText != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _handleCta(t),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(ctaText, style: const TextStyle(color: _purple, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 16, color: _purple),
            ]),
          ),
        ],
      ]),
    );
  }
}
