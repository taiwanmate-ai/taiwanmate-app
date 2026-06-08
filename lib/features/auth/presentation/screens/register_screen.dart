import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/theme/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _register() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _error = 'Vui lòng điền đầy đủ thông tin');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await DioClient.instance.post(
        ApiConstants.register,
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'full_name': _nameController.text.trim(),
        },
      );
      await SecureStorage.saveToken(response.data['access_token']);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data['detail'] ?? 'Đăng ký thất bại';
      });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.navyMid, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const Text('🇹🇼', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Tạo tài khoản',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                    color: Colors.white)),
                const SizedBox(height: 8),
                Text('Bắt đầu hành trình tại Đài Loan',
                  style: TextStyle(fontSize: 14,
                    color: Colors.white.withOpacity(0.7))),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_error!,
                            style: const TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildLabel('HỌ VÀ TÊN'),
                      const SizedBox(height: 8),
                      _buildTextField(_nameController, 'Nguyễn Văn A'),
                      const SizedBox(height: 16),
                      _buildLabel('EMAIL'),
                      const SizedBox(height: 8),
                      _buildTextField(_emailController, 'email@gmail.com',
                        keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildLabel('MẬT KHẨU'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Đăng ký',
                                style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Đã có tài khoản? ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7))),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text('Đăng nhập',
                              style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: Colors.white70, letterSpacing: 1));
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(hint, suffixIcon: suffixIcon),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
    );
  }
}