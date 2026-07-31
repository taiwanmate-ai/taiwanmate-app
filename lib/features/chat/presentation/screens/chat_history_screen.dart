import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});
  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/sessions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _sessions = List<Map<String, dynamic>>.from(res.data['sessions'] ?? []));
    } catch (e) {
      setState(() => _sessions = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'Hôm nay, ${DateFormat.Hm().format(dt)}';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isYesterday) return 'Hôm qua, ${DateFormat.Hm().format(dt)}';
    return DateFormat('dd/MM/yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Lịch sử trò chuyện', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1D2E),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B5FEF)))
          : _sessions.isEmpty
              ? const Center(child: Text('Chưa có cuộc trò chuyện nào', style: TextStyle(color: Color(0xFF8A8FA3))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) {
                      final s = _sessions[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: const Color(0xFFEEEDFE), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF5B5FEF), size: 20),
                          ),
                          title: Text(
                            s['title'] ?? 'Cuộc trò chuyện',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1D2E)),
                          ),
                          subtitle: Text(_formatTime(s['last_message_at']), style: const TextStyle(fontSize: 12, color: Color(0xFF8A8FA3))),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8FA3)),
                          onTap: () => Navigator.pop(context, s['id'] as String),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}