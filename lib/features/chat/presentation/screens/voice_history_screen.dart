/// Audit "Voice roadmap — luu lich su hoi thoai Voice" (2026-09-08) — man
/// hinh XEM LAI cac cuoc tro chuyen Voice DA LUU (backend gio ghi ChatSession/
/// ChatMessage voi source='voice' cho moi phien — xem voice_ws.py). CHI DOC
/// (khong the "tiep tuc" 1 phien Voice cu nhu ChatHistoryScreen cho Chat —
/// Voice khong co khai niem resume ket noi WebSocket da dong), nen tap vao
/// 1 session se mo transcript READ-ONLY thay vi pop tra ve session_id.
library;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:chinesemate/core/constants/api_constants.dart';

class VoiceHistoryScreen extends StatefulWidget {
  const VoiceHistoryScreen({super.key});
  @override
  State<VoiceHistoryScreen> createState() => _VoiceHistoryScreenState();
}

class _VoiceHistoryScreenState extends State<VoiceHistoryScreen> {
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
        '${ApiConstants.baseUrl}/chat/sessions',
        queryParameters: {'source': 'voice'},
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử Voice')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _sessions.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có cuộc trò chuyện Voice nào',
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                )
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
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.graphic_eq, color: scheme.tertiary, size: 20),
                          ),
                          title: Text(
                            s['title'] ?? 'Cuộc trò chuyện Voice',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          subtitle: Text(
                            _formatTime(s['last_message_at']),
                            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.5)),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VoiceHistoryTranscriptScreen(
                                sessionId: s['id'] as String,
                                title: s['title'] as String? ?? 'Cuộc trò chuyện Voice',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Transcript READ-ONLY cho 1 phien Voice da luu — KHONG the tiep tuc noi
/// (khac ChatScreen), chi xem lai noi dung da trao doi.
class VoiceHistoryTranscriptScreen extends StatefulWidget {
  const VoiceHistoryTranscriptScreen({super.key, required this.sessionId, required this.title});
  final String sessionId;
  final String title;

  @override
  State<VoiceHistoryTranscriptScreen> createState() => _VoiceHistoryTranscriptScreenState();
}

class _VoiceHistoryTranscriptScreenState extends State<VoiceHistoryTranscriptScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _messages = [];
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
        '${ApiConstants.baseUrl}/chat/session/${widget.sessionId}/messages',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _messages = List<Map<String, dynamic>>.from(res.data['messages'] ?? []));
    } catch (e) {
      setState(() => _messages = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isUser = m['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? scheme.primary.withValues(alpha: 0.16) : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Text(
                      m['content'] as String? ?? '',
                      style: TextStyle(fontSize: 15, color: scheme.onSurface, height: 1.4),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
