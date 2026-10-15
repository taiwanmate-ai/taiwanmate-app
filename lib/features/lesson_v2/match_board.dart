import 'dart:math';

/// Logic THUAN cua mini-game "Ghep nhanh 60 giay" (khong UI, khong AI): sinh tu cac cap chu–nghia da duyet cua bai.
/// Hien [size] cap; ghep dung -> cap do duoc thay bang cap moi trong pool; ghep sai -> +1 loi. Server tu tinh diem tu (matched, misses).
class MatchBoard {
  final List<Map<String, dynamic>> pool; // [{word_id,left,right}]
  final int size;
  final Random _rng;
  final List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> pairs = []; // cac cap dang hien
  List<Map<String, dynamic>> lefts = [];
  List<Map<String, dynamic>> rights = [];
  int matched = 0;
  int misses = 0;

  MatchBoard(this.pool, {this.size = 5, int? seed}) : _rng = Random(seed) {
    _refillQueue();
    for (var i = 0; i < size && _queue.isNotEmpty; i++) {
      pairs.add(_queue.removeAt(0));
    }
    _reshuffle();
  }

  void _refillQueue() {
    final shown = pairs.map((p) => p['word_id']).toSet();
    final fresh = pool.where((p) => !shown.contains(p['word_id']) && !_queue.any((q) => q['word_id'] == p['word_id'])).toList()..shuffle(_rng);
    _queue.addAll(fresh);
  }

  void _reshuffle() {
    lefts = List.of(pairs)..shuffle(_rng);
    rights = List.of(pairs)..shuffle(_rng);
  }

  /// Chon 1 chu (left) va 1 nghia (right) theo word_id. Tra ve true neu dung.
  bool select(String leftWordId, String rightWordId) {
    if (leftWordId != rightWordId) {
      misses++;
      return false;
    }
    matched++;
    final idx = pairs.indexWhere((p) => p['word_id'] == leftWordId);
    if (idx < 0) return true;
    final oldL = lefts.indexWhere((p) => p['word_id'] == leftWordId);
    final oldR = rights.indexWhere((p) => p['word_id'] == leftWordId);
    if (_queue.isEmpty) _refillQueue();
    if (_queue.isNotEmpty) {
      // thay dung o vua ghep bang cap moi (cac o con lai giu nguyen vi tri de nguoi choi khong bi "nhay")
      final next = _queue.removeAt(0);
      pairs[idx] = next;
      if (oldL >= 0) lefts[oldL] = next;
      if (oldR >= 0) rights[oldR] = next;
    } else {
      pairs.removeAt(idx);
      if (oldL >= 0) lefts.removeAt(oldL);
      if (oldR >= 0) rights.removeAt(oldR);
    }
    return true;
  }

  bool get isEmpty => pairs.isEmpty;

  int get score => (matched * 10 - misses * 2).clamp(0, 1 << 30);
}
