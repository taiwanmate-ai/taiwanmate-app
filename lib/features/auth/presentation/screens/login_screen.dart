import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/google_web_button.dart';
import '../../../../shared/theme/app_colors.dart';
import 'package:chinesemate/core/cache/app_cache.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleWebAuthSub;
  // Bug da sua: renderGoogleWebButton() TRUOC DAY duoc goi TRUC TIEP, MOI
  // LAN build() (vd moi 4s do _copyTimer trong _buildBottomSection() goi
  // setState()). Xac nhan qua chinh source that google_sign_in_web.dart
  // (renderButton() dong 266-284): moi lan goi tao 1 `GSIButtonConfiguration()`
  // MOI (default constructor, khong truyen vao), va Key cua FutureBuilder
  // ben trong la `Key(config.hashCode.toString())` — hashCode nay THAY DOI
  // moi lan goi (identity hashCode, khong phai value-based), nghia la MOI
  // LAN _LoginScreenState.build() chay lai, Flutter thay Key khac -> PHA
  // HUY VA TAO LAI TU DAU toan bo platform view (iframe nut GIS that su),
  // dang ky lai MutationObserver/ResizeObserver tu dau (xem
  // flexible_size_html_element_view.dart) — lap lien tuc, KHONG BAO GIO
  // on dinh vi _copyTimer khong bao gio dung, gay vong lap treo man hinh
  // vinh vien tren Web. SUA: goi renderGoogleWebButton() DUY NHAT 1 LAN
  // trong initState(), cache lai Widget instance, dung LAI CHINH instance
  // do trong moi build() — giu nguyen Key/danh tinh widget on dinh qua
  // moi lan rebuild.
  Widget? _googleWebButton;

  // Micro-copy rotation
  int _copyIndex = 0;
  Timer? _copyTimer;
  late AnimationController _copyFadeCtrl;
  late Animation<double> _copyFade;

  // Entrance animation
  late AnimationController _enterCtrl;
  late Animation<double> _enterFade;
  late Animation<Offset> _enterSlide;

  final List<Map<String, String>> _microcopy = [
    {'main': 'Ký hợp đồng mà\nkhông hiểu gì?', 'sub': 'Mình dịch cho. Ngay bây giờ.'},
    {'main': 'Đi làm ở Đài Loan\nngại hỏi vì không biết tiếng?', 'sub': 'Mình là phiên dịch 24/7 của bạn.'},
    {'main': 'Muốn nói chuyện\nvới người Đài mà ngại?', 'sub': 'Luyện với 小美 — an toàn, không phán xét.'},
  ];

  @override
  void initState() {
    super.initState();

    _copyFadeCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _copyFade = CurvedAnimation(parent: _copyFadeCtrl, curve: Curves.easeInOut);
    _copyFadeCtrl.forward();

    _enterCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _enterFade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _enterSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut));
    _enterCtrl.forward();

    _copyTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _copyFadeCtrl.reverse();
      if (mounted) setState(() => _copyIndex = (_copyIndex + 1) % _microcopy.length);
      _copyFadeCtrl.forward();
    });

    // Web KHONG dung authenticate() truc tiep duoc (xem docstring
    // GoogleAuthService) — phai render nut GIS that (renderGoogleWebButton
    // trong build()) va lang nghe ket qua qua stream nay. Android/iOS
    // KHONG can buoc nay (van dung _loginWithGoogle() goi signIn() nhu cu).
    if (kIsWeb) {
      _googleWebButton = renderGoogleWebButton();
      _setupGoogleWebSignIn();
    }
  }

  Future<void> _setupGoogleWebSignIn() async {
    try {
      await GoogleAuthService.ensureInitialized();
    } catch (e) {
      debugPrint('Google web sign-in init error: $e');
      return;
    }
    _googleWebAuthSub = GoogleAuthService.webAuthenticationEvents.listen(
      _handleGoogleWebAuthEvent,
      onError: (Object e) {
        debugPrint('Google web sign-in stream error: $e');
        if (mounted) setState(() => _error = 'Đăng nhập Google thất bại, vui lòng thử lại');
      },
    );
  }

  Future<void> _handleGoogleWebAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      await GoogleAuthService.completeSignIn(event.user);
      AppCache.instance.preloadAll();
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      debugPrint('Google web sign-in DioException: $e');
      setState(() => _error = e.response?.data['detail'] ?? 'Đăng nhập Google thất bại');
    } catch (e) {
      debugPrint('Google web sign-in error: $e');
      setState(() => _error = 'Đăng nhập Google thất bại, vui lòng thử lại');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _copyFadeCtrl.dispose();
    _enterCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _googleWebAuthSub?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await DioClient.instance.post(
        ApiConstants.login,
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
      );
      await SecureStorage.saveToken(response.data['access_token']);

       AppCache.instance.preloadAll();

      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data['detail'] ?? 'Email hoặc mật khẩu không đúng');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final accessToken = await GoogleAuthService.signIn();
      if (accessToken == null) {
        // Nguoi dung tu huy — khong phai loi, khong hien thong bao.
        return;
      }
      AppCache.instance.preloadAll();
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      debugPrint('Google sign-in DioException: $e');
      setState(() => _error = e.response?.data['detail'] ?? 'Đăng nhập Google thất bại');
    } catch (e) {
      // Bug da sua: truoc day catch chung nay KHONG in "e" ra dau ca —
      // 1 loi StateError tu GoogleSignIn.initialize() (vd goi initialize()
      // 2 lan do bam nut nhanh truoc khi lan dau kip tai xong JS SDK) bi
      // "nuot" hoan toan, chi hien 1 chuoi loi co dinh, khong the debug
      // duoc tu Console. LUON in "e" that ra Console tu nay ve sau.
      debugPrint('Google sign-in error: $e');
      setState(() => _error = 'Đăng nhập Google thất bại, vui lòng thử lại');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
       physics: const BouncingScrollPhysics(),
        child: ConstrainedBox(
         constraints: BoxConstraints(minHeight: size.height),
          child: Column(
            children: [
              // ── TOP SECTION (40%) ──────────────────────────
              _buildTopSection(size),
              // ── BOTTOM SECTION (60%) ───────────────────────
              _buildBottomSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ── TOP SECTION ──────────────────────────
Widget _buildTopSection(Size size) {
  return Container(
    height: size.height * 0.42,
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Color(0xFF1A1A4E),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(36),
        bottomRight: Radius.circular(36),
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Social proof
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('✨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('TaiwanMate AI',
                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('👥', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('12,400+ người dùng',
                        style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),

            // Illustration
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/Sign_up-amico.webp',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Micro-copy
            FadeTransition(
              opacity: _copyFade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _microcopy[_copyIndex]['main']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _microcopy[_copyIndex]['sub']!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Dot indicators
            Row(children: List.generate(3, (i) => Container(
              margin: const EdgeInsets.only(right: 6),
              width: i == _copyIndex ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _copyIndex
                    ? const Color(0xFFFFD166)
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ))),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBottomSection() {
    return SlideTransition(
      position: _enterSlide,
      child: FadeTransition(
        opacity: _enterFade,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text('Đăng nhập',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1D2E), letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text('Chào mừng trở lại! 👋',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),

              const SizedBox(height: 24),

              // Error
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE53935), fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'email@gmail.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 16),

              // Password field
              _buildLabel('Mật khẩu'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade400, size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
                  child: const Text('Quên mật khẩu?',
                      style: TextStyle(color: Color(0xFF5B5FEF), fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 8),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: GestureDetector(
                  onTap: _isLoading ? null : _login,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B5FEF), Color(0xFF3B3FA8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                        color: const Color(0xFF5B5FEF).withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6),
                      )],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Divider "hoặc"
              Row(children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('hoặc', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ]),

              const SizedBox(height: 16),

              // Đăng nhập với Google — TÍNH NĂNG THÊM VÀO, KHÔNG thay thế
              // form email/mật khẩu ở trên.
              //
              // Web PHẢI dùng nút GIS thật (renderGoogleWebButton) — xác
              // nhận qua chính source google_sign_in_web: authenticate()
              // ném UnimplementedError trên Web ("Instead, use renderButton
              // to create a sign-in widget."), supportsAuthenticate() luôn
              // false trên Web. Android/iOS vẫn dùng nút tự vẽ + authenticate()
              // như cũ, KHÔNG đổi.
              if (kIsWeb)
                Center(child: _googleWebButton!)
              else
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.g_mobiledata_rounded, size: 26, color: Color(0xFF5B5FEF)),
                        const SizedBox(width: 6),
                        const Text('Đăng nhập với Google',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 14),

              // Try without register
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Dùng thử ngay — không cần đăng ký',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 24),

              // Register
              Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Chưa có tài khoản? ', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text('Đăng ký ngay',
                        style: TextStyle(color: Color(0xFF5B5FEF), fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E)),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1D2E), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF5B5FEF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
