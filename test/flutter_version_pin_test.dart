// CTO 07/11/2026: mọi phiên dùng ĐÚNG Flutter 3.44.2 (bản build production). `environment.flutter` trong pubspec.yaml KHÔNG chặn được
// bản mới hơn (pub bỏ qua cận trên của ràng buộc Flutter — đã thử với 3.47.7), nên chốt ở đây: chạy test bằng bản khác -> đỏ.
// Nâng bản: sửa kFlutterVersion + pubspec.yaml + .fvmrc + README trong cùng 1 commit.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const kFlutterVersion = '3.44.2';

void main() {
  test('đang chạy đúng Flutter $kFlutterVersion', () {
    final root = Platform.environment['FLUTTER_ROOT'];
    expect(root, isNotNull, reason: 'flutter test luôn đặt FLUTTER_ROOT');
    final f = File('$root/bin/cache/flutter.version.json');
    final version = f.existsSync() ? (jsonDecode(f.readAsStringSync()) as Map)['frameworkVersion'] : File('$root/version').readAsStringSync().trim();
    expect(version, kFlutterVersion, reason: 'Dùng Flutter $kFlutterVersion (README "Phiên bản Flutter"); bản khác đổi pubspec.lock');
  });

  test('pubspec.yaml và .fvmrc ghim cùng bản', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('  flutter: $kFlutterVersion\n'));
    expect((jsonDecode(File('.fvmrc').readAsStringSync()) as Map)['flutter'], kFlutterVersion);
  });
}
