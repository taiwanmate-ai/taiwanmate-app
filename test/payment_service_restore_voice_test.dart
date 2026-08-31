/// Audit "VIP Voice UI" (2026-08-31) — lo hong da phat hien: truoc day
/// PaymentService.restorePurchases() chi nhan dien 2 Product ID VIP text-chat
/// ('vip_monthly'/'vip_yearly') qua _productIds — mot giao dich Voice
/// ('voice_monthly'/'voice_yearly') khoi phuc (vd cai lai app/doi may) se bi
/// BO QUA HOAN TOAN (khong goi verify-google-purchase), khien user da tra
/// tien Voice MAT quyen loi. Da fix bang cach mo rong _productIds + tach 2
/// ham THUAN isRestorableProductId()/shouldMarkVipStatus() de test truc tiep
/// (khong can mock InAppPurchase plugin/platform channel that — restorePurchases()
/// va purchaseAndroid() GOI LAI CHINH 2 ham nay, khong sao chep logic rieng).
///
/// Test xac nhan CA 4 Product ID that (2 VIP text-chat cu + 2 Voice moi):
/// deu duoc restorePurchases() nhan dien (khong bi bo qua), VA dung field
/// tuong ung duoc danh dau de cap nhat — VIP -> UserState.isVipNotifier,
/// Voice -> KHONG dung co nay (backend tu cap voice_access qua
/// verify-google-purchase, doc lap hoan toan voi VIP).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/core/services/payment_service.dart';

void main() {
  group('isRestorableProductId() — restorePurchases() phai nhan dien ca 4 Product ID that', () {
    test('vip_monthly duoc nhan dien', () {
      expect(PaymentService.isRestorableProductId('vip_monthly'), isTrue);
    });
    test('vip_yearly duoc nhan dien', () {
      expect(PaymentService.isRestorableProductId('vip_yearly'), isTrue);
    });
    test('voice_monthly duoc nhan dien (TRUOC DAY la lo hong — bi bo qua)', () {
      expect(PaymentService.isRestorableProductId('voice_monthly'), isTrue);
    });
    test('voice_yearly duoc nhan dien (TRUOC DAY la lo hong — bi bo qua)', () {
      expect(PaymentService.isRestorableProductId('voice_yearly'), isTrue);
    });
    test('Product ID la (khong lien quan) khong duoc nhan dien', () {
      expect(PaymentService.isRestorableProductId('some_other_product'), isFalse);
    });
  });

  group('shouldMarkVipStatus() — chi bat co VIP text-chat cho DUNG 2 goi VIP, khong lan sang Voice', () {
    test('vip_monthly -> BAT co VIP', () {
      expect(PaymentService.shouldMarkVipStatus('vip_monthly'), isTrue);
    });
    test('vip_yearly -> BAT co VIP', () {
      expect(PaymentService.shouldMarkVipStatus('vip_yearly'), isTrue);
    });
    test('voice_monthly -> KHONG bat co VIP (entitlement rieng biet)', () {
      expect(PaymentService.shouldMarkVipStatus('voice_monthly'), isFalse);
    });
    test('voice_yearly -> KHONG bat co VIP (entitlement rieng biet)', () {
      expect(PaymentService.shouldMarkVipStatus('voice_yearly'), isFalse);
    });
  });

  test('Ca 4 Product ID that: nhan dien DUNG va khong lan lon co VIP/Voice', () {
    const expected = {
      'vip_monthly': true,
      'vip_yearly': true,
      'voice_monthly': false,
      'voice_yearly': false,
    };
    for (final entry in expected.entries) {
      expect(
        PaymentService.isRestorableProductId(entry.key),
        isTrue,
        reason: '${entry.key} phai duoc restorePurchases() nhan dien (khong bo qua)',
      );
      expect(
        PaymentService.shouldMarkVipStatus(entry.key),
        entry.value,
        reason: '${entry.key} phai ${entry.value ? "BAT" : "KHONG bat"} co VIP text-chat',
      );
    }
  });
}
