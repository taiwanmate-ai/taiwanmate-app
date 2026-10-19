// Ket qua bai hoc tinh o may (2026-10-20): cong thuc PHAI giong server (lesson_service.submit_results), gui nen + thu lai + hang doi may,
// va chi cap nhat bai vua hoc + bai ke tiep (khong tai lai danh sach).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/curriculum_tab.dart';
import 'package:chinesemate/features/lesson_v2/lesson_result.dart';
import 'package:chinesemate/features/lesson_v2/lesson_runner.dart';
import 'package:chinesemate/features/lesson_v2/lesson_v2_api.dart';

class _Api implements LessonV2Api {
  final List<Object?> script; // moi lan goi: null = thanh cong, Exception = nem
  int calls = 0;
  final bodies = <Map<String, dynamic>>[];
  _Api(this.script);
  @override
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body) async {
    bodies.add(body);
    final step = calls < script.length ? script[calls] : null;
    calls++;
    if (step is Exception) throw step;
    return {'duplicate': false, 'score': {'correct': 1, 'total': 1, 'percent': 100}, 'xp_gained': 40, 'streak_days': 3, 'due_tomorrow': 2};
  }

  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) => throw UnimplementedError();
  @override
  Future<void> reportQuestion(String questionId, {String? reason}) async {}
  @override
  Future<Map<String, dynamic>> submitGame(int matched, int misses) async => {};
  @override
  Future<void> playAudio(Map<String, dynamic>? audio) async {}
}

DioException _http(int code) => DioException(requestOptions: RequestOptions(path: '/x'), response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: code));
DioException _net() => DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);

Map<String, dynamic> _session(List<List<String>> qs) => {
      'session_id': 'S9',
      'unit': {'id': 'u9', 'order': 3, 'total_units': 12, 'topic_vi': 'Ẩm thực', 'level': 'A1'},
      'steps': [
        {'type': 'intro', 'goals': ['Gọi món', 'Hỏi giá']},
        {
          'type': 'practice',
          'questions': <Map<String, dynamic>>[for (final q in qs) <String, dynamic>{'id': q[0], 'word_id': q[1]}]
        },
      ],
      'retry': {
        'alts': {
          'w1': [
            {'id': 'alt1', 'word_id': 'w1'}
          ]
        }
      },
    };

void main() {
  group('pyRound = round() cua Python (lam tron ve so CHAN khi .5)', () {
    test('12.5->12, 62.5->62, 37.5->38, 90.5->90, 89.5->90, 0.5->0, 1.5->2', () {
      expect(pyRound(12.5), 12);
      expect(pyRound(62.5), 62);
      expect(pyRound(37.5), 38);
      expect(pyRound(90.5), 90);
      expect(pyRound(89.5), 90);
      expect(pyRound(0.5), 0);
      expect(pyRound(1.5), 2);
      expect(pyRound(88.0), 88);
      expect(pyRound(33.333), 33);
      expect(pyRound(66.667), 67);
    });
  });

  group('computeLocalSummary giong cong thuc server', () {
    // (dung, tong) -> (phan tram, xp) lay tu chinh cong thuc server bang Python round()
    const cases = [
      [1, 8, 12, 30], [7, 8, 88, 30], [5, 8, 62, 30], [3, 8, 38, 30], [9, 10, 90, 40], [18, 20, 90, 40], [45, 50, 90, 40], [0, 0, 0, 30],
    ];
    for (final c in cases) {
      test('dung ${c[0]} / tong ${c[1]} -> ${c[2]}% , +${c[3]} XP', () {
        final qs = [for (var i = 0; i < c[1]; i++) ['q$i', 'w$i']];
        final recs = [for (var i = 0; i < c[1]; i++) AnswerRecord('q$i', i < c[0], 1, 1000)];
        final s = computeLocalSummary(_session(qs), recs);
        expect((s['score'] as Map)['percent'], c[2]);
        expect((s['score'] as Map)['correct'], c[0]);
        expect((s['score'] as Map)['total'], c[1]);
        expect(s['xp_gained'], c[3]);
      });
    }

    test('chi tinh lan DAU cua tung cau (lam lai attempt 2 khong tinh); toi da 50 cau', () {
      final qs = [for (var i = 0; i < 3; i++) ['q$i', 'w$i']];
      final recs = [AnswerRecord('q0', true, 1, 1), AnswerRecord('q1', false, 1, 1), AnswerRecord('q1', true, 2, 1), AnswerRecord('q2', true, 1, 1)];
      final s = computeLocalSummary(_session(qs), recs);
      expect((s['score'] as Map)['correct'], 2);
      expect((s['score'] as Map)['total'], 3);
      final many = [for (var i = 0; i < 60; i++) AnswerRecord('m$i', true, 1, 1)];
      final s2 = computeLocalSummary(_session([for (var i = 0; i < 60; i++) ['m$i', 'w$i']]), many);
      expect((s2['score'] as Map)['total'], 50);
    });

    test('tu sai = ti le dung cua cac cau dau tien cua tu < 50% (ke ca cau lam lai khac dang); khong co word_id thi bo qua', () {
      final session = _session([
        ['a', 'w1'],
        ['b', 'w1'],
        ['c', 'w2'],
        ['d', null.toString()],
      ]);
      (session['steps'] as List)[1]['questions'][3] = <String, dynamic>{'id': 'd', 'word_id': null};
      final recs = [AnswerRecord('a', false, 1, 1), AnswerRecord('b', false, 1, 1), AnswerRecord('alt1', true, 2, 1), AnswerRecord('c', true, 1, 1), AnswerRecord('d', false, 1, 1)];
      final s = computeLocalSummary(session, recs);
      expect(s['wrong_word_ids'], ['w1']); // w1: 0/2 dung; w2 dung; cau d khong co tu
    });

    test('tien do: da xong + 1 (hoac giu nguyen neu bai nay da xong tu truoc); co goi y bai ke tiep / cuoi cap', () {
      final recs = [AnswerRecord('q0', true, 1, 1)];
      final a = computeLocalSummary(_session([['q0', 'w']]), recs, completedUnits: 3, nextUnitId: 'next');
      expect(a['progress'], {'completed_units': 4, 'total_units': 12, 'level': 'A1'});
      expect(a['next_unit_id'], 'next');
      expect(a['level_completed'], false);
      final b = computeLocalSummary(_session([['q0', 'w']]), recs, completedUnits: 3, alreadyCompleted: true, levelCompleted: true);
      expect((b['progress'] as Map)['completed_units'], 3);
      expect(b['level_completed'], true);
      expect(computeLocalSummary(_session([['q0', 'w']]), recs).containsKey('progress'), false); // thieu goi y -> doi server
      expect(a['can_do'], ['Gọi món', 'Hỏi giá']);
    });
  });

  test('mergeServerSummary: server thang o moi khoa no co, giu unit_id; duplicate -> giu ban o may', () {
    final local = {'score': {'correct': 2, 'total': 3, 'percent': 67}, 'xp_gained': 30, 'unit_id': 'u9', 'local': true};
    final m = mergeServerSummary(local, {'duplicate': false, 'score': {'correct': 3, 'total': 4, 'percent': 75}, 'xp_gained': 40, 'streak_days': 5});
    expect((m['score'] as Map)['percent'], 75);
    expect(m['xp_gained'], 40);
    expect(m['streak_days'], 5);
    expect(m['unit_id'], 'u9');
    expect(m['local'], false);
    final d = mergeServerSummary(local, {'duplicate': true});
    expect((d['score'] as Map)['percent'], 67);
    expect(d['synced'], true);
  });

  group('gui nen + thu lai + hang doi may', () {
    final body = {'session_id': 'S9', 'results': []};
    test('thanh cong lan dau: khong luu hang doi', () async {
      final api = _Api([null]);
      final store = MemoryPendingStore();
      final res = await syncLessonResult(api, 'u9', body, store: store, sleep: (d) async {});
      expect(res!['xp_gained'], 40);
      expect(api.calls, 1);
      expect(store.items, isEmpty);
    });

    test('mat mang 2 lan roi thanh cong: DUNG 3 lan goi, cung session_id, hang doi rong; thu tu tinh trang', () async {
      final api = _Api([_net(), _http(503), null]);
      final store = MemoryPendingStore();
      final states = <String>[];
      final waits = <Duration>[];
      final res = await syncLessonResult(api, 'u9', body, store: store, sleep: (d) async => waits.add(d), onState: states.add, delays: const [Duration(seconds: 2), Duration(seconds: 5)]);
      expect(res, isNotNull);
      expect(api.calls, 3);
      expect(api.bodies.map((b) => b['session_id']).toSet(), {'S9'});
      expect(waits, [const Duration(seconds: 2), const Duration(seconds: 5)]);
      expect(states, ['syncing', 'retrying', 'retrying', 'synced']);
      expect(store.items, isEmpty);
    });

    test('het so lan thu: tra null, KET QUA CON TRONG hang doi may (khong mat)', () async {
      final api = _Api([_net(), _net(), _net(), _net()]);
      final store = MemoryPendingStore();
      final res = await syncLessonResult(api, 'u9', body, store: store, sleep: (d) async {}, delays: const [Duration(seconds: 1), Duration(seconds: 1)]);
      expect(res, isNull);
      expect(api.calls, 3);
      expect(store.items.length, 1);
      expect(store.items.first.unitId, 'u9');
    });

    test('loi vinh vien 4xx (400/403/404): KHONG thu lai, khong giu hang doi', () async {
      for (final code in [400, 403, 404]) {
        final api = _Api([_http(code)]);
        final store = MemoryPendingStore();
        final res = await syncLessonResult(api, 'u9', body, store: store, sleep: (d) async {});
        expect(res, isNull);
        expect(api.calls, 1);
        expect(store.items, isEmpty);
      }
    });

    test('408 / 429 / 401 / 5xx / mat mang la loi TAM THOI (thu lai)', () {
      for (final c in [408, 429, 401, 500, 502, 503]) {
        expect(isPermanentError(_http(c)), false, reason: '$c');
      }
      expect(isPermanentError(_net()), false);
      for (final c in [400, 403, 404, 422]) {
        expect(isPermanentError(_http(c)), true, reason: '$c');
      }
    });

    test('flushPendingResults: gui lai cac ket qua ket, xoa muc thanh cong / loi vinh vien, giu muc con loi tam thoi', () async {
      final store = MemoryPendingStore()
        ..items = [
          PendingResult('u1', {'session_id': 'A', 'results': []}),
          PendingResult('u2', {'session_id': 'B', 'results': []}),
          PendingResult('u3', {'session_id': 'C', 'results': []}),
        ];
      final api = _Api([null, _http(404), _net()]);
      final sent = await flushPendingResults(api, store: store);
      expect(sent, 1);
      expect(store.items.map((p) => p.body['session_id']).toList(), ['C']);
    });

    test('khong luu trung 1 session_id khi thu lai nhieu lan', () async {
      final api = _Api([_net(), _net(), _net(), _net(), _net()]);
      final store = MemoryPendingStore();
      await syncLessonResult(api, 'u9', body, store: store, sleep: (d) async {}, delays: const [Duration(seconds: 1), Duration(seconds: 1), Duration(seconds: 1)]);
      expect(store.items.length, 1);
    });
  });

  // ── Man danh sach: sau bai hoc v2 CHI cap nhat bai vua hoc + bai ke tiep, KHONG tai lai danh sach ──
  group('CurriculumTab sau bai hoc v2', () {
    testWidgets('khong goi lai GET units; bai vua hoc = completed, bai ke tiep mo khoa', (tester) async {
      var unitsCalls = 0;
      final dio = Dio();
      dio.httpClientAdapter = _Adapter((path) {
        if (path.endsWith('/zh/levels')) return {'levels': [{'level': 'A1', 'total_units': 2, 'completed_units': 0}]};
        if (path.endsWith('/zh/A1/units')) {
          unitsCalls++;
          return {
            'units': [
              {'unit_id': 'u-a', 'level': 'A1', 'unit_order': 1, 'topic_vi': 'Bai A', 'status': 'unlocked', 'is_vip_locked': false},
              {'unit_id': 'u-b', 'level': 'A1', 'unit_order': 2, 'topic_vi': 'Bai B', 'status': 'locked', 'is_vip_locked': false},
            ]
          };
        }
        return null;
      });
      final api = _SessionApi();
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [lessonV2EnabledProvider.overrideWith((ref) async => true), lessonV2ApiProvider.overrideWithValue(api)],
        child: MaterialApp(home: Scaffold(body: CurriculumTab(initialLanguage: 'zh', initialLevel: 'A1', dio: dio, readToken: () async => 't'))),
      ));
      await tester.pumpAndSettle();
      expect(unitsCalls, 1);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget); // bai B khoa
      await tester.tap(find.text('Bai A'));
      await tester.pumpAndSettle();
      // phien chi co buoc intro -> bam Bat dau -> man ket qua (tinh o may, khong cho server)
      await tester.tap(find.byKey(const Key('lesson_start_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('summary_title')), findsOneWidget);
      expect(find.textContaining('Chặng A1: 1/2'), findsOneWidget); // tien do tinh o may: 0 + 1 / 2
      await tester.tap(find.byKey(const Key('summary_continue')));
      await tester.pumpAndSettle();
      expect(unitsCalls, 1, reason: 'KHONG tai lai danh sach sau bai hoc');
      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // bai A completed
      expect(find.byIcon(Icons.lock_rounded), findsNothing); // bai B da mo khoa (khong goi mang)
      expect(api.submitCalls, 1);
    });
  });
}

class _SessionApi implements LessonV2Api {
  int submitCalls = 0;
  @override
  Future<Map<String, dynamic>> fetchSession(String unitId) async => {
        'session_id': 'S1',
        'unit': {'id': unitId, 'order': 1, 'total_units': 2, 'topic_vi': 'Bai A', 'level': 'A1', 'language': 'zh'},
        'steps': [
          {'type': 'intro', 'title': 'Bai A', 'goals': ['x'], 'estimated_minutes': 5}
        ],
        'retry': {'alts': {}},
      };
  @override
  Future<Map<String, dynamic>> submitAnswers(String unitId, Map<String, dynamic> body) async {
    submitCalls++;
    return {'duplicate': false, 'score': {'correct': 0, 'total': 0, 'percent': 0}, 'can_do': ['x'], 'wrong_word_ids': [], 'due_tomorrow': 0, 'xp_gained': 30, 'total_xp': 30, 'streak_days': 1, 'progress': {'completed_units': 1, 'total_units': 2, 'level': 'A1'}, 'next_unit_id': 'u-b', 'level_completed': false};
  }

  @override
  Future<void> reportQuestion(String questionId, {String? reason}) async {}
  @override
  Future<Map<String, dynamic>> submitGame(int matched, int misses) async => {};
  @override
  Future<void> playAudio(Map<String, dynamic>? audio) async {}
}

class _Adapter implements HttpClientAdapter {
  final Object? Function(String path) handler;
  _Adapter(this.handler);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final v = handler(o.path);
    if (v == null) return ResponseBody.fromString('not found', 404);
    return ResponseBody.fromString(jsonEncode(v), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
