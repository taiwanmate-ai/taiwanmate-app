// ═══════════════════════════════════════════════════════════════
// MY MISTAKES SCREEN
// File: lib/features/learn/presentation/widgets/my_mistakes_screen.dart
//
// Hiển thị các lỗi ngữ pháp/từ vựng AI phát hiện được trong AI Chat,
// dạng flashcard để ôn lại (SRS đơn giản: nhớ/chưa nhớ).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MyMistakesScreen extends StatefulWidget {
  const MyMistakesScreen({super.key});

  @override
  State<MyMistakesScreen> createState() => _MyMistakesScreenState();
}

class _MyMistakesScreenState extends State<MyMistakesScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _mistakes = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showAnswer = false;

  static const _red = Color(0xFFFF3D57);
  static const _green = Color(0xFF00C853);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _bg = Color(0xFFF7F8FC);
  static const _purple = Color(0xFF5B5FEF);

  @override
  void initState() {
    super.initState();
    _loadMistakes();
  }

  Future<void> _loadMistakes() async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/mistakes',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _mistakes = List<Map<String, dynamic>>.from(response.data['mistakes'] ?? []);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewCurrent(bool remembered) async {
    if (_currentIndex >= _mistakes.length) return;
    final mistakeId = _mistakes[_currentIndex]['id'];
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/chat/mistakes/$mistakeId/review',
        data: {'remembered': remembered},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {}

    setState(() {
      _showAnswer = false;
      if (_currentIndex < _mistakes.length - 1) {
        _currentIndex++;
      } else {
        _mistakes.removeWhere((m) => remembered && m == _mistakes[_currentIndex]);
        _currentIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Lỗi của tôi',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : _mistakes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎉', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      const Text('Chưa có lỗi nào cần ôn!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                      const SizedBox(height: 6),
                      const Text('Trò chuyện với AI, lỗi sai sẽ tự động lưu ở đây để ôn lại.',
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _muted)),
                    ]),
                  ),
                )
              : _buildFlashcard(),
    );
  }

  Widget _buildFlashcard() {
    final m = _mistakes[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text('${_currentIndex + 1} / ${_mistakes.length}',
            style: const TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BẠN ĐÃ VIẾT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.4)),
                const SizedBox(height: 8),
                Text(m['wrong_text'] ?? '', style: const TextStyle(fontSize: 17, color: _red, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough, fontFamily: 'NotoSansTC')),
                const SizedBox(height: 20),
                if (_showAnswer) ...[
                  const Text('SỬA ĐÚNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _muted, letterSpacing: 0.4)),
                  const SizedBox(height: 8),
                  Text(m['correct_text'] ?? '', style: const TextStyle(fontSize: 19, color: _green, fontWeight: FontWeight.w800, fontFamily: 'NotoSansTC')),
                  if ((m['explanation'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                      child: Text(m['explanation'], style: const TextStyle(fontSize: 13, color: _ink, height: 1.5)),
                    ),
                  ],
                ] else
                  const Text('Chạm để xem đáp án đúng', style: TextStyle(fontSize: 13, color: _muted, fontStyle: FontStyle.italic)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_showAnswer) Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _reviewCurrent(false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFFDE8E7), borderRadius: BorderRadius.circular(14)),
              child: const Text('Chưa nhớ', textAlign: TextAlign.center, style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: GestureDetector(
            onTap: () => _reviewCurrent(true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFE3F7EC), borderRadius: BorderRadius.circular(14)),
              child: const Text('Đã nhớ', textAlign: TextAlign.center, style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
            ),
          )),
        ]),
      ]),
    );
  }
}