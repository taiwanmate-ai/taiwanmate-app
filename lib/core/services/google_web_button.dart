/// Theo dung mau chinh thuc cua package google_sign_in (7.2.0), xem
/// example/lib/src/web_wrapper.dart — google_sign_in_web/web_only.dart
/// (chua renderButton()) dung dart:ui_web/package:web ben trong, KHONG
/// bien dich duoc cho Android/iOS neu import truc tiep trong file dung
/// chung — bat buoc phai qua conditional export nhu the nay.
library;

export 'google_web_button_stub.dart'
    if (dart.library.js_util) 'google_web_button_web.dart';
