import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/features/lesson_v2/lesson_runner.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';

/// Kết quả bài học tính NGAY Ở MÁY (2026-10-20) để hiện màn hình kết thúc không phải chờ server; gửi lên server ở nền
/// (idempotent theo session_id) và đồng bộ lại khi server trả về. Công thức GIỐNG HỆT server (lesson_service.submit_results).
const int kXpLesson = 30;
const int kXpPerfectBonus = 10;
const int kMaxScoredQuestions = 50;

/// Python `round()` làm tròn về số CHẴN khi đúng .5 (12.5 -> 12, 13.5 -> 14); Dart `.round()` làm tròn ra xa 0 -> lệch hiển thị %.
int pyRound(double x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if (diff < 0.5) return f.toInt();
  if (diff > 0.5) return f.toInt() + 1;
  return (f.toInt() % 2 == 0) ? f.toInt() : f.toInt() + 1;
}

/// Gom question_id -> word_id từ phiên (câu ôn lại, hỏi nhanh, luyện tập, câu làm lại khác dạng).
Map<String, String?> questionWordMap(Map<String, dynamic> session) {
  final out = <String, String?>{};
  void add(dynamic q) {
    if (q is Map && q['id'] != null) out[q['id'] as String] = q['word_id'] as String?;
  }

  for (final st in (session['steps'] as List? ?? const [])) {
    if (st is! Map) continue;
    for (final q in (st['questions'] as List? ?? const [])) {
      add(q);
    }
    for (final p in (st['pairs'] as List? ?? const [])) {
      if (p is Map) add(p['micro']);
    }
  }
  final alts = (session['retry'] as Map?)?['alts'];
  if (alts is Map) {
    for (final list in alts.values) {
      for (final q in (list as List)) {
        add(q);
      }
    }
  }
  return out;
}

/// Kết quả tính ở máy -> Map cùng khóa với phản hồi server + `local: true`. Chưa biết (cần server): due_tomorrow, streak_days, total_xp (không có khóa).
Map<String, dynamic> computeLocalSummary(
  Map<String, dynamic> session,
  List<AnswerRecord> records, {
  int? completedUnits,
  bool alreadyCompleted = false,
  String? nextUnitId,
  bool levelCompleted = false,
}) {
  final wordOf = questionWordMap(session);
  // lần trả lời ĐẦU TIÊN của từng câu (câu trả lời lại: bản ghi cuối với attempt==1 thắng, như server)
  final firstByQ = <String, bool>{};
  for (final r in records) {
    if (r.attempt == 1) firstByQ[r.questionId] = r.correct;
  }
  final total = firstByQ.length < kMaxScoredQuestions ? firstByQ.length : kMaxScoredQuestions;
  final correct = firstByQ.values.take(total).where((v) => v).length;
  final pct = total == 0 ? 0 : pyRound(100.0 * correct / total);
  final xp = kXpLesson + ((total > 0 && pct >= 90) ? kXpPerfectBonus : 0);

  final perWord = <String, List<bool>>{};
  firstByQ.forEach((qid, ok) {
    final w = wordOf[qid];
    if (w != null && w.isNotEmpty) perWord.putIfAbsent(w, () => []).add(ok);
  });
  final wrong = <String>[
    for (final e in perWord.entries)
      if (e.value.where((v) => v).length / e.value.length < 0.5) e.key,
  ];

  final unit = (session['unit'] as Map?) ?? const {};
  final intro = (session['steps'] as List? ?? const []).cast<dynamic>().whereType<Map>().firstWhere((s) => s['type'] == 'intro', orElse: () => const {});
  final goals = ((intro['goals'] as List?) ?? const []).cast<String>();
  final totalUnits = (unit['total_units'] as num?)?.toInt() ?? 0;
  final out = <String, dynamic>{
    'duplicate': false,
    'local': true,
    'score': {'correct': correct, 'total': total, 'percent': pct},
    'can_do': goals.isNotEmpty ? goals : ['Bạn đã học xong bài ${unit['topic_vi'] ?? ''}'.trim()],
    'wrong_word_ids': wrong,
    'xp_gained': xp,
    'next_unit_id': nextUnitId,
    'level_completed': levelCompleted,
    'unit_id': unit['id'],
  };
  if (completedUnits != null) {
    out['progress'] = {'completed_units': completedUnits + (alreadyCompleted ? 0 : 1), 'total_units': totalUnits, 'level': unit['level']};
  }
  return out;
}

/// Gộp kết quả server vào bản ở máy: server THẮNG ở mọi khóa nó có (lệch thì sửa theo server); giữ `unit_id`.
Map<String, dynamic> mergeServerSummary(Map<String, dynamic> local, Map<String, dynamic> server) {
  if (server['duplicate'] == true) return {...local, 'synced': true};
  return {...local, ...server, 'local': false, 'synced': true, 'unit_id': local['unit_id']};
}

// ───────────────────────── gửi nền + thử lại + hàng đợi lưu máy ─────────────────────────

/// Lỗi vĩnh viễn (400/401?/403/404...) — thử lại vô ích; 408/429/5xx/mất mạng thì thử lại.
bool isPermanentError(Object e) {
  if (e is DioException) {
    final c = e.response?.statusCode;
    if (c == null) return false;
    return c >= 400 && c < 500 && c != 408 && c != 429 && c != 401;
  }
  return false;
}

class PendingResult {
  final String unitId;
  final Map<String, dynamic> body; // session_id = khóa idempotency (server bỏ qua bản gửi trùng)
  const PendingResult(this.unitId, this.body);
  Map<String, dynamic> toJson() => {'unit_id': unitId, 'body': body};
  static PendingResult fromJson(Map<String, dynamic> j) => PendingResult(j['unit_id'] as String, Map<String, dynamic>.from(j['body'] as Map));
}

abstract class PendingStore {
  Future<List<PendingResult>> load();
  Future<void> save(List<PendingResult> items);
}

class PrefsPendingStore implements PendingStore {
  static const _key = 'lesson_v2_pending_results';
  @override
  Future<List<PendingResult>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      return [for (final j in (jsonDecode(raw) as List)) PendingResult.fromJson(Map<String, dynamic>.from(j as Map))];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> save(List<PendingResult> items) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
    } catch (_) {}
  }
}

class MemoryPendingStore implements PendingStore {
  List<PendingResult> items = [];
  @override
  Future<List<PendingResult>> load() async => List.of(items);
  @override
  Future<void> save(List<PendingResult> v) async => items = List.of(v);
}

Future<void> _removePending(PendingStore store, String sessionId) async {
  final cur = await store.load();
  await store.save(cur.where((p) => p.body['session_id'] != sessionId).toList());
}

Future<void> _addPending(PendingStore store, PendingResult r) async {
  final cur = await store.load();
  if (cur.any((p) => p.body['session_id'] == r.body['session_id'])) return;
  await store.save([...cur, r]);
}

typedef Sleeper = Future<void> Function(Duration d);

/// Gửi kết quả lên server ở nền. Lần đầu thất bại (mất mạng/5xx) -> LƯU vào hàng đợi máy rồi thử lại theo [delays]; thành công -> xóa khỏi hàng đợi.
/// Lỗi vĩnh viễn (4xx) -> bỏ, không thử lại. [onState]: 'syncing' | 'retrying' | 'failed' | 'synced'. Trả về phản hồi server (hoặc null nếu bỏ cuộc).
Future<Map<String, dynamic>?> syncLessonResult(
  LessonV2Api api,
  String unitId,
  Map<String, dynamic> body, {
  PendingStore? store,
  List<Duration> delays = const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30), Duration(seconds: 60)],
  Sleeper? sleep,
  void Function(String state)? onState,
  bool Function()? cancelled,
}) async {
  final st = store ?? PrefsPendingStore();
  final wait = sleep ?? (d) => Future.delayed(d);
  onState?.call('syncing');
  var attempt = 0;
  while (true) {
    try {
      final res = await api.submitAnswers(unitId, body);
      await _removePending(st, body['session_id'] as String);
      onState?.call('synced');
      return res;
    } catch (e) {
      if (isPermanentError(e)) {
        await _removePending(st, body['session_id'] as String);
        onState?.call('failed');
        return null;
      }
      await _addPending(st, PendingResult(unitId, body));
      if (attempt >= delays.length || (cancelled?.call() ?? false)) {
        onState?.call('failed');
        return null; // còn trong hàng đợi máy -> gửi lại lần mở app / bài sau
      }
      onState?.call('retrying');
      await wait(delays[attempt]);
      attempt++;
    }
  }
}

/// Gửi lại các kết quả còn kẹt (mất mạng lần trước). Mỗi mục 1 lần thử; thành công / lỗi vĩnh viễn -> xóa. Gọi lúc mở tab Chương trình / trước khi vào bài mới.
Future<int> flushPendingResults(LessonV2Api api, {PendingStore? store}) async {
  final st = store ?? PrefsPendingStore();
  var sent = 0;
  for (final p in await st.load()) {
    try {
      await api.submitAnswers(p.unitId, p.body);
      await _removePending(st, p.body['session_id'] as String);
      sent++;
    } catch (e) {
      if (isPermanentError(e)) await _removePending(st, p.body['session_id'] as String);
    }
  }
  return sent;
}
