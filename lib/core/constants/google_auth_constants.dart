/// 3 OAuth Client ID cua Google Sign-In — CHINH XAC PHAI KHOP voi 3 bien
/// da cau hinh tren Railway (backend doc qua os.environ, xem
/// app/services/auth_service.py::google_login()):
///   - GOOGLE_CLIENT_ID          (Web)
///   - GOOGLE_CLIENT_ID_ANDROID  (Android)
///   - GOOGLE_CLIENT_ID_IOS      (iOS)
///
/// Day KHONG PHAI thong tin bi mat (OAuth client_id la dinh danh CONG
/// KHAI theo thiet ke cua Google — luon lo ra trong request/URL/HTML khi
/// dang nhap, khac han GOOGLE_CLIENT_SECRET chi ton tai o backend) — an
/// toan khi nhung thang vao code Flutter, giong het cach moi ung dung
/// Google Sign-In khac lam (vd web/index.html cung se co client_id trong
/// the <meta> lo thien).
///
/// THAY 3 GIA TRI PLACEHOLDER DUOI DAY bang dung gia tri that lay tu
/// Google Cloud Console (Credentials) — PHAI khop 1-1 voi 3 bien Railway
/// da co, khong duoc dung nham chieu (vd dung Android client_id cho Web).
class GoogleAuthConstants {
  static const String webClientId =
      '593288308402-c81p5iqdphom4nfsq2va667smunooig3.apps.googleusercontent.com';

  static const String androidClientId =
      '593288308402-a8mp8b99gjov1ark15rj2dq7noklcp5n.apps.googleusercontent.com';

  static const String iosClientId =
      '593288308402-j48bpdu5meqrdursmoe13ui31jkglsro.apps.googleusercontent.com';
}
