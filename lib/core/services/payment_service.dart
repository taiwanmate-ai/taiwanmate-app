import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../state/user_state.dart';
import '../utils/web_utils.dart';
import '../network/dio_client.dart';


class PaymentService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static const _storage = FlutterSecureStorage();
  static const _productIds = {'vip_monthly', 'vip_yearly'};

  /// Web — giữ nguyên luồng Lemon Squeezy cũ, không đổi
  static void openCheckout({required String plan, required String fallbackUrl}) {
    try {
      webOpenUrl(fallbackUrl);
    } catch (e) {}
  }

  /// Android — luồng Google Play Billing mới
  /// onSuccess: gọi khi verify thành công, dùng để đóng dialog/hiện thông báo
  /// onError: gọi khi có lỗi, truyền message hiển thị cho user
  static Future<void> purchaseAndroid({
    required String plan, // 'monthly' hoặc 'yearly'
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) async {
    final productId = plan == 'yearly' ? 'vip_yearly' : 'vip_monthly';

    final bool available = await _iap.isAvailable();
    if (!available) {
      onError('Google Play Billing không khả dụng trên thiết bị này');
      return;
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      onError('Không tìm thấy gói VIP. Vui lòng thử lại sau');
      return;
    }

    late final Stream<List<PurchaseDetails>> purchaseStream;
    purchaseStream = _iap.purchaseStream;

    final subscription = purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;

        if (purchase.status == PurchaseStatus.pending) {
          continue;
        }

        if (purchase.status == PurchaseStatus.error) {
          onError('Giao dịch thất bại: ${purchase.error?.message ?? "Lỗi không xác định"}');
          if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final verified = await _verifyWithBackend(
            purchaseToken: purchase.verificationData.serverVerificationData,
            productId: productId,
          );

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          if (verified) {
            UserState.updateVipStatus(true);
            onSuccess();
          } else {
            onError('Không thể xác thực giao dịch. Vui lòng liên hệ hỗ trợ');
          }
        }
      }
    }, onError: (e) {
      onError('Lỗi xử lý giao dịch: $e');
    });

    final purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      onError('Không thể khởi tạo giao dịch: $e');
      subscription.cancel();
    }
  }
  /// Khôi phục giao dịch VIP đã mua trước đó nhưng chưa verify thành công
  /// (dùng khi: cài lại app, đổi máy, hoặc verify backend từng lỗi tạm thời)
  static Future<void> restorePurchases({
    required void Function() onSuccess,
    required void Function(String message) onError,
  }) async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      onError('Google Play Billing không khả dụng trên thiết bị này');
      return;
    }

    late StreamSubscription<List<PurchaseDetails>> subscription;
    bool handled = false;

    subscription = _iap.purchaseStream.listen((purchases) async {
      bool foundValid = false;

      for (final purchase in purchases) {
        if (!_productIds.contains(purchase.productID)) continue;

        if (purchase.status == PurchaseStatus.error) {
          if (purchase.pendingCompletePurchase) await _iap.completePurchase(purchase);
          continue;
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final verified = await _verifyWithBackend(
            purchaseToken: purchase.verificationData.serverVerificationData,
            productId: purchase.productID,
          );

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }

          if (verified) {
            foundValid = true;
            UserState.updateVipStatus(true);
          }
        }
      }

      if (!handled) {
        handled = true;
        subscription.cancel();
        if (foundValid) {
          onSuccess();
        } else {
          onError('Không tìm thấy giao dịch VIP hợp lệ để khôi phục');
        }
      }
    }, onError: (e) {
      if (!handled) {
        handled = true;
        subscription.cancel();
        onError('Lỗi khôi phục giao dịch: $e');
      }
    });

    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (!handled) {
        handled = true;
        subscription.cancel();
        onError('Không thể khôi phục giao dịch: $e');
      }
    }

    // Timeout dự phòng: nếu Google không trả gì sau 10s (không có gì để restore)
    Future.delayed(const Duration(seconds: 10), () {
      if (!handled) {
        handled = true;
        subscription.cancel();
        onError('Không có giao dịch nào để khôi phục');
      }
    });
  }

  static Future<bool> _verifyWithBackend({
    required String purchaseToken,
    required String productId,
  }) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/payment/verify-google-purchase',
        data: {'purchase_token': purchaseToken, 'product_id': productId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return res.data['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }
  /// Lấy URL checkout Polar thật (dùng cho web) — backend tạo Checkout
  /// Session qua polar_sdk, khóa sẵn customer_email theo user đang đăng nhập.
  static Future<String> createCheckout({String plan = 'monthly'}) async {
    final response = await DioClient.instance.get(
      '/payment/checkout-url',
      queryParameters: {'plan': plan},
    );
    return response.data['url'];
  }

  /// Kiểm tra trạng thái subscription hiện tại
  static Future<Map<String, dynamic>> getStatus() async {
    final response = await DioClient.instance.get('/payment/status');
    return response.data;
  }

  /// Gửi yêu cầu thanh toán thủ công qua QR (chờ admin duyệt)
  static Future<void> submitManualPayment({
    required String plan,
    required String receiptUrl,
    String note = '',
  }) async {
    await DioClient.instance.post('/payment/manual/submit', data: {
      'plan': plan,
      'receipt_url': receiptUrl,
      'note': note,
    });
  }
}