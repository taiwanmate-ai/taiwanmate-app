import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:dio/dio.dart";
import "../../../../core/constants/api_constants.dart";
import "../../../../shared/theme/app_colors.dart";

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      setState(() => _error = "Vui long nhap email hop le");
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      await dio.post("/auth/forgot-password", data: {"email": email});
      setState(() => _sent = true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        setState(() => _error = "Email khong ton tai trong he thong");
      } else {
        setState(() => _sent = true);
      }
    } catch (e) {
      setState(() => _error = "Loi ket noi. Vui long thu lai.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.lightText),
          onPressed: () => context.go("/login"),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 20),
              const Text("Quen mat khau?",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.lightText)),
              const SizedBox(height: 8),
              const Text("Nhap email cua ban, chung toi se gui huong dan dat lai mat khau.",
                  style: TextStyle(fontSize: 14, color: AppColors.lightTextMid, height: 1.5)),
              const SizedBox(height: 28),
              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success),
                    SizedBox(width: 12),
                    Expanded(child: Text("Da gui! Kiem tra hop thu email cua ban.",
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.go("/login"),
                    child: const Text("Quay lai dang nhap", style: TextStyle(color: AppColors.primary)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: AppColors.lightSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.lightBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.lightBorder),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Gui huong dan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
