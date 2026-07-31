import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MasteryProfileTab extends StatefulWidget {
  const MasteryProfileTab({super.key});
  @override
  State<MasteryProfileTab> createState() => _MasteryProfileTabState();
}

class _MasteryProfileTabState extends State<MasteryProfileTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _topics = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5B5FEF)));
    }

    if (_error != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_error!, style: const TextStyle(color: Color(0xFF8A8FA3))),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF5B5FEF), borderRadius: BorderRadius.circular(12)),
            child: const Text('Thử lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]));
    }

    if (_topics.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chưa có dữ liệu năng lực.\nHãy luyện Đấu Trường Boss hoặc chat với AI để bắt đầu nhé!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF8A8FA3), fontSize: 14),
        ),
      ));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: _topics.length,
        itemBuilder: (_, i) {
          final t = _topics[i];
          final score = (t['mastery_score'] as num).toDouble();
          final color = _colorForScore(score);
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
                Expanded(child: Text(t['label'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E)))),
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
            ]),
          );
        },
      ),
    );
  }
}