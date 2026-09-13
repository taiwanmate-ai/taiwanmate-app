// Idea #3 (2026-09-13) — cau khan cap dong goi san (dich + TTS tao 1 lan
// luc build, xem assets/data/emergency_phrases.json) de hoat dong OFFLINE
// 100%. Test nay xac nhan: file manifest ton tai/parse dung, DAY DU field
// bat buoc, va MOI audio_asset tham chieu THAT SU load duoc (khong rong)
// — day la lop bao ve chinh, tranh truong hop quen dong goi 1 file .mp3
// hoac go sai duong dan trong pubspec.yaml ma khong bi phat hien cho toi
// khi user thuc te bam nut luc khong co mang.
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('emergency_phrases.json parse dung, du field bat buoc', () async {
    final raw = await rootBundle.loadString('assets/data/emergency_phrases.json');
    final parsed = jsonDecode(raw) as List;

    expect(parsed.length, greaterThanOrEqualTo(6));
    for (final raw in parsed) {
      final p = raw as Map<String, dynamic>;
      expect(p['id'], isA<String>());
      expect((p['id'] as String).isNotEmpty, isTrue);
      expect(p['vi'], isA<String>());
      expect((p['vi'] as String).isNotEmpty, isTrue, reason: 'vi rong cho id=${p['id']}');
      expect(p['zh'], isA<String>());
      expect((p['zh'] as String).isNotEmpty, isTrue, reason: 'zh rong cho id=${p['id']}');
      expect(p['pinyin'], isA<String>());
      expect((p['pinyin'] as String).isNotEmpty, isTrue, reason: 'pinyin rong cho id=${p['id']}');
      expect(p['audio_asset'], isA<String>());
      expect(p['icon'], isA<String>());
    }
  });

  test('moi audio_asset tham chieu trong manifest deu load duoc va khong rong', () async {
    final raw = await rootBundle.loadString('assets/data/emergency_phrases.json');
    final parsed = jsonDecode(raw) as List;

    for (final raw in parsed) {
      final p = raw as Map<String, dynamic>;
      final assetPath = p['audio_asset'] as String;
      final data = await rootBundle.load(assetPath);
      expect(data.lengthInBytes, greaterThan(1000),
          reason: '$assetPath (id=${p['id']}) phai la file mp3 that, khong rong/hong');
    }
  });

  test('khong co id trung lap trong manifest', () async {
    final raw = await rootBundle.loadString('assets/data/emergency_phrases.json');
    final parsed = jsonDecode(raw) as List;
    final ids = parsed.map((p) => (p as Map<String, dynamic>)['id'] as String).toList();
    expect(ids.toSet().length, ids.length, reason: 'Phat hien id trung lap: $ids');
  });
}
