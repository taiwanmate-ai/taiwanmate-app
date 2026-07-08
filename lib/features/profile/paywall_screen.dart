import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:chinesemate/core/services/payment_service.dart';
import 'manual_payment_screen.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});
  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
  }

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  bool _isYearly = false;

 Future<void> _subscribe() async {
    if (kIsWeb) {
      // TẠM: Lemon Squeezy còn ở Test mode, chưa duyệt Live.
      // Chuyển sang QR thủ công đã hoạt động ổn định, tránh user thanh toán vào môi trường test.
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualPaymentScreen()));
      return;
    } else {
      setState(() => _loading = true);
      await PaymentService.purchaseAndroid(
        plan: _isYearly ? 'yearly' : 'monthly',
        onSuccess: () {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🎉 Nâng cấp VIP thành công!'), backgroundColor: Colors.green),
            );
          }
        },
        onError: (msg) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _restore() async {
    if (kIsWeb) return; // Restore chỉ áp dụng cho Google Play Billing
    setState(() => _loading = true);
    await PaymentService.restorePurchases(
      onSuccess: () {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 Đã khôi phục VIP thành công!'), backgroundColor: Colors.green),
          );
        }
      },
      onError: (msg) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      },
    );
    if (mounted) setState(() => _loading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          child: Column(
            children: [
              // Header gradient card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium,
                          color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text('ChineseMate Pro',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 6),
                    // Toggle tháng/năm
Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.15),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: () => setState(() => _isYearly = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: !_isYearly ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Tháng',
              style: TextStyle(
                  color: !_isYearly ? const Color(0xFF6C63FF) : Colors.white,
                  fontWeight: FontWeight.bold)),
        ),
      ),
      GestureDetector(
        onTap: () => setState(() => _isYearly = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: _isYearly ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Năm',
              style: TextStyle(
                  color: _isYearly ? const Color(0xFF6C63FF) : Colors.white,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    ],
  ),
),
Text(
  _isYearly ? 'NT\$1,499 / năm' : 'NT\$199 / tháng',
  style: const TextStyle(
      fontSize: 16,
      color: Colors.white,
      fontWeight: FontWeight.w600),
),
if (_isYearly)
  const Text('Tiết kiệm 37%',
      style: TextStyle(color: Colors.amberAccent, fontSize: 12)
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Features
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Tính năng Pro',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
              ),
              const SizedBox(height: 16),
              _feature(Icons.chat_bubble_outline, 'Chat AI không giới hạn',
                  'Trò chuyện với Yuki & Kai bao nhiêu cũng được'),
              _feature(Icons.record_voice_over_outlined, 'TTS giọng đọc cao cấp',
                  'Nghe phát âm chuẩn từ giọng AI tự nhiên'),
              _feature(Icons.style_outlined, 'Flashcard nâng cao',
                  'Học từ vựng hiệu quả với spaced repetition'),
              _feature(Icons.support_agent_outlined, 'Hỗ trợ ưu tiên',
                  'Được hỗ trợ nhanh hơn qua email'),

              const SizedBox(height: 32),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _subscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Đăng ký ngay',
                          style: TextStyle(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 12),
              const Text('Huỷ bất cứ lúc nào • Thanh toán an toàn',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : _restore,
                  child: const Text('Đã mua rồi? Khôi phục giao dịch',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 18),
        ],
      ),
    );
  }
}
