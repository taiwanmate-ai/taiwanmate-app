import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web_signin;

/// Nut dang nhap Google THAT SU do chinh Google Identity Services JS SDK
/// render (khong phai widget Flutter tu ve) — xac nhan qua source that
/// cua google_sign_in_web: authenticate() nem UnimplementedError tren Web
/// voi thong bao ro rang "Instead, use renderButton to create a sign-in
/// widget." Day la ly do CHINH THUC (khong phai lua chon UI tuy y) khien
/// nhanh Web phai dung co che khac han Android/iOS.
Widget renderGoogleWebButton() => web_signin.renderButton();
