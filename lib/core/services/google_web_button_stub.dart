import 'package:flutter/material.dart';

/// Stub cho nen tang khong phai Web — KHONG duoc goi thuc su (UI da gate
/// bang kIsWeb, xem login_screen.dart), chi ton tai de conditional import
/// bien dich duoc tren Android/iOS.
Widget renderGoogleWebButton() {
  throw StateError('renderGoogleWebButton() chỉ được gọi trên Web');
}
