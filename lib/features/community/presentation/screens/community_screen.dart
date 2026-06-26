// ═══════════════════════════════════════════════════════════════
// COMMUNITY SCREEN — Tab Cộng Đồng TaiwanMate
// Khớp với backend: app/api/v1/community.py (prefix /community)
// Chức năng: list bài (filter category/user_type/city/search),
//            đăng bài, báo cáo, cảnh báo scam, SOS khẩn cấp.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─── Design System (đồng bộ toàn app) ─────────────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const green = Color(0xFF00C853);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

const _baseUrl = 'https://taiwanmate-backend-production.up.railway.app/api/v1';

// Category: backend value ↔ nhãn hiển thị
const _categories = [
  {'value': 'job', 'label': 'Việc làm', 'icon': '💼'},
  {'value': 'housing', 'label': 'Nhà ở', 'icon': '🏠'},
  {'value': 'marketplace', 'label': 'Mua bán', 'icon': '🛒'},
  {'value': 'legal', 'label': 'Hỏi đáp', 'icon': '⚖️'},
];

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();

  String _userType = 'labor';          // labor | student
  String? _selectedCategory;            // null = tất cả
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Dio _dio() => Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

  Future<String?> _token() => _storage.read(key: 'access_token');

  Future<void> _loadPosts() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _token();
      final params = <String, dynamic>{
        'user_type': _userType,
        'country': 'TW',
      };
      if (_selectedCategory != null) params['category'] = _selectedCategory;
      if (_searchController.text.trim().isNotEmpty) {
        params['search'] = _searchController.text.trim();
      }
      final res = await _dio().get('/community/posts',
          queryParameters: params,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final list = List<Map<String, dynamic>>.from(res.data['posts'] ?? []);
      if (mounted) setState(() { _posts = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Không tải được bài đăng. Kéo để thử lại.'; _loading = false; });
    }
  }

  Future<void> _reportPost(int postId) async {
    try {
      final token = await _token();
      await _dio().post('/community/posts/$postId/report',
          data: {'post_id': postId, 'reason': 'scam'},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã báo cáo bài này. Cảm ơn bạn!'),
          backgroundColor: _DS.green,
        ));
        _loadPosts();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Lỗi báo cáo';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _DS.orange,
        onPressed: _openCreatePost,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Đăng bài', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildUserTypeToggle(),
          _buildSearch(),
          _buildCategoryFilter(),
          Expanded(child: _buildList()),
        ]),
      ),
    );
  }

  // ── Header với nút SOS ──────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(children: [
        const Text('CỘNG ĐỒNG',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.textDark, letterSpacing: -0.5)),
        const Spacer(),
        GestureDetector(
          onTap: _showSOSBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _DS.red,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: _DS.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.sos_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Toggle Lao động / Du học sinh ───────────────────────────
  Widget _buildUserTypeToggle() {
    Widget pill(String value, String label, String emoji) {
      final selected = _userType == value;
      return Expanded(
        child: GestureDetector(
          onTap: () { if (_userType != value) { setState(() => _userType = value); _loadPosts(); } },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: selected ? const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$emoji $label',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                    color: selected ? Colors.white : _DS.textGrey)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        pill('labor', 'Lao động', '👷'),
        pill('student', 'Du học sinh', '🎓'),
      ]),
    );
  }

  // ── Ô tìm kiếm ──────────────────────────────────────────────
  Widget _buildSearch() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: _DS.textGrey, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            onSubmitted: (_) => _loadPosts(),
            decoration: const InputDecoration(
              hintText: 'Tìm việc làm, nhà trọ, khu vực...',
              hintStyle: TextStyle(color: _DS.textGrey, fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_searchController.text.isNotEmpty)
          GestureDetector(
            onTap: () { _searchController.clear(); _loadPosts(); },
            child: const Icon(Icons.clear_rounded, color: _DS.textGrey, size: 18),
          ),
      ]),
    );
  }

  // ── Filter category ─────────────────────────────────────────
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        children: [
          _catChip(null, '🌐', 'Tất cả'),
          ..._categories.map((c) => _catChip(c['value'], c['icon']!, c['label']!)),
        ],
      ),
    );
  }

  Widget _catChip(String? value, String icon, String label) {
    final selected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => _selectedCategory = value); _loadPosts(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _DS.orange : _DS.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? _DS.orange : _DS.textGrey.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _DS.textDark)),
          ]),
        ),
      ),
    );
  }

  // ── Danh sách bài ───────────────────────────────────────────
  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _DS.orange));
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: _error != null
          ? ListView(children: [const SizedBox(height: 120), Center(child: Text(_error!, style: const TextStyle(color: _DS.textGrey)))])
          : _posts.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 100),
                  Center(child: Text('📭', style: TextStyle(fontSize: 48))),
                  SizedBox(height: 12),
                  Center(child: Text('Chưa có bài đăng nào', style: TextStyle(color: _DS.textGrey, fontWeight: FontWeight.w600))),
                  SizedBox(height: 4),
                  Center(child: Text('Hãy là người đầu tiên đăng bài!', style: TextStyle(color: _DS.textGrey, fontSize: 12))),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: _posts.length,
                  itemBuilder: (context, i) => _buildPostCard(_posts[i]),
                ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> p) {
    final scam = p['scam_detection'] as Map<String, dynamic>?;
    final warnings = scam != null ? List<String>.from(scam['warnings'] ?? []) : <String>[];
    final cat = _categories.firstWhere((c) => c['value'] == p['category'],
        orElse: () => {'icon': '📝', 'label': ''});

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Hàng đầu: category + thời gian + báo cáo
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
            child: Text('${cat['icon']} ${cat['label']}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _DS.orange)),
          ),
          const Spacer(),
          Text(p['time_ago'] as String? ?? '', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmReport(p['id'] as int),
            child: const Icon(Icons.flag_outlined, size: 16, color: _DS.textGrey),
          ),
        ]),
        const SizedBox(height: 10),
        // Cảnh báo scam
        if (warnings.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: _DS.redLight, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings.map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(w, style: const TextStyle(fontSize: 11, color: _DS.red, fontWeight: FontWeight.w600)),
                )).toList()),
          ),
        ],
        // Tiêu đề + nội dung
        Text(p['title'] as String? ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark, height: 1.3)),
        const SizedBox(height: 6),
        Text(p['content'] as String? ?? '',
            style: const TextStyle(fontSize: 13, color: _DS.textGrey, height: 1.5)),
        // Thông tin phụ
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if ((p['city'] as String? ?? '').isNotEmpty) _infoTag(Icons.location_on_outlined, p['city']),
          if ((p['salary'] as String? ?? '').isNotEmpty) _infoTag(Icons.payments_outlined, p['salary']),
          if ((p['price'] as String? ?? '').isNotEmpty) _infoTag(Icons.sell_outlined, p['price']),
          if ((p['work_hours'] as String? ?? '').isNotEmpty) _infoTag(Icons.schedule_outlined, p['work_hours']),
        ]),
        if ((p['contact'] as String? ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.contact_phone_outlined, size: 16, color: _DS.blue),
              const SizedBox(width: 8),
              Text('Liên hệ: ${p['contact']}',
                  style: const TextStyle(fontSize: 13, color: _DS.blue, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Text('— ${p['author_name'] ?? 'Ẩn danh'}',
            style: const TextStyle(fontSize: 11, color: _DS.textGrey, fontStyle: FontStyle.italic)),
      ]),
    );
  }

  Widget _infoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _DS.textGrey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: _DS.textDark, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  void _confirmReport(int postId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Báo cáo bài này?'),
      content: const Text('Báo cáo bài có dấu hiệu lừa đảo/giả mạo. Bài bị báo cáo 3 lần sẽ tự động ẩn.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); _reportPost(postId); },
          child: const Text('Báo cáo', style: TextStyle(color: _DS.red, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  // ── SOS bottom sheet ────────────────────────────────────────
  Future<void> _showSOSBottomSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _SOSContent(scrollController: scrollCtrl, storage: _storage),
        ),
      ),
    );
  }

  // ── Đăng bài ────────────────────────────────────────────────
  void _openCreatePost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CreatePostSheet(
        userType: _userType,
        storage: _storage,
        onPosted: () { Navigator.pop(context); _loadPosts(); },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SOS CONTENT — gọi GET /community/sos
// ═══════════════════════════════════════════════════════════════
class _SOSContent extends StatefulWidget {
  final ScrollController scrollController;
  final FlutterSecureStorage storage;
  const _SOSContent({required this.scrollController, required this.storage});
  @override
  State<_SOSContent> createState() => _SOSContentState();
}

class _SOSContentState extends State<_SOSContent> {
  List<Map<String, dynamic>> _numbers = [];
  List<String> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await widget.storage.read(key: 'access_token');
      final res = await Dio().get('$_baseUrl/community/sos',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (mounted) setState(() {
        _numbers = List<Map<String, dynamic>>.from(res.data['emergency_numbers'] ?? []);
        _notes = List<String>.from(res.data['important_notes'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.sos_rounded, color: _DS.red),
          SizedBox(width: 8),
          Text('Số khẩn cấp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _DS.textDark)),
        ]),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _DS.red))
            : ListView(controller: widget.scrollController, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
                ..._numbers.map((n) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(_DS.radiusSm)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textDark, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(n['note'] as String? ?? '', style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _DS.red, borderRadius: BorderRadius.circular(20)),
                      child: Text(n['number'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ]),
                )),
                if (_notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(_DS.radiusSm)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('💡 Lưu ý quan trọng', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.orange, fontSize: 13)),
                      const SizedBox(height: 8),
                      ..._notes.map((note) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• $note', style: const TextStyle(fontSize: 12, color: _DS.textDark, height: 1.4)),
                      )),
                    ]),
                  ),
                ],
              ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// CREATE POST SHEET — gọi POST /community/posts
// ═══════════════════════════════════════════════════════════════
class _CreatePostSheet extends StatefulWidget {
  final String userType;
  final FlutterSecureStorage storage;
  final VoidCallback onPosted;
  const _CreatePostSheet({required this.userType, required this.storage, required this.onPosted});
  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  String _category = 'job';
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _city = TextEditingController();
  final _contact = TextEditingController();
  final _salary = TextEditingController();
  final _price = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose(); _content.dispose(); _city.dispose();
    _contact.dispose(); _salary.dispose(); _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tiêu đề tối thiểu 5 ký tự')));
      return;
    }
    if (_content.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nội dung tối thiểu 10 ký tự')));
      return;
    }
    if (_city.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập khu vực')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final token = await widget.storage.read(key: 'access_token');
      await Dio().post('$_baseUrl/community/posts',
        data: {
          'category': _category,
          'user_type': widget.userType,
          'country': 'TW',
          'city': _city.text.trim(),
          'title': _title.text.trim(),
          'content': _content.text.trim(),
          'contact': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
          'salary': _salary.text.trim().isEmpty ? null : _salary.text.trim(),
          'price': _price.text.trim().isEmpty ? null : _price.text.trim(),
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}));
      if (mounted) widget.onPosted();
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Lỗi đăng bài';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$msg')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Đăng bài mới', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 16),
            // Chọn category
            Wrap(spacing: 8, children: _categories.map((c) {
              final sel = _category == c['value'];
              return GestureDetector(
                onTap: () => setState(() => _category = c['value']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _DS.orange : _DS.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${c['icon']} ${c['label']}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _DS.textDark)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            _field(_title, 'Tiêu đề *', 'VD: Tuyển công nhân điện tử Đào Viên'),
            _field(_content, 'Nội dung *', 'Mô tả chi tiết...', maxLines: 4),
            _field(_city, 'Khu vực *', 'VD: Đào Viên'),
            _field(_contact, 'Liên hệ (SĐT/LINE)', 'Tuỳ chọn'),
            if (_category == 'job') _field(_salary, 'Mức lương', 'VD: 28000 NTD/tháng'),
            if (_category == 'marketplace' || _category == 'housing')
              _field(_price, 'Giá', 'VD: 8000 NTD/tháng'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Đăng bài', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textDark)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _DS.textGrey, fontSize: 13),
            filled: true,
            fillColor: _DS.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }
}