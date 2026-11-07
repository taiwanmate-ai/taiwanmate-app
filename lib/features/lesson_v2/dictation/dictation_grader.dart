/// Chấm NGHE CHÉP trên thiết bị (không gọi mạng). Bản PORT 1-1 của backend `app/services/dictation.py` (bản tham chiếu).
///
/// HỢP ĐỒNG: cho ĐÚNG kết quả `expect` của mọi ca trong `test/fixtures/dictation_normalize_cases.json` (chép nguyên văn từ backend
/// `data/dictation_normalize_cases.json`; sha256 ghim trong `test/dictation_fixture_hash_test.dart`). Bảng âm tiết:
/// `assets/data/dictation_pinyin_syllables.json` (cũng chép nguyên văn từ backend). Đổi luật chấm → đổi ở backend trước, sinh lại file, chép sang đây.
///
/// Quy ước pinyin: âm tiết = (gốc không dấu, chữ thường, ü viết 'v'), thanh 1–4, 5 = thanh nhẹ; người học gõ KHÔNG dấu → thanh 0.
library;

/// Một bước căn chỉnh: op ∈ ok | sub | del | ins | tone | tone_warn.
class DictationOp {
  final String op;
  final String? exp;
  final String? got;
  final String? note; // simplified | variant (chữ Hán)
  final String? msg; // giải thích biến điệu (pinyin)
  const DictationOp(this.op, this.exp, this.got, {this.note, this.msg});

  /// Cùng thứ tự khóa với bản Python (để so sánh JSON với file test vector).
  Map<String, dynamic> toJson() => {'op': op, 'exp': exp, 'got': got, if (note != null) 'note': note, if (msg != null) 'msg': msg};
}

class DictationResult {
  final bool correct;
  final double accuracy;
  final List<DictationOp> ops;
  const DictationResult(this.correct, this.accuracy, this.ops);
  Map<String, dynamic> toJson() => {'correct': correct, 'accuracy': accuracy, 'ops': [for (final o in ops) o.toJson()]};

  /// Có ít nhất 1 âm tiết sai thanh (dù vẫn tính đúng khi không bắt dấu thanh).
  bool get hasToneIssue => ops.any((o) => o.op == 'tone' || o.op == 'tone_warn');
}

/// Một chữ của đáp án (payload['chars']): h = chữ, b = gốc pinyin, t = thanh chấp nhận (t[0] = thanh viết trong pinyin soạn sẵn), s = dạng giản thể.
class DictChar {
  final String h;
  final String b;
  final List<int> t;
  final String? s;
  const DictChar(this.h, this.b, this.t, this.s);
  factory DictChar.fromJson(Map m) => DictChar(m['h'] as String, m['b'] as String, [for (final x in m['t'] as List) (x as num).toInt()], m['s'] as String?);
}

List<DictChar> charsOf(Map payload) => [for (final c in payload['chars'] as List) DictChar.fromJson(c as Map)];

// Chữ dị thể mà ở Đài Loan cả hai đều dùng — coi là cùng chữ. Khóa = dạng trong đáp án.
const Map<String, String> kVariants = {'台': '臺', '臺': '台', '裡': '裏', '裏': '裡', '着': '著', '痴': '癡', '癡': '痴'};
const Map<String, int> kSandhiBase = {'一': 1, '不': 4};

const _toneOfMark = {'\u0304': 1, '\u0301': 2, '\u030c': 3, '\u0300': 4};
const _markOfTone = {1: '\u0304', 2: '\u0301', 3: '\u030c', 4: '\u0300'};

// NFD của nguyên âm pinyin dựng sẵn (Dart không có chuẩn hóa Unicode): chỉ cần nhóm ký tự xuất hiện trong pinyin.
const Map<String, String> _decompose = {
  'ā': 'a\u0304', 'á': 'a\u0301', 'ǎ': 'a\u030c', 'à': 'a\u0300',
  'ē': 'e\u0304', 'é': 'e\u0301', 'ě': 'e\u030c', 'è': 'e\u0300',
  'ī': 'i\u0304', 'í': 'i\u0301', 'ǐ': 'i\u030c', 'ì': 'i\u0300',
  'ō': 'o\u0304', 'ó': 'o\u0301', 'ǒ': 'o\u030c', 'ò': 'o\u0300',
  'ū': 'u\u0304', 'ú': 'u\u0301', 'ǔ': 'u\u030c', 'ù': 'u\u0300',
  'ǖ': 'u\u0308\u0304', 'ǘ': 'u\u0308\u0301', 'ǚ': 'u\u0308\u030c', 'ǜ': 'u\u0308\u0300', 'ü': 'u\u0308',
  'ń': 'n\u0301', 'ň': 'n\u030c', 'ǹ': 'n\u0300', 'ḿ': 'm\u0301', 'ê': 'e\u0302',
};
final Map<String, String> _compose = {
  for (final e in _decompose.entries) e.value.replaceAll('u\u0308', 'ü'): e.key,
};

String _nfdV(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    b.write(_decompose[c] ?? c);
  }
  return b.toString().replaceAll('u\u0308', 'v').replaceAll('u:', 'v');
}

bool _isMn(String c) {
  final r = c.runes.first;
  return (r >= 0x0300 && r <= 0x036f) || (r >= 0x1ab0 && r <= 0x1aff) || (r >= 0x1dc0 && r <= 0x1dff) || (r >= 0x20d0 && r <= 0x20ff) || (r >= 0xfe20 && r <= 0xfe2f);
}

final _alnum = RegExp(r'^[\p{L}\p{N}]$', unicode: true);

/// Bỏ dấu câu (cả toàn khổ), khoảng trắng, ký hiệu. Giữ chữ Hán / chữ cái / số.
String normalizeHanzi(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (_alnum.hasMatch(c)) b.write(c);
  }
  return b.toString();
}

List<String> _chars(String s) => [for (final r in s.runes) String.fromCharCode(r)];

final _aliasJqxy = RegExp(r'([jqxy])v');
final _aliasUe = RegExp(r'([ln])ue');
final _chunk = RegExp(r'[a-z\u0300-\u036f]+[1-5]?');

/// Cắt chuỗi chữ cái thành âm tiết hợp lệ: nhiều cách cắt → chọn cách có NHIỀU âm tiết nằm trong [expected] nhất, rồi ÍT âm tiết nhất.
List<(int, int)>? _segment(String letters, Set<String> expected, Set<String> table) {
  final n = letters.length;
  final best = List<((int, int), List<(int, int)>)?>.filled(n + 1, null);
  best[n] = ((0, 0), const []);
  bool gt((int, int) a, (int, int) b) => a.$1 != b.$1 ? a.$1 > b.$1 : a.$2 > b.$2;
  for (var i = n - 1; i >= 0; i--) {
    ((int, int), List<(int, int)>)? cand;
    for (var j = (i + 6 < n ? i + 6 : n); j > i; j--) {
      final piece = letters.substring(i, j);
      final next = best[j];
      if (table.contains(piece) && next != null) {
        final sc = (next.$1.$1 + (expected.contains(piece) ? 1 : 0), next.$1.$2 - 1);
        if (cand == null || gt(sc, cand.$1)) cand = (sc, [(i, j), ...next.$2]);
      }
    }
    best[i] = cand;
  }
  return best[0]?.$2;
}

/// 'wǒ míngtiān', 'wo3 ming2tian1', 'nv3', 'lu:4' → [(gốc, thanh)]. Đoạn không cắt được → 1 âm tiết là chính đoạn đó (sẽ bị chấm sai).
List<(String, int)> parsePinyin(String s, Set<String> table, [Iterable<String> expectedBases = const []]) {
  final exp = expectedBases.toSet();
  final out = <(String, int)>[];
  for (final m in _chunk.allMatches(_nfdV(s))) {
    final chunk = m.group(0)!;
    final last = chunk[chunk.length - 1];
    final digit = int.tryParse(last);
    final body = digit != null ? chunk.substring(0, chunk.length - 1) : chunk;
    var letters = '';
    final marks = <int>[];
    for (final c in _chars(body)) {
      if (_toneOfMark.containsKey(c) && letters.isNotEmpty) {
        marks[marks.length - 1] = _toneOfMark[c]!;
      } else if (_isMn(c)) {
        continue;
      } else {
        letters += c;
        marks.add(0);
      }
    }
    if (letters.isEmpty) continue;
    letters = letters.replaceAllMapped(_aliasJqxy, (m) => '${m[1]}u').replaceAllMapped(_aliasUe, (m) => '${m[1]}ve');
    final parts = _segment(letters, exp, table);
    if (parts == null) {
      final mx = marks.fold<int>(0, (a, b) => b > a ? b : a);
      out.add((letters, digit ?? mx));
      continue;
    }
    for (var k = 0; k < parts.length; k++) {
      final (i, j) = parts[k];
      var tone = marks.sublist(i, j).firstWhere((x) => x != 0, orElse: () => 0);
      if (digit != null && k == parts.length - 1) tone = digit;
      out.add((letters.substring(i, j), tone));
    }
  }
  return out;
}

/// Levenshtein + truy ngược CÙNG thứ ưu tiên với bản Python: chéo → xóa → chèn. → [(op, iExp, jGot)].
List<(String, int?, int?)> _align<E, G>(List<E> exp, List<G> got, bool Function(E, G) same) {
  final n = exp.length, m = got.length;
  final d = List.generate(n + 1, (i) => List<int>.filled(m + 1, 0));
  for (var i = 0; i <= n; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= m; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final c = same(exp[i - 1], got[j - 1]) ? 0 : 1;
      var v = d[i - 1][j] + 1;
      if (d[i][j - 1] + 1 < v) v = d[i][j - 1] + 1;
      if (d[i - 1][j - 1] + c < v) v = d[i - 1][j - 1] + c;
      d[i][j] = v;
    }
  }
  final ops = <(String, int?, int?)>[];
  var i = n, j = m;
  while (i > 0 || j > 0) {
    if (i > 0 && j > 0 && d[i][j] == d[i - 1][j - 1] + (same(exp[i - 1], got[j - 1]) ? 0 : 1)) {
      ops.add((same(exp[i - 1], got[j - 1]) ? 'ok' : 'sub', i - 1, j - 1));
      i--;
      j--;
    } else if (i > 0 && d[i][j] == d[i - 1][j] + 1) {
      ops.add(('del', i - 1, null));
      i--;
    } else {
      ops.add(('ins', null, j - 1));
      j--;
    }
  }
  return ops.reversed.toList();
}

/// ok/n làm tròn 3 chữ số, ĐÚNG NỬA → số CHẴN (giống round() của Python; tính bằng số nguyên như `round3` ở backend).
double round3(int ok, int n) {
  if (n == 0) return 0.0;
  var q = (ok * 1000) ~/ n;
  final r = (ok * 1000) % n;
  if (2 * r > n || (2 * r == n && q.isOdd)) q++;
  return q / 1000;
}

DictationResult _result(List<DictationOp> ops, int nExp) {
  final ok = ops.where((o) => o.op == 'ok' || o.op == 'tone_warn').length;
  return DictationResult(ops.every((o) => o.op == 'ok' || o.op == 'tone_warn'), round3(ok, nExp), ops);
}

/// Chữ dị thể (台/臺) = đúng; dạng giản thể của chữ đáp án = đúng kèm ghi chú 'simplified'.
DictationResult gradeHanzi(List<DictChar> chars, String user) {
  final got = _chars(normalizeHanzi(user));
  bool same(DictChar e, String g) => g == e.h || g == kVariants[e.h] || g == e.s;
  final ops = <DictationOp>[];
  for (final (op, i, j) in _align<DictChar, String>(chars, got, same)) {
    final e = i != null ? chars[i] : null;
    final g = j != null ? got[j] : null;
    String? note;
    if (op == 'ok' && g != e!.h) note = g == e.s ? 'simplified' : 'variant';
    ops.add(DictationOp(op, e?.h, g, note: note));
  }
  return _result(ops, chars.length);
}

DictationResult gradeTiles(List<DictChar> chars, List<String> picked) => gradeHanzi(chars, picked.join());

/// Không bắt dấu thanh: sai thanh / không đánh thanh → 'tone_warn' (vẫn đúng). Bắt dấu thanh: sai thanh → 'tone' (sai); không đánh thanh chỉ đúng khi thanh nhẹ.
DictationResult gradePinyin(List<DictChar> chars, String user, Set<String> table, {bool strictTones = false}) {
  final got = parsePinyin(user, table, chars.map((c) => c.b));
  final ops = <DictationOp>[];
  for (final (op, i, j) in _align<DictChar, (String, int)>(chars, got, (e, g) => g.$1 == e.b)) {
    final e = i != null ? chars[i] : null;
    final g = j != null ? got[j] : null;
    var o = op;
    String? msg;
    if (op == 'ok') {
      final tone = g!.$2;
      final fine = e!.t.contains(tone) || (tone == 0 && e.t.contains(5));
      if (!fine) {
        o = strictTones ? 'tone' : 'tone_warn';
        msg = sandhiMessage(chars, i!, tone);
      }
    }
    ops.add(DictationOp(o, e != null ? '${e.b}${e.t.first}' : null, g != null ? '${g.$1}${g.$2 == 0 ? '' : g.$2}' : null, msg: msg));
  }
  return _result(ops, chars.length);
}

/// ('hao', 3) → 'hǎo'; ('lv', 4) → 'lǜ'; thanh 5/0 → không dấu. Luật: a/e trước, 'ou' → o, còn lại nguyên âm cuối.
String mark(String base, int tone) {
  final b = base.replaceAll('v', 'ü');
  final mk = _markOfTone[tone];
  if (mk == null) return b;
  int k;
  if (b.contains('a')) {
    k = b.indexOf('a');
  } else if (b.contains('e')) {
    k = b.indexOf('e');
  } else if (b.contains('ou')) {
    k = b.indexOf('o');
  } else {
    k = -1;
    for (var i = 0; i < b.length; i++) {
      if ('iouü'.contains(b[i])) k = i;
    }
    if (k < 0) return b;
  }
  final v = b[k];
  return b.substring(0, k) + (_compose['$v$mk'] ?? '$v$mk') + b.substring(k + 1);
}

/// Người học gõ thanh SAI mà nguyên nhân là biến điệu → giải thích đúng nguyên nhân (CTO 03/11). Không liên quan biến điệu → null.
String? sandhiMessage(List<DictChar> chars, int i, int tone) {
  final e = chars[i];
  final nxt = i + 1 < chars.length ? chars[i + 1] : null;
  final written = e.t.first;
  final nx = nxt != null ? ' ${mark(nxt.b, nxt.t.first)}' : '';
  if (written == 3 && tone == 2 && nxt != null && nxt.t.first == 3) {
    return 'Đọc là ${mark(e.b, 2)}$nx, nhưng viết vẫn là ${mark(e.b, 3)}$nx (3+3).';
  }
  if (kSandhiBase.containsKey(e.h) && (e.b == 'yi' || e.b == 'bu') && tone >= 1 && tone <= 4) {
    final base = kSandhiBase[e.h]!;
    if (written != base && nxt != null) {
      return '${e.h} đứng trước ${mark(nxt.b, nxt.t.first)} nên đọc là ${mark(e.b, written)} (${mark(e.b, written)}$nx); '
          'viết ${mark(e.b, base)} hoặc ${mark(e.b, written)} đều đúng.';
    }
    if (e.h == '不') return '不 chỉ đọc là bú khi đứng trước thanh 4; ở đây giữ thanh gốc: bù$nx.';
    return '一 ở đây giữ thanh gốc: yī$nx.';
  }
  return null;
}
