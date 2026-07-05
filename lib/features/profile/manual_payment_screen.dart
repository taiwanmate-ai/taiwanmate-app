import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/utils/web_utils.dart';
import 'package:chinesemate/core/services/receipt_upload_service.dart';
import 'package:chinesemate/core/services/payment_service.dart';

class _DS {
  static const orange = Color(0xFFFF6B35);
  static const yellow = Color(0xFFFFB300);
  static const green = Color(0xFF00C853);
  static const textGrey = Color(0xFF8A8FA3);
}

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({super.key});
  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  final _storage = const FlutterSecureStorage();
  String _plan = 'monthly';
  String? _imageBase64;
  bool _isUploading = false;
  String? _userEmail;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final response = await dio.get(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        setState(() {
          _userEmail = response.data['email'];
          _noteController.text = 'VIP ${_userEmail ?? ''}';
        });
      }
    } catch (_) {}
  }

  int get _amount => _plan == 'monthly' ? 199000 : 1499000;
  String get _amountLabel => _plan == 'monthly' ? '199,000 VNĐ' : '1,499,000 VNĐ';

  Future<void> _pickImage() async {
    final base64 = await webPickImage();
    if (base64 == null) return;
    setState(() => _imageBase64 = base64);
  }

  Future<void> _submit() async {
    if (_imageBase64 == null) {
      _showSnack('Vui lòng chọn ảnh biên lai trước', isError: true);
      return;
    }
    setState(() => _isUploading = true);
    try {
      final receiptUrl = await ReceiptUploadService.uploadReceipt(_imageBase64!);
      if (receiptUrl == null) {
        _showSnack('Tải ảnh lên thất bại, thử lại nhé!', isError: true);
        return;
      }
      await PaymentService.submitManualPayment(
        plan: _plan,
        receiptUrl: receiptUrl,
        note: _noteController.text.trim(),
      );
      if (mounted) _showSuccessDialog();
    } on DioException catch (e) {
      final detail = e.response?.data?['detail']?.toString() ?? 'Lỗi kết nối, thử lại sau.';
      _showSnack(detail, isError: true);
    } catch (e) {
      _showSnack('Có lỗi xảy ra, thử lại sau.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _DS.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('✅ Đã gửi yêu cầu'),
        content: const Text('Chúng tôi sẽ xác nhận và kích hoạt VIP trong vòng 24 giờ. Cảm ơn bạn!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Chuyển khoản ngân hàng', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Chọn gói
          Row(children: [
            Expanded(child: _buildPlanTab('monthly', 'Tháng', '199,000đ')),
            const SizedBox(width: 12),
            Expanded(child: _buildPlanTab('yearly', 'Năm', '1,499,000đ')),
          ]),
          const SizedBox(height: 20),

          // QR
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Image.asset('assets/images/vcb_qr.jpg', fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF2A1500), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow('Số tiền', _amountLabel),
              const SizedBox(height: 8),
              _infoRow('Nội dung CK', _noteController.text.isEmpty ? 'VIP + email của bạn' : _noteController.text),
            ]),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nội dung chuyển khoản (đã điền sẵn)',
              labelStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Chọn ảnh biên lai
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: _imageBase64 != null ? 200 : 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: _imageBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.contain),
                    )
                  : const Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.upload_file_rounded, color: Colors.white54, size: 32),
                        SizedBox(height: 8),
                        Text('Chọn ảnh biên lai chuyển khoản', style: TextStyle(color: Colors.white54)),
                      ]),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isUploading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Gửi yêu cầu duyệt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Chúng tôi sẽ kích hoạt VIP trong vòng 24 giờ sau khi xác nhận',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildPlanTab(String value, String label, String price) {
    final isSelected = _plan == value;
    return GestureDetector(
      onTap: () => setState(() => _plan = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _DS.orange : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? _DS.orange : Colors.white24),
        ),
        child: Column(children: [
          Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.w800)),
          Text(price, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Row(children: [
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
    const Spacer(),
    Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
  ]);
}