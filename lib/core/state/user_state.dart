import 'package:flutter/foundation.dart';

/// Singleton đơn giản để 3 màn hình đồng bộ trạng thái VIP.
/// Không dùng Riverpod để tránh refactor lớn ở giai đoạn MVP.
class UserState {
  UserState._();
  static final ValueNotifier<bool> isVipNotifier = ValueNotifier(false);

  static void updateVipStatus(bool isVip) {
    isVipNotifier.value = isVip;
  }
}
