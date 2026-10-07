import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:chinesemate/app/router/app_router.dart';

/// Lưới an toàn toàn cục (2026-10-06, audit toàn app sau bug "màn trắng" CTA ngữ pháp) cho
/// LỖI XẢY RA ĐỒNG BỘ TRONG build() — thay thế màn trắng/xám mặc định của Flutter ở BẢN
/// RELEASE/PROFILE bằng 1 thẻ lỗi thân thiện, LUÔN có lối thoát (không bao giờ để user bị kẹt):
///   - `Navigator.canPop(context) == true` → nút "Quay lại" (`Navigator.pop`).
///   - `canPop == false` (ví dụ lỗi ở TRANG GỐC của 1 tab/shell route GoRouter, không có gì
///     để pop) → nút "Về trang chủ" điều hướng bằng GoRouter tới `/home`.
/// Gắn ở `main()` (xem `main.dart`) CHỈ khi KHÔNG debug (`kDebugMode == false`) — bản debug
/// GIỮ NGUYÊN màn đỏ mặc định của Flutter để dev thấy đúng chi tiết lỗi.
///
/// GIỚI HẠN (xem audit) — chỉ bắt được lỗi ĐỒNG BỘ trong `build()` (cơ chế `ErrorWidget` của
/// Flutter), KHÔNG bắt được lỗi trong `initState()`/callback async/`onTap`. Đây là lưới BỔ
/// SUNG, không thay thế việc tự phòng thủ ở từng màn hình cụ thể (xem grammar_tool_screen.dart,
/// tools_screen.dart::parseGrammarAnalysisData, translate_screen.dart::parseRiskAnalysisItem).
///
/// `onGoHome` chỉ dùng để test (thay `appRouter.go('/home')` thật) — mặc định null = điều
/// hướng thật.
Widget buildGlobalErrorWidget(FlutterErrorDetails details, {VoidCallback? onGoHome}) {
  return Builder(builder: (context) {
    final canPop = Navigator.of(context).canPop();
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Đã có lỗi hiển thị',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1D2E))),
              const SizedBox(height: 8),
              const Text('Vui lòng thử lại.',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A8FA3))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: canPop
                    ? () => Navigator.of(context).pop()
                    : (onGoHome ?? () => appRouter.go('/home')),
                child: Text(canPop ? 'Quay lại' : 'Về trang chủ'),
              ),
            ]),
          ),
        ),
      ),
    );
  });
}

/// Gắn `ErrorWidget.builder` toàn cục — tách riêng khỏi `main()` để TEST ĐƯỢC cả 2 nhánh.
/// `kDebugMode` là hằng số Dart (cố định theo build mode, không đổi được lúc chạy test), nên
/// tham số `debug` (mặc định = `kDebugMode` thật) cho phép test GIẢ LẬP cả 2 nhánh mà không
/// cần build thật ở release — xác nhận: debug=true GIỮ NGUYÊN `ErrorWidget.builder` mặc định
/// của Flutter (không gán gì), debug=false mới gán `buildGlobalErrorWidget`.
void installGlobalErrorWidget({bool debug = kDebugMode}) {
  if (!debug) {
    ErrorWidget.builder = buildGlobalErrorWidget;
  }
}
