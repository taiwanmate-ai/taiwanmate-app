/// Audit "khong thay CTA mua Voice tren man hinh test noi bo" (2026-09-02) —
/// server bao {"type":"voice_access_required","message":...} khi user thieu/
/// het han voice_access (2 nhanh dau cua _has_active_voice_access trong
/// voice_ws.py) — TRUOC DAY dung chung type "error" voi moi loi khac, khien
/// UI khong co cach nao phan biet de hien nut "Mua gói Voice ngay" dan toi
/// VipScreen. Test nay xac nhan VoiceWebSocketService dinh tuyen DUNG
/// callback rieng (onVoiceAccessRequired), khong lan sang onConnectionError.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/voice_websocket_service.dart';

void main() {
  test('type=voice_access_required goi onVoiceAccessRequired VOI DUNG message, KHONG goi onConnectionError', () {
    final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');

    String? capturedVoiceAccessMessage;
    var connectionErrorCallCount = 0;
    wsService.onVoiceAccessRequired = (message) => capturedVoiceAccessMessage = message;
    wsService.onConnectionError = (_) => connectionErrorCallCount++;

    wsService.handleRawMessageForTesting(
      jsonEncode({'type': 'voice_access_required', 'message': 'Bạn cần mua gói Voice để dùng tính năng này'}),
    );

    expect(capturedVoiceAccessMessage, 'Bạn cần mua gói Voice để dùng tính năng này');
    expect(connectionErrorCallCount, 0,
        reason: 'voice_access_required PHAI di rieng callback, khong duoc lan sang onConnectionError (khac loi thuong, can hien CTA mua)');
  });

  test('type=error (vd tai khoan bi khoa) VAN goi onConnectionError nhu cu, KHONG goi onVoiceAccessRequired', () {
    final wsService = VoiceWebSocketService(tokenProvider: () async => 'fake-token');

    String? capturedConnectionErrorMessage;
    var voiceAccessRequiredCallCount = 0;
    wsService.onConnectionError = (message) => capturedConnectionErrorMessage = message;
    wsService.onVoiceAccessRequired = (_) => voiceAccessRequiredCallCount++;

    wsService.handleRawMessageForTesting(
      jsonEncode({'type': 'error', 'message': 'Tài khoản đã bị khóa'}),
    );

    expect(capturedConnectionErrorMessage, 'Tài khoản đã bị khóa');
    expect(voiceAccessRequiredCallCount, 0,
        reason: 'Loi KHAC (khong lien quan voice_access) khong duoc kich hoat CTA mua Voice');
  });
}
