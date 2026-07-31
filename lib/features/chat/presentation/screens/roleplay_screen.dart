// ═══════════════════════════════════════════════════════════════
// ROLEPLAY SCREEN — Chọn kịch bản nhập vai (VIP only)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'roleplay_chat_screen.dart';

class RoleplayScreen extends StatefulWidget {
  const RoleplayScreen({super.key});

  @override
  State<RoleplayScreen> createState() => _RoleplayScreenState();
}

class _RoleplayScreenState extends State<RoleplayScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _scenarios = [];
  bool _isLoading = true;
  bool _isVip = false;

  static const _purple = Color(0xFF5B5FEF);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF7F8FC);
  static const _orange = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/roleplay/scenarios',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _scenarios = List<Map<String, dynamic>>.from(response.data['scenarios'] ?? []);
        _isVip = response.data['is_vip'] == true;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showVipRequiredDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Tính năng VIP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink)),
            const SizedBox(height: 8),
            const Text('Nhập vai với AI để luyện tập tình huống thật — chỉ dành cho hội viên VIP.',
                textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.5)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Đã hiểu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Nhập vai luyện tập',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isVip) Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_orange, Color(0xFFF57F17)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(children: [
                    Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Tính năng VIP — nâng cấp để mở khóa nhập vai với AI',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                  ]),
                ),
                ..._scenarios.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      if (!_isVip) { _showVipRequiredDialog(); return; }
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => RoleplayChatScreen(scenarioKey: s['key'], scenarioName: s['name']),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: Center(child: Text(s['emoji'] ?? '🎭', style: const TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
                          const SizedBox(height: 4),
                          Text(
                            (s['times_played'] ?? 0) > 0
                                ? 'Đã chơi ${s['times_played']} lần · Độ khó ${s['difficulty_level']}/3'
                                : 'Chưa chơi lần nào',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ])),
                        if (!_isVip) const Icon(Icons.lock_rounded, size: 18, color: _muted)
                        else const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _purple),
                      ]),
                    ),
                  ),
                )),
              ],
            ),
    );
  }
}