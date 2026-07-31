// ═══════════════════════════════════════════════════════════════
// STROKE PRACTICE SCREEN
// File: lib/features/learn/presentation/widgets/stroke_practice_screen.dart
//
// Luyện viết chữ Hán theo từng nét — dùng package stroke_order_animator
// + dữ liệu nét từ hanzi_writer_data_flutter (giấy phép ARPHIC, cho phép
// dùng thương mại — xem file ARPHICPL.txt đi kèm).
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';
import 'package:hanzi_writer_data_flutter/hanzi_writer_data_flutter.dart';
import 'package:characters/characters.dart';

class StrokePracticeScreen extends StatefulWidget {
  final String hanzi;
  final String meaning;

  const StrokePracticeScreen({
    super.key,
    required this.hanzi,
    required this.meaning,
  });

  @override
  State<StrokePracticeScreen> createState() => _StrokePracticeScreenState();
}

class _StrokePracticeScreenState extends State<StrokePracticeScreen> with TickerProviderStateMixin {
  static const _orange = Color(0xFFFF6B35);
  static const _orange2 = Color(0xFFF57F17);
  static const _ink = Color(0xFF1A1D2E);
  static const _muted = Color(0xFF8A8FA3);
  static const _green = Color(0xFF00C853);
  static const _bg = Color(0xFFF7F8FC);

  bool _isLoading = true;
  String? _errorMsg;
  int _currentCharIndex = 0;
  List<StrokeOrderAnimationController> _controllers = [];

  List<String> get _chars => widget.hanzi.characters.map((c) => c.toString()).toList();

  @override
  void initState() {
    super.initState();
    _loadStrokeData();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadStrokeData() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final controllers = <StrokeOrderAnimationController>[];
      for (final char in _chars) {
        final data = await loadCharData(char);
        if (data == null) continue;
        final strokeOrder = StrokeOrder(data);
        controllers.add(StrokeOrderAnimationController(strokeOrder, this));
      }
      if (controllers.isEmpty) {
        setState(() { _errorMsg = 'Chưa có dữ liệu nét cho chữ này'; _isLoading = false; });
        return;
      }
      setState(() { _controllers = controllers; _isLoading = false; });
    } catch (e) {
      setState(() { _errorMsg = 'Không tải được dữ liệu nét. Thử lại nhé!'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: _ink),
        title: const Text('Luyện viết',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _ink),
          onPressed: () => Navigator.pop(context, 'exit'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _errorMsg != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_errorMsg!, style: const TextStyle(color: _muted)),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _loadStrokeData, child: const Text('Thử lại')),
                  ]),
                ))
              : _buildPractice(),
    );
  }

  Widget _buildPractice() {
    final controller = _controllers[_currentCharIndex];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(children: [
          Text(widget.meaning, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          if (_chars.length > 1) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Chữ ${_currentCharIndex + 1}/${_chars.length}',
                style: const TextStyle(fontSize: 12, color: _muted)),
          ),
        ]),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: StrokeOrderAnimator(controller),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          Expanded(child: _buildActionButton(
            icon: Icons.play_arrow_rounded, label: 'Xem hoạt ảnh',
            onTap: () => controller.startAnimation(),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildActionButton(
            icon: Icons.edit_rounded, label: 'Tự luyện viết',
            onTap: () => controller.startQuiz(),
            filled: true,
          )),
        ]),
      ),
      if (_chars.length > 1) Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          if (_currentCharIndex > 0) Expanded(child: _buildActionButton(
            icon: Icons.arrow_back_rounded, label: 'Chữ trước',
            onTap: () => setState(() => _currentCharIndex--),
          )),
          if (_currentCharIndex > 0 && _currentCharIndex < _chars.length - 1) const SizedBox(width: 10),
          if (_currentCharIndex < _chars.length - 1) Expanded(child: _buildActionButton(
            icon: Icons.arrow_forward_rounded, label: 'Chữ tiếp',
            onTap: () => setState(() => _currentCharIndex++),
          )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.pop(context, 'continue'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_orange, _orange2]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Xong, từ tiếp theo →',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: filled ? const LinearGradient(colors: [_orange, _orange2]) : null,
          color: filled ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: _orange.withOpacity(0.4)),
          boxShadow: filled ? [BoxShadow(color: _orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: filled ? Colors.white : _orange),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: filled ? Colors.white : _orange)),
        ]),
      ),
    );
  }
}