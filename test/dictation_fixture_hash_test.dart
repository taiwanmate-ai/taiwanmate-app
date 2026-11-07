// Nợ kỹ thuật #11 (backend docs/tech_debt.md, CTO 03/11/2026): 2 file hợp đồng nghe chép là BẢN SAO NGUYÊN VĂN của backend `data/`.
// sha256 dưới đây PHẢI giống hệt `FIXTURE_SHA256` trong backend `test_dictation.py`. Backend đổi file → chép lại sang đây + sửa hash ở CẢ 2 repo.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const fixtureSha256 = {
  'test/fixtures/dictation_normalize_cases.json': '547cd5c025d7a836e9e56c2da0d587094120c123790d96634d3392fc812650a7',
  'assets/data/dictation_pinyin_syllables.json': '4b9090064755e7c3d832cbb55d4eff7f8a20b5eeab40362ad6277185b81956cc',
};

void main() {
  for (final e in fixtureSha256.entries) {
    test('sha256 ${e.key} khớp backend', () {
      final got = sha256.convert(File(e.key).readAsBytesSync()).toString();
      expect(got, e.value, reason: '${e.key} lệch bản backend: chép lại từ taiwanmate-backend/data/ và cập nhật hash ở cả 2 repo');
    });
  }
}
