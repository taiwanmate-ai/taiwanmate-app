import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chinesemate/core/services/payment_service.dart';
import 'package:chinesemate/core/utils/web_utils.dart';

/// Tao Checkout Session THAT tren Polar (GET /payment/checkout-url, backend
/// da tra ve URL Polar that — xem app/api/v1/payment.py) roi mo bang
/// url_launcher — thay the hoan toan nhanh dieu huong sang ManualPaymentScreen
/// (thanh toan thu cong) tung ton tai o day cho ca web. KHONG dung
/// PaymentService.openCheckout()/webOpenUrl() cu (van con gan voi fallbackUrl
/// Lemon Squeezy da chet, khong lien quan Polar).
///
/// Tach thanh ham chung PUBLIC o day (thay vi de private trong 1 man hinh
/// cu the) vi Dart coi ham co tien to "_" la PRIVATE THEO TUNG FILE (khong
/// phai theo package/feature) — profile_screen.dart va paywall_screen.dart
/// la 2 file/library rieng biet, KHONG THE import lan nhau 1 ham private.
/// Dat ngang cap voi manual_payment_screen.dart/paywall_screen.dart (dung
/// quy uoc file phang da co san trong thu muc lib/features/profile/), tranh
/// nhet logic mo URL/hien SnackBar (thuoc lop UI) vao PaymentService (hien
/// dang la lop logic/API thuan tuy, khong phu thuoc BuildContext).
///
/// LaunchMode.externalApplication — dung QUY UOC DA CO san trong du an
/// (home_screen.dart, tools_screen.dart, main_shell.dart deu dung y het mode
/// nay cho launchUrl), tren web se mo tab moi thay vi dieu huong mat trang
/// hien tai.
Future<void> startPolarCheckout(BuildContext context, {required String plan, String product = 'vip'}) async {
  // Audit "nut mua Voice khong bam duoc tren iOS Safari" (2026-09-02) —
  // TRUOC DAY: await createCheckout() (goi API, co do tre mang) RỒI MỚI
  // launchUrl()/window.open() — tren cac trinh duyet chan popup nghiem
  // ngat (dac biet Safari iOS), khoang cho async giua luc tap va luc
  // window.open() thuc su chay khien trinh duyet KHONG con coi day la
  // hanh dong nguoi dung nua -> popup bi chan AM THAM (khong hien loi,
  // giong nhu nut khong phan ung gi). Web KHAC: mo 1 tab TRANG NGAY LUC
  // NAY (dong bo, truoc BAT KY await nao) de giu "user activation" hop
  // le, roi dieu huong tab do SAU KHI co URL that — xem docstring
  // webOpenBlankWindow()/webNavigateWindow() (web_utils_impl.dart).
  final windowHandle = kIsWeb ? webOpenBlankWindow() : null;
  // Hiem: trinh duyet chan luon ca tab TRANG (vd cai dat chan popup o muc
  // nghiem ngat nhat) — bao loi NGAY, khong goi API tao Checkout Session
  // vo ich (khong con noi de dieu huong toi).
  if (kIsWeb && windowHandle == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở trang thanh toán, vui lòng thử lại sau')),
      );
    }
    return;
  }
  try {
    final url = await PaymentService.createCheckout(plan: plan, product: product);
    if (kIsWeb) {
      webNavigateWindow(windowHandle, url);
      return;
    }
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở trang thanh toán, vui lòng thử lại sau')),
      );
    }
  } catch (e) {
    if (kIsWeb) webCloseWindow(windowHandle);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tạo phiên thanh toán, vui lòng thử lại sau')),
      );
    }
  }
}
