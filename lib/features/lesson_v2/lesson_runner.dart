/// Logic THUAN (khong UI) cua bai hoc moi: hang doi luyen tap co "sai -> hoi lai bang dang khac" + ghi ket qua de gui len server.
/// Server tra ca phien 1 lan (GET /lesson/{unit}/session) — khong goi AI khi dang hoc.
class AnswerRecord {
  final String questionId;
  final bool correct;
  final int attempt; // 1 = lan dau; >1 = lam lai sau khi sai
  final int ms;
  const AnswerRecord(this.questionId, this.correct, this.attempt, this.ms);

  Map<String, dynamic> toJson() => {'question_id': questionId, 'correct': correct, 'attempt': attempt, 'ms': ms};
}

class _Item {
  final Map<String, dynamic> q;
  final int attempt;
  _Item(this.q, this.attempt);
}

/// Hang doi cau hoi. Quy tac (thiet ke da duyet):
///  - tra loi SAI lan dau (cau co word_id): hoi lai SAU [retryGap] cau, bang cau DANG KHAC cua cung tu (lay tu `alts`);
///  - sai lan 2: hoi them 1 lan nua O CUOI phien (lan 3); sai lan 3 thi thoi (khong chan tien do);
///  - cau ghep cap (khong co word_id) khong lam lai.
class PracticeQueue {
  final Map<String, List<Map<String, dynamic>>> alts;
  final int retryGap;
  final List<_Item> _items;
  final List<AnswerRecord> records = [];
  final Set<String> _usedIds = {};
  int _index = 0;
  final int initialCount;

  PracticeQueue(List<Map<String, dynamic>> questions, {Map<String, List<Map<String, dynamic>>>? alts, this.retryGap = 2})
      : alts = alts ?? const {},
        _items = [for (final q in questions) _Item(q, 1)],
        initialCount = questions.length {
    for (final q in questions) {
      _usedIds.add(q['id'] as String);
    }
  }

  bool get isDone => _index >= _items.length;
  Map<String, dynamic>? get current => isDone ? null : _items[_index].q;
  int get attemptOfCurrent => isDone ? 0 : _items[_index].attempt;
  int get position => _index.clamp(0, _items.length);
  int get total => _items.length;

  void answer(bool correct, {int ms = 0}) {
    if (isDone) return;
    final item = _items[_index];
    final id = item.q['id'] as String;
    records.add(AnswerRecord(id, correct, item.attempt, ms));
    if (!correct && item.q['word_id'] != null) {
      if (item.attempt == 1) {
        final retry = _pickAlt(item.q);
        final at = (_index + 1 + retryGap).clamp(0, _items.length);
        _items.insert(at, _Item(retry, 2));
      } else if (item.attempt == 2) {
        _items.add(_Item(_pickAlt(item.q), 3));
      }
    }
    _index++;
  }

  Map<String, dynamic> _pickAlt(Map<String, dynamic> q) {
    final list = alts[q['word_id']] ?? const <Map<String, dynamic>>[];
    for (final a in list) {
      if (!_usedIds.contains(a['id']) && a['kind'] != q['kind']) {
        _usedIds.add(a['id'] as String);
        return a;
      }
    }
    for (final a in list) {
      if (!_usedIds.contains(a['id'])) {
        _usedIds.add(a['id'] as String);
        return a;
      }
    }
    return q; // het cau khac -> hoi lai chinh cau nay
  }

  /// (dung, tong) tinh tren lan tra loi DAU TIEN cua tung cau.
  (int, int) get firstAttemptScore {
    final firsts = records.where((r) => r.attempt == 1).toList();
    return (firsts.where((r) => r.correct).length, firsts.length);
  }
}

/// Gop ket qua cac buoc (on lai, hoi nhanh, luyen tap) thanh body POST /lesson/{unit}/answers.
Map<String, dynamic> buildAnswersBody(String sessionId, List<AnswerRecord> records) =>
    {'session_id': sessionId, 'results': [for (final r in records) r.toJson()]};

/// Cac buoc hien thi cua phien (loai bo buoc rong de khong hien man hinh trong).
List<Map<String, dynamic>> visibleSteps(Map<String, dynamic> session) {
  final out = <Map<String, dynamic>>[];
  for (final s in (session['steps'] as List).cast<Map<String, dynamic>>()) {
    final t = s['type'];
    if (t == 'review' && (s['questions'] as List).isEmpty) continue;
    if (t == 'practice' && (s['questions'] as List).isEmpty) continue;
    if (t == 'minigame' && (s['pairs'] as List).length < 4) continue;
    out.add(s);
  }
  return out;
}
