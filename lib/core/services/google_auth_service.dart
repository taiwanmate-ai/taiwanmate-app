import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/api_constants.dart';
import '../constants/google_auth_constants.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';

/// Dang nhap qua Google — TINH NANG THEM VAO, KHONG thay the form email/
/// mat khau hien co (xem login_screen.dart, van gan _login() nhu cu).
///
/// Ca 3 nen tang (Web/Android/iOS) dung CHUNG 1 API instance() cua
/// google_sign_in v7 (initialize()/authenticate() — API MOI hoan toan
/// khac ban truoc 7.0, xem migration guide chinh thuc tren pub.dev), chi
/// khac tham so truyen vao initialize() theo dung tai lieu real cua
/// tung platform package con (google_sign_in_android/_ios/_web):
///   - Web: initialize(clientId: WEB_ID) — google_sign_in_web doc that
///     WEB_ID lam client_id cho Google Identity Services truc tiep.
///   - Android: initialize(serverClientId: WEB_ID) — xac nhan qua chinh
///     source that cua google_sign_in_android (google_sign_in_android.dart):
///     "The clientId parameter is not supported on Android" — Android
///     client_id (package+SHA-1) duoc Google TU DONG doi chieu qua Cloud
///     Console, KHONG truyen trong code; serverClientId (Web ID) moi la
///     gia tri quyet dinh "aud" cua ID token tra ve — dung theo dung
///     huong dan chinh thuc cua Google (developers.google.com/identity/
///     sign-in/android/backend-auth: "pass it your server's web client ID").
///   - iOS: initialize(clientId: IOS_ID, serverClientId: WEB_ID) — iOS
///     CAN clientId rieng (khop GIDClientID trong Info.plist, bat buoc
///     de native flow hoat dong voi dung bundle id), serverClientId (Web
///     ID) de dam bao "aud" cua ID token van la 1 trong 3 gia tri backend
///     dang chap nhan.
///
/// KET QUA: token Android/iOS/Web deu co the co "aud" la CHINH WEB_ID
/// (theo dung co che serverClientId cua Google) — nhung backend van
/// chap nhan CA 3 client_id trong danh sach audience (xem auth_service.py)
/// de an toan/dung chuan neu sau nay co truong hop token mang aud khac.
///
/// QUAN TRONG — Web KHONG dung authenticate(): xac nhan qua chinh source
/// that cua google_sign_in_web (GoogleSignInPlugin.authenticate() nem
/// UnimplementedError: "authenticate is not supported on the web.
/// Instead, use renderButton to create a sign-in widget.") va
/// supportsAuthenticate() LUON tra ve false tren Web — day la THIET KE
/// CO CHU DICH cua package (Google Identity Services yeu cau 1 nut GIS
/// that su render tren trang, khong cho phep trigger popup tuy y qua
/// code nhu native app). Vi vay:
///   - Android/iOS: dung signIn() (authenticate() truc tiep) — KHONG DOI.
///   - Web: dung renderGoogleWebButton() (google_web_button.dart) de
///     render nut That cua Google, ket qua tra ve qua stream
///     webAuthenticationEvents (lang nghe trong login_screen.dart),
///     roi goi completeSignIn() de hoan tat — xem mau chinh thuc trong
///     example/lib/main.dart cua chinh package google_sign_in 7.2.0.
class GoogleAuthService {
  /// Bug da sua: TRUOC DAY dung 1 `bool _initialized` chi duoc set = true
  /// SAU KHI await initialize() xong — nghia la 2 lan goi _ensureInitialized()
  /// GAN NHU DONG THOI (vd bam nut 2 lan lien tiep truoc khi lan dau kip
  /// tai xong Google Identity Services JS SDK tren web, thuong mat vai
  /// giay) deu thay `_initialized == false` va CA HAI cung goi
  /// GoogleSignIn.instance.initialize() — plugin Web (google_sign_in_web,
  /// doc truc tiep source that: lib/google_sign_in_web.dart::init())
  /// NEM StateError ro rang cho truong hop nay:
  ///   "init() has already been called. Calling init() more than once
  ///   results in undefined behavior."
  /// StateError KHONG PHAI GoogleSignInException nen bi lot qua catch
  /// rieng trong signIn() (o duoi), roi bi "nuot" boi catch (e) chung
  /// chung o login_screen.dart (chi set 1 chuoi loi co dinh, khong in ra
  /// console) — dung la nguyen nhan goc cua bug "that bai ngay, khong
  /// hien popup chon tai khoan".
  ///
  /// Sua bang mau "single-flight future" — `??=` chi tao Future MOI khi
  /// chua co Future nao dang chay; moi lan goi tiep theo (du dong thoi
  /// hay tuan tu) deu await LAI DUNG 1 Future duy nhat, dam bao
  /// GoogleSignIn.instance.initialize() CHI THUC SU duoc goi 1 LAN DUY
  /// NHAT trong suot vong doi ung dung, bat ke goi _ensureInitialized()
  /// bao nhieu lan/nhanh co nao.
  static Future<void>? _initializeFuture;

  /// PUBLIC — man hinh Web can tu goi truoc khi render nut Google (xem
  /// login_screen.dart), vi renderButton() tren Web KHONG di qua signIn()
  /// (khac han Android/iOS dung authenticate()).
  static Future<void> ensureInitialized() {
    // Neu lan init truoc THAT BAI (vd tam thoi mat mang luc tai JS SDK),
    // xoa cache de LAN GOI SAU duoc thu lai — khong de 1 lan loi permanently
    // "khoa" viec dang nhap Google cho ca phien lam viec.
    return _initializeFuture ??= _doInitialize().catchError((Object e) {
      _initializeFuture = null;
      throw e;
    });
  }

  static Future<void> _doInitialize() async {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: GoogleAuthConstants.webClientId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await GoogleSignIn.instance.initialize(
        clientId: GoogleAuthConstants.iosClientId,
        serverClientId: GoogleAuthConstants.webClientId,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await GoogleSignIn.instance.initialize(
        serverClientId: GoogleAuthConstants.webClientId,
      );
    } else {
      // macOS/Windows/Linux — ngoai pham vi Sprint nay (chi Web+Android+iOS).
      throw Exception('Đăng nhập Google chưa hỗ trợ trên nền tảng này');
    }
  }

  /// Stream su kien dang nhap/dang xuat Google — CHI dung cho Web. Xac
  /// nhan qua chinh source that cua google_sign_in_web
  /// (google_sign_in_web.dart::authenticate()):
  ///   "authenticate is not supported on the web. Instead, use
  ///   renderButton to create a sign-in widget."
  /// Web KHONG the goi authenticate() truc tiep (GoogleSignIn.instance.
  /// supportsAuthenticate() luon tra ve false tren Web — day la THIET KE
  /// CO CHU DICH cua package, khong phai bug) — thay vao do phai render
  /// nut GIS that (xem google_web_button_web.dart) va lang nghe ket qua
  /// qua stream nay, dung DUNG mau chinh thuc trong example/lib/main.dart
  /// cua package google_sign_in 7.2.0.
  static Stream<GoogleSignInAuthenticationEvent> get webAuthenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  /// Hoan tat dang nhap SAU KHI da co GoogleSignInAccount (tu authenticate()
  /// tren Android/iOS, HOAC tu 1 su kien trong webAuthenticationEvents
  /// tren Web) — gui idToken cho backend /auth/google-login, luu JWT tra
  /// ve. Dung CHUNG cho ca 2 luong de khong lap logic.
  static Future<String> completeSignIn(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Không lấy được ID token từ Google');
    }

    final response = await DioClient.instance.post(
      ApiConstants.googleLogin,
      data: {'id_token': idToken},
    );
    final accessToken = response.data['access_token'] as String;
    await SecureStorage.saveToken(accessToken);
    return accessToken;
  }

  /// Dang nhap qua Google tren Android/iOS (authenticate() truc tiep).
  /// KHONG dung duoc tren Web (xem webAuthenticationEvents o tren) — man
  /// hinh Web phai dung nut Google that (renderGoogleWebButton()) +
  /// lang nghe webAuthenticationEvents, KHONG duoc goi ham nay.
  ///
  /// Tra ve access_token (JWT cua CHINH backend TaiwanMate, giong het
  /// /auth/login) neu thanh cong. Tra ve null neu nguoi dung tu huy
  /// (khong phai loi that su — man hinh KHONG nen hien thong bao loi
  /// trong truong hop nay). Nem Exception voi message ro rang cho moi
  /// truong hop loi that su khac.
  static Future<String?> signIn() async {
    await ensureInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw Exception(
        'Nền tảng này không hỗ trợ đăng nhập Google trực tiếp — '
        'hãy dùng nút Google riêng cho Web',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw Exception('Đăng nhập Google thất bại: ${e.description ?? e.code}');
    }

    return completeSignIn(account);
  }

  /// Don session Google KHI DANG XUAT khoi TaiwanMate — goi truoc khi xoa
  /// JWT token cua TaiwanMate. Bug da sua: TRUOC DAY logout chi xoa JWT
  /// cua TaiwanMate, KHONG goi gi toi GoogleSignIn ca. Xac nhan qua chinh
  /// source that (gis_client.dart::signOut()): id.initialize() duoc cau
  /// hinh voi `auto_select: true` ("Attempt to sign-in silently") — GIS SDK
  /// cua Google se TU DONG dang nhap lai (silent/one-tap) khi nut Google
  /// duoc render lai, TRU KHI da goi `id.disableAutoSelect()` — CHINH XAC
  /// dieu ma `GoogleSignIn.instance.signOut()` lam (qua
  /// `GoogleSignInPlatform.instance.signOut()` -> `_gisSdkClient.signOut()`
  /// -> `id.disableAutoSelect()`). KHONG goi ham nay khi dang xuat se khien
  /// GIS tu dong dang nhap lai NGAY sau khi LoginScreen moi (sau logout)
  /// mount va render lai nut Google — gay ra dang nhap-lai-tu-dong ngoai
  /// y muon, dua den dieu huong chong cheo trong luc LoginScreen con dang
  /// mount/dispose do dang, day chinh la nguyen nhan cua bug treo man hinh
  /// xam + vong lap requestAnimationFrame sau khi dang xuat.
  ///
  /// AN TOAN cho MOI truong hop dang xuat, ke ca user dang nhap bang email/
  /// mat khau (chua bao gio dung Google) — `GoogleSignIn.instance.signOut()`
  /// tren Web se `await ensureInitialized()` TRUOC (dam bao khong bao gio
  /// hang vinh vien cho mot Completer chua duoc hoan tat trong truong hop
  /// user duoc tu dong dang nhap qua token cu, KHONG bao gio ghe qua
  /// LoginScreen — nen GoogleAuthService.ensureInitialized() co the CHUA
  /// TUNG duoc goi cho phien nay). Loi (neu co, vd mat mang) chi duoc log,
  /// KHONG lam gian doan luong dang xuat that su cua TaiwanMate.
  static Future<void> signOut() async {
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await ensureInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google sign-out error (bo qua, khong chan dang xuat): $e');
    }
  }
}
