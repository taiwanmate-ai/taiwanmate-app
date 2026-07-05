import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/services/payment_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/providers/theme_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../manual_payment_screen.dart';
import 'package:chinesemate/core/state/user_state.dart';

// ─── Design System ────────────────────────────────────────────
class _DS {
 static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const yellow = Color(0xFFFFB300);
  static const yellowLight = Color(0xFFFFF8E1);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const purple = Color(0xFF7C4DFF);
  static const purpleLight = Color(0xFFEDE7F6);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

// ─── Badge data ───────────────────────────────────────────────
class _Badge {
  final String emoji, name, desc;
  final bool unlocked;
  const _Badge({required this.emoji, required this.name, required this.desc, required this.unlocked});
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _avatarUrl;
  final _linkController = TextEditingController();
  late TabController _tabCtrl;

   Future<void> _callDeleteAccount(BuildContext context) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;

    final res = await http.delete(
      Uri.parse('https://taiwanmate-backend-production.up.railway.app/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'avatar_url');
      if (context.mounted) context.go('/login');
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa tài khoản thất bại. Thử lại sau.')),
        );
      }
    }
  }
  

Future<void> _showDeleteConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xóa tài khoản?'),
      content: const Text('Toàn bộ dữ liệu học tập sẽ bị xóa vĩnh viễn, không thể hoàn tác.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Tiếp tục'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final doubleConfirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Xác nhận lần cuối'),
      content: const Text('Bạn chắc chắn? Dữ liệu không thể khôi phục.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không, giữ lại')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Xóa tài khoản', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (doubleConfirmed != true || !context.mounted) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  await _callDeleteAccount(context);
  if (context.mounted) {
    Navigator.of(context).pop(); // đóng loading dialog trước
    context.go('/login');
 }
}
  // Stats từ user data
  int get _streak => (_user?['streak_days'] as num?)?.toInt() ?? 0;
  int get _totalXp => (_user?['total_xp'] as num?)?.toInt() ?? 0;
  String get _subscription => _user?['subscription'] ?? 'free';
  bool get _isVip => _subscription == 'vip';
  String get _level => _user?['chinese_level'] ?? 'beginner';

  // Tính level label
  String get _levelLabel {
    switch (_level) {
      case 'beginner': return 'Người mới bắt đầu';
      case 'basic': return 'Cơ bản';
      case 'intermediate': return 'Trung cấp';
      default: return 'Người mới';
    }
  }

  // XP cần để lên level tiếp
  int get _xpForNextLevel {
    if (_totalXp < 500) return 500;
    if (_totalXp < 2000) return 2000;
    if (_totalXp < 5000) return 5000;
    return 10000;
  }

  int get _xpPrevLevel {
    if (_totalXp < 500) return 0;
    if (_totalXp < 2000) return 500;
    if (_totalXp < 5000) return 2000;
    return 5000;
  }

  String get _rankLabel {
    if (_totalXp >= 5000) return '🥇 Cao thủ';
    if (_totalXp >= 2000) return '🥈 Nâng cao';
    if (_totalXp >= 500) return '🥉 Cơ bản';
    return '🌱 Mới bắt đầu';
  }

  List<_Badge> get _badges => [
    _Badge(emoji: '🔥', name: 'Streak 7 ngày', desc: 'Học 7 ngày liên tiếp', unlocked: _streak >= 7),
    _Badge(emoji: '⭐', name: 'XP 500', desc: 'Đạt 500 XP', unlocked: _totalXp >= 500),
    _Badge(emoji: '📚', name: 'Học viên', desc: 'Hoàn thành buổi học đầu tiên', unlocked: _totalXp > 0),
    _Badge(emoji: '🎯', name: 'Streak 30 ngày', desc: 'Học 30 ngày liên tiếp', unlocked: _streak >= 30),
    _Badge(emoji: '💎', name: 'VIP Member', desc: 'Nâng cấp lên VIP', unlocked: _isVip),
    _Badge(emoji: '🏆', name: 'Cao thủ', desc: 'Đạt 5000 XP', unlocked: _totalXp >= 5000),
    _Badge(emoji: '🗣️', name: 'Người trò chuyện', desc: 'Chat với AI 50 lần', unlocked: false),
    _Badge(emoji: '🇹🇼', name: 'Người Đài Loan', desc: 'Hoàn thành 100 từ vựng', unlocked: false),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadProfile();
    _loadAvatar();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('avatar_url');
    setState(() => _avatarUrl = avatar);
  }

  Future<void> _loadProfile() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _user = response.data);
      UserState.updateVipStatus(_user?['subscription'] == 'vip');
    } catch (e) {
      setState(() => _user = {'email': 'user@gmail.com', 'full_name': 'Người dùng', 'streak_days': 0, 'total_xp': 0, 'subscription': 'free'});
      UserState.updateVipStatus(false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Đăng xuất?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.textDark)),
            const SizedBox(height: 8),
            const Text('Bạn có chắc muốn đăng xuất không?', textAlign: TextAlign.center, style: TextStyle(color: _DS.textGrey)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Hủy', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textGrey)),
                ),
              )),
              
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await _storage.delete(key: 'access_token');
                  if (mounted) context.go('/login');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: _DS.red, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Đăng xuất', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickImageFromFile() async {
  final base64 = await webPickImage();
  if (base64 == null) return;
  final dataUrl = 'data:image/jpeg;base64,$base64';
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('avatar_url', dataUrl);
  if (mounted) {
    setState(() => _avatarUrl = dataUrl);
    Navigator.pop(context);
  }
}

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(24)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Ảnh đại diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textDark)),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _DS.blueLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.upload_file_rounded, color: _DS.blue)),
            title: const Text('Tải từ máy tính', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () { Navigator.pop(context); _pickImageFromFile(); },
          ),
          if (_avatarUrl != null)
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _DS.redLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_rounded, color: _DS.red)),
              title: const Text('Xóa ảnh', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.red)),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('avatar_url');
                setState(() => _avatarUrl = null);
                if (mounted) Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  ImageProvider? get _avatarImage {
    if (_avatarUrl == null) return null;
    if (_avatarUrl!.startsWith('data:')) return MemoryImage(base64Decode(_avatarUrl!.split(',')[1]));
    return NetworkImage(_avatarUrl!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _DS.orange))
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(children: [
                  _buildHeader(),
                  _buildStatsRow(),
                  _buildXpProgress(),
                  _buildTabBar(),
                  _buildTabContent(),
                ]),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1A1D2E), Color(0xFF2D3250)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(children: [
          // Top row
          Row(children: [
            const Text('Hồ sơ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
            const Spacer(),
            if (_isVip)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('⭐', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 4),
                  Text('VIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
          ]),
          const SizedBox(height: 20),

          // Avatar + info
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.40,
                maxHeight: MediaQuery.of(context).size.height * 0.15,
              ),
              child: Image.asset(
                'assets/images/Profile_pic-amico.webp',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(
              onTap: _showAvatarOptions,
              child: Stack(children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
                    boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: _avatarImage != null
                      ? ClipOval(child: Image(image: _avatarImage!, fit: BoxFit.cover))
                      : Center(child: Text(
                          (_user?['full_name'] ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                        )),
                ),
                Positioned(bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: _DS.orange, shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1A1D2E), width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                    )),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_user?['full_name'] ?? 'Người dùng',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text(_user?['email'] ?? '', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(_rankLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ])),
          ]),
        ]),
      ),
    );
  }

  Widget _buildStatsRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(children: [
      Expanded(child: _buildStatCard('🔥', '$_streak', 'Ngày liên tiếp', _DS.orange, _DS.orangeLight)),
      const SizedBox(width: 10),
      Expanded(child: _buildStatCard('⭐', '$_totalXp', 'Tổng XP', _DS.yellow, _DS.yellowLight)),
      const SizedBox(width: 10),
      Expanded(child: _buildStatCard('📚', _levelLabel.split(' ').first, 'Trình độ', _DS.blue, _DS.blueLight)),
    ]),
  );

  Widget _buildStatCard(String emoji, String value, String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 24)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: _DS.textGrey, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ]),
  );

  Widget _buildXpProgress() {
    final xpInLevel = _totalXp - _xpPrevLevel;
    final xpNeeded = _xpForNextLevel - _xpPrevLevel;
    final progress = xpInLevel / xpNeeded;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_rankLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.textDark)),
            const Spacer(),
            Text('$_totalXp / ${_xpForNextLevel} XP', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.orange)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 10,
                  backgroundColor: _DS.orange.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(_DS.orange))),
          const SizedBox(height: 6),
          Text('Cần thêm ${_xpForNextLevel - _totalXp} XP để lên cấp tiếp theo',
              style: const TextStyle(fontSize: 11, color: _DS.textGrey)),
        ]),
      ),
    );
  }

  Widget _buildTabBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: _DS.textGrey,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🏅', style: TextStyle(fontSize: 14)), SizedBox(width: 4), Text('Huy hiệu')])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('⚙️', style: TextStyle(fontSize: 14)), SizedBox(width: 4), Text('Cài đặt')])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('👤', style: TextStyle(fontSize: 14)), SizedBox(width: 4), Text('Tài khoản')])),
        ],
      ),
    ),
  );

  Widget _buildTabContent() {
    return SizedBox(
      height: 500,
      child: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBadgesTab(),
          _buildSettingsTab(),
          _buildAccountTab(),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Huy hiệu của bạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _DS.textDark)),
        const Spacer(),
        Text('${_badges.where((b) => b.unlocked).length}/${_badges.length}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.orange)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
          ),
          itemCount: _badges.length,
          itemBuilder: (_, i) {
            final b = _badges[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: b.unlocked ? _DS.white : _DS.bg,
                borderRadius: BorderRadius.circular(_DS.radiusSm),
                border: Border.all(color: b.unlocked ? _DS.orange.withOpacity(0.3) : Colors.grey.shade200),
                boxShadow: b.unlocked ? [BoxShadow(color: _DS.orange.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text(b.emoji, style: TextStyle(fontSize: 24, color: b.unlocked ? null : const Color(0xFFBBBBBB))),
                  const Spacer(),
                  if (b.unlocked) Container(width: 8, height: 8, decoration: const BoxDecoration(color: _DS.green, shape: BoxShape.circle)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                      color: b.unlocked ? _DS.textDark : _DS.textGrey)),
                  Text(b.desc, style: TextStyle(fontSize: 10, color: b.unlocked ? _DS.textGrey : _DS.textGrey.withOpacity(0.5)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ]),
            );
          },
        ),
      ),
    ]),
  );

  Widget _buildSettingsTab() {
    final themeState = ref.watch(themeProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // VIP card
        if (!_isVip) ...[
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VipScreen()),
            ),
            child: Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(_DS.radiusSm),
                boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Text('⭐', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nâng cấp VIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('Chat không giới hạn · Dịch ảnh · Tìm việc AI', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('NT\$199/tháng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _DS.orange))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Theme colors
        const Text('Màu chủ đạo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Wrap(spacing: 10, runSpacing: 10,
            children: themeColors.map((tc) {
              final color = tc['color'] as Color;
              final isSelected = themeState.primaryColor.value == color.value;
              return GestureDetector(
                onTap: () => ref.read(themeProvider.notifier).setColor(color),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 3),
                        boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)] : []),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Dark mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            const Icon(Icons.dark_mode_rounded, color: _DS.textGrey),
            const SizedBox(width: 12),
            const Expanded(child: Text('Giao diện tối', style: TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark))),
            Switch(value: themeState.themeMode == ThemeMode.dark, activeColor: _DS.orange,
                onChanged: (v) => ref.read(themeProvider.notifier).setThemeMode(v ? ThemeMode.dark : ThemeMode.light)),
          ]),
        ),
        const SizedBox(height: 14),

        // Notifications
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Row(children: [
            const Icon(Icons.notifications_rounded, color: _DS.textGrey),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nhắc nhở học tập', style: TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark)),
              Text('Nhắc lúc 8h tối mỗi ngày', style: TextStyle(fontSize: 11, color: _DS.textGrey)),
            ])),
            Switch(value: true, activeColor: _DS.orange, onChanged: (_) {}),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAccountTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      // Account info
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          _infoRow('📧', 'Email', _user?['email'] ?? ''),
          const Divider(height: 24),
          _infoRow('👤', 'Tên', _user?['full_name'] ?? 'Người dùng'),
          const Divider(height: 24),
          _infoRow('⭐', 'Gói dùng', _isVip ? 'VIP' : 'Miễn phí'),
          const Divider(height: 24),
          _infoRow('📊', 'Trình độ', _levelLabel),
        ]),
      ),
      const SizedBox(height: 16),

      // App info
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          _infoRow('📱', 'Phiên bản', 'v1.0.0'),
          const Divider(height: 24),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://taiwanmate-ai.github.io/taiwanmate-legal')),
            child: Row(children: [
              const Text('📄', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Chính sách bảo mật', style: TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark))),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _DS.textGrey),
            ]),
          ),
          const Divider(height: 24),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse('https://taiwanmate-ai.github.io/taiwanmate-legal')),
            child: Row(children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Điều khoản sử dụng', style: TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark))),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _DS.textGrey),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),

      // Logout button
      GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: _DS.red.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: _DS.red, size: 20),
            SizedBox(width: 8),
            Text('Đăng xuất', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.red)),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // Xóa tài khoản
      GestureDetector(
        onTap: () => _showDeleteConfirmDialog(context),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            border: Border.all(color: _DS.red.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.delete_forever_outlined, color: _DS.red, size: 20),
            SizedBox(width: 8),
            Text('Xóa tài khoản', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _DS.red)),
          ]),
        ),
      ),
      const SizedBox(height: 20),
    ]),
  );

  Widget _infoRow(String emoji, String label, String value) => Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(width: 12),
    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: _DS.textDark))),
    Text(value, style: const TextStyle(fontSize: 13, color: _DS.textGrey, fontWeight: FontWeight.w600)),
  ]);
}

// ═══════════════════════════════════════════════════════════════
// VIP SCREEN
// ═══════════════════════════════════════════════════════════════
class VipScreen extends StatelessWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      body: SingleChildScrollView(
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7A2E00), Color(0xFFFF6B35), Color(0xFFFFB300)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              const Text('⭐', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('ChineseMate VIP', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Mở khóa toàn bộ tính năng · Hỗ trợ không giới hạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85))),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // So sánh Free vs VIP
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1500),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _DS.orange.withOpacity(0.3)),
                ),
                child: Column(children: [
                  // Header bảng
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _DS.orange.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(children: [
                      const Expanded(flex: 3, child: Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text('Tính năng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                      )),
                      Expanded(child: Center(child: Text('Free', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white54)))),
                      Expanded(child: Center(child: Text('VIP ⭐', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _DS.yellow)))),
                    ]),
                  ),
                  // Rows
                  ...[
                    ['Chat AI 小美', '40 lần/ngày', 'Không giới hạn'],
                    ['Dịch văn bản', '50 lần/ngày', 'Không giới hạn'],
                    ['Dịch ảnh & hợp đồng', '15 lần/ngày', 'Không giới hạn'],
                    ['Dịch giọng nói', '15 lần/ngày', 'Không giới hạn'],
                    ['AI Tools (15 công cụ)', '15 lần/ngày', 'Không giới hạn'],
                    ['Phân tích hợp đồng AI', '❌', '✅ Chi tiết'],
                    ['Tư vấn du học A-Z', '❌', '✅ Đầy đủ'],
                    ['Lộ trình học tập VIP', '❌', '✅'],
                    ['Học từ vựng/Quiz', '✅', '✅'],
                  ].asMap().entries.map((e) {
                    final i = e.key;
                    final row = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: i.isOdd ? Colors.white.withOpacity(0.03) : Colors.transparent,
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(row[0], style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500))),
                        Expanded(child: Center(child: Text(row[1], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.w500)))),
                        Expanded(child: Center(child: Text(row[2], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _DS.yellow, fontWeight: FontWeight.w700)))),
                      ]),
                    );
                  }),
                ]),
              ),

              const SizedBox(height: 24),

              // Giá
              Row(children: [
                // Gói tháng
                Expanded(child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1500),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(children: [
                    const Text('Tháng', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('NT\$199', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Text('/tháng', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ]),
                )),
                const SizedBox(width: 12),
                // Gói năm — nổi bật hơn
                Expanded(child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Tiết kiệm 37%', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    const Text('NT\$1,499', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    const Text('/năm', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ]),
                )),
              ]),

              const SizedBox(height: 20),

              // Nút mua — kết nối Lemon Squeezy
              // Nút gói tháng
GestureDetector(
  onTap: () async {
    if (kIsWeb) {
      PaymentService.openCheckout(plan: 'monthly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/33e90daf-ec9a-4ae7-88b9-5221d20c22d1');
    } else {
      await PaymentService.purchaseAndroid(
        plan: 'monthly',
        onSuccess: () {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Nâng cấp VIP thành công!'), backgroundColor: _DS.green),
            );
          }
        },
        onError: (msg) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
    }
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: const Color(0xFF2A1500),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _DS.orange.withOpacity(0.6)),
    ),
    child: const Text('Gói tháng — NT\$199/tháng',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
  ),
),
const SizedBox(height: 12),
// Nút gói năm — nổi bật hơn
GestureDetector(
  onTap: () async {
    if (kIsWeb) {
      PaymentService.openCheckout(plan: 'yearly', fallbackUrl: 'https://taiwanmate-ai.lemonsqueezy.com/checkout/buy/f8fef26c-2235-4bf1-8e04-02252d8e9dac');
    } else {
      await PaymentService.purchaseAndroid(
        plan: 'yearly',
        onSuccess: () {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Nâng cấp VIP thành công!'), backgroundColor: _DS.green),
            );
          }
        },
        onError: (msg) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
      );
    }
  },
  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [_DS.orange, _DS.yellow]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: const Text('Gói năm — NT\$1,499/năm ⭐ Tiết kiệm 37%',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
  ),
),
              const SizedBox(height: 16),
              Row(children: const [
                Expanded(child: Divider(color: Colors.white24)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('hoặc', style: TextStyle(color: Colors.white38))),
                Expanded(child: Divider(color: Colors.white24)),
              ]),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPaymentScreen())),
                child: Container(
                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text('Chuyển khoản ngân hàng (QR)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // Voucher 24h
              const _VoucherCountdown(),
              const SizedBox(height: 20),

              // Cam kết
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _VipBadge(icon: '🔒', label: 'Thanh toán\nan toàn'),
                _VipBadge(icon: '↩️', label: 'Hoàn tiền\n7 ngày'),
                _VipBadge(icon: '⚡', label: 'Kích hoạt\ntức thì'),
                _VipBadge(icon: '🇻🇳', label: 'Hỗ trợ\ntiếng Việt'),
              ]),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  if (kIsWeb) return;
                  await PaymentService.restorePurchases(
                    onSuccess: () {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Đã khôi phục VIP thành công!'), backgroundColor: _DS.green),
                        );
                      }
                    },
                    onError: (msg) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    },
                  );
                },
                child: const Text('Đã mua rồi? Khôi phục giao dịch', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Để sau', style: TextStyle(color: Colors.white54)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  final String icon, label;
  const _VipBadge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 24)),
    const SizedBox(height: 4),
    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w600)),
  ]);
}

class _VoucherCountdown extends StatefulWidget {
  const _VoucherCountdown();
  @override
  State<_VoucherCountdown> createState() => _VoucherCountdownState();
}
 
class _VoucherCountdownState extends State<_VoucherCountdown> {
  static const _storage = FlutterSecureStorage();
  static const _installKey = 'install_date';
  static const _voucherDays = 15; // số ngày voucher có hiệu lực
 
  int? _daysLeft; // null = đang load
  bool _expired = false;
 
  // Màu vàng đồng bộ với _DS.yellow (0xFFFFD166)
  static const _yellow = Color(0xFFFFD166);
 
  @override
  void initState() {
    super.initState();
    _initVoucher();
  }
 
  Future<void> _initVoucher() async {
    try {
      String? raw = await _storage.read(key: _installKey);
      DateTime installDate;
      if (raw == null) {
        // Lần đầu mở app → ghi ngày cài là hôm nay
        installDate = DateTime.now();
        await _storage.write(key: _installKey, value: installDate.toIso8601String());
      } else {
        installDate = DateTime.parse(raw);
      }
      final passed = DateTime.now().difference(installDate).inDays;
      final left = _voucherDays - passed;
      if (mounted) {
        setState(() {
          if (left < 0) {
            _expired = true;
          } else {
            _daysLeft = left;
          }
        });
      }
    } catch (_) {
      // Lỗi storage → ẩn voucher cho an toàn
      if (mounted) setState(() => _expired = true);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    if (_expired) return const SizedBox.shrink();        // hết hạn → ẩn
    if (_daysLeft == null) return const SizedBox.shrink(); // đang load → chưa hiện
 
    final d = _daysLeft!;
    final subtitle = d == 0
        ? '⏰ Hôm nay là ngày cuối! · Nhập code khi thanh toán'
        : '⏰ Chỉ còn $d ngày · Nhập code khi thanh toán';
 
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1500),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _yellow.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Text('🎟️', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Voucher ra mắt — chỉ NT\$999/năm',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _yellow)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
        ])),
      ]),
    );
  }
}
 




























