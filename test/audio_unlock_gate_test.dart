/// Audit "Safari iOS: TTS khong phat am thanh" (2026-09-04) — xac nhan logic
/// THUAN dang quyet dinh khi nao tao AudioElement THAT (web_utils_impl.dart
/// goi TRUC TIEP class nay, khong sao chep logic rieng cho test): CHI 1 lan
/// duy nhat trong ca session (chinh la fix cho bug goc: truoc day webPlayAudio()
/// tao 1 AudioElement MOI moi lan phat, khong element nao tung duoc WebKit
/// "unlock", nen hau het segment TTS bi Safari lang le chan .play()).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/core/utils/audio_unlock_gate.dart';

void main() {
  test('needsElementCreation() chi tra ve true DUNG 1 LAN, moi lan sau la false', () {
    final gate = AudioUnlockGate();

    expect(gate.needsElementCreation(), isTrue,
        reason: 'Lan dau tien phai tao AudioElement THAT');
    for (var i = 0; i < 10; i++) {
      expect(gate.needsElementCreation(), isFalse,
          reason: 'Tu lan thu 2 tro di PHAI tai su dung element cu, khong tao moi (day chinh la fix cho bug goc)');
    }
    expect(gate.elementCreations, 1,
        reason: 'Du goi needsElementCreation() 11 lan, AudioElement chi duoc tao THAT 1 lan duy nhat');
  });

  test('isUnlocked mac dinh false, chi thanh true SAU markUnlocked()', () {
    final gate = AudioUnlockGate();
    expect(gate.isUnlocked, isFalse);
    gate.markUnlocked();
    expect(gate.isUnlocked, isTrue);
  });

  test('markUnlocked() khong anh huong needsElementCreation() (2 trang thai doc lap)', () {
    final gate = AudioUnlockGate();
    gate.markUnlocked();
    expect(gate.needsElementCreation(), isTrue,
        reason: 'unlock thanh cong khong tu dong nghia la element da duoc tao — 2 khai niem tach biet');
    expect(gate.needsElementCreation(), isFalse);
  });

  test('Moi AudioUnlockGate MOI (vd tao lai khi reload trang) bat dau tu dau, khong dinh trang thai cu', () {
    final gate1 = AudioUnlockGate();
    gate1.needsElementCreation();
    gate1.markUnlocked();

    final gate2 = AudioUnlockGate();
    expect(gate2.elementCreations, 0);
    expect(gate2.isUnlocked, isFalse);
  });
}
