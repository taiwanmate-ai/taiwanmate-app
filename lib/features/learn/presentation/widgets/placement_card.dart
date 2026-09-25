// ═══════════════════════════════════════════════════════════════
// PLACEMENT CARD — CAT đầu vào TÙY CHỌN (thay cho cổng CAT bắt buộc)
// File: lib/features/learn/presentation/widgets/placement_card.dart
//
// Bối cảnh (2026-09-26, audit funnel production): cổng CAT cứng khiến 96% user không vượt được
// bỏ trong <1 phút ở Reading (0-4 câu) và 89% user mới chưa từng thấy nội dung Học. Giờ CAT là
// 1 thẻ ở đầu tab Lộ trình: làm thì được gợi ý cấp bắt đầu, không làm/"Để sau" thì vẫn học bình
// thường. Thẻ TỰ ẨN khi bài kiểm tra chưa sẵn sàng hoặc lỗi mạng — KHÔNG BAO GIỜ chặn.
// ═══════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:chinesemate/core/constants/api_constants.dart';
import 'package:chinesemate/features/learn/presentation/widgets/cat_test_tab.dart';

enum PlacementState { loading, hidden, notTaken, inProgress, completed }

class PlacementInfo {
  final PlacementState state;
  final String? overallLevel;
  final String? recommendedLevel;
  final String? recommendedTopic;
  const PlacementInfo(this.state, {this.overallLevel, this.recommendedLevel, this.recommendedTopic});
}

/// Bấm "Để sau" thì ẩn thẻ chừng này ngày rồi mời lại (trừ khi đã làm xong).
const placementSnoozeDays = 7;

String placementTestType(String lang) => lang == 'en' ? 'english' : 'tocfl';
String placementDismissKey(String testType) => 'placement_dismissed_at_$testType';

/// Quyết định trạng thái thẻ. Mọi lỗi -> hidden (không chặn, không báo lỗi làm phiền).
Future<PlacementInfo> loadPlacementInfo({
  required Dio dio,
  required String testType,
  required Future<String?> Function(String key) readKey,
  required DateTime now,
  Options? options,
}) async {
  try {
    final base = '${ApiConstants.baseUrl}/cat-test';
    final q = {'test_type': testType};
    final status = (await dio.get('$base/status', queryParameters: q, options: options)).data as Map;

    if (status['completed'] == true) {
      final result = (await dio.get('$base/result', queryParameters: q, options: options)).data as Map;
      final rec = result['recommended'] as Map?;
      return PlacementInfo(
        PlacementState.completed,
        overallLevel: result['overall_level'] as String?,
        recommendedLevel: rec?['level'] as String?,
        recommendedTopic: rec?['topic_vi'] as String?,
      );
    }

    final availability = (await dio.get('$base/availability', queryParameters: q, options: options)).data as Map;
    if (availability['available'] != true) return const PlacementInfo(PlacementState.hidden);

    final dismissedRaw = await readKey(placementDismissKey(testType));
    final dismissedAt = dismissedRaw == null ? null : DateTime.tryParse(dismissedRaw);
    if (dismissedAt != null && now.difference(dismissedAt).inDays < placementSnoozeDays) {
      return const PlacementInfo(PlacementState.hidden);
    }

    final inProgress = (status['reading'] as Map?)?['in_progress'] == true ||
        (status['listening'] as Map?)?['in_progress'] == true;
    return PlacementInfo(inProgress ? PlacementState.inProgress : PlacementState.notTaken);
  } catch (_) {
    return const PlacementInfo(PlacementState.hidden);
  }
}

class PlacementCard extends StatefulWidget {
  final String lang; // 'zh' | 'en'
  /// Bấm "Bắt đầu học từ <cấp>" — mở Lộ trình đúng ngôn ngữ + cấp gợi ý.
  final void Function(String language, String level) onStartFromLevel;

  // Chỉ để test: thay phụ thuộc mạng/lưu trữ/điều hướng.
  final Dio? dio;
  final Future<String?> Function(String key)? readKey;
  final Future<void> Function(String key, String value)? writeKey;
  final Future<String?> Function()? readToken;
  final DateTime Function()? clock;
  final Future<void> Function(BuildContext context, String testType)? openTest;

  const PlacementCard({
    super.key,
    required this.lang,
    required this.onStartFromLevel,
    this.dio,
    this.readKey,
    this.writeKey,
    this.readToken,
    this.clock,
    this.openTest,
  });

  @override
  State<PlacementCard> createState() => _PlacementCardState();
}

class _PlacementCardState extends State<PlacementCard> {
  static const _storage = FlutterSecureStorage();
  static const _indigo = Color(0xFF5B5FEF);
  static const _textDark = Color(0xFF1A1D2E);
  static const _textGrey = Color(0xFF8A8FA3);

  late final Dio _dio = widget.dio ??
      Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
  PlacementInfo _info = const PlacementInfo(PlacementState.loading);

  String get _testType => placementTestType(widget.lang);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _read(String key) => (widget.readKey ?? (k) => _storage.read(key: k))(key);
  Future<void> _write(String key, String value) =>
      (widget.writeKey ?? (k, v) => _storage.write(key: k, value: v))(key, value);

  Future<void> _load() async {
    final token = await (widget.readToken ?? () => _storage.read(key: 'access_token'))();
    final info = await loadPlacementInfo(
      dio: _dio,
      testType: _testType,
      readKey: _read,
      now: (widget.clock ?? DateTime.now)(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    if (mounted) setState(() => _info = info);
  }

  Future<void> _dismiss() async {
    await _write(placementDismissKey(_testType), (widget.clock ?? DateTime.now)().toIso8601String());
    if (mounted) setState(() => _info = const PlacementInfo(PlacementState.hidden));
  }

  Future<void> _openTest() async {
    if (widget.openTest != null) {
      await widget.openTest!(context, _testType);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: const Color(0xFFF0F4FF),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: _textDark),
              title: const Text('Kiểm tra trình độ',
                  style: TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            body: SafeArea(
              child: CatTestTab(
                isRequiredPlacement: true, // miễn phí, đúng test_type, không cần chọn loại đề
                requiredTestType: _testType,
                autoAdvance: false,
                completeLabel: 'Xong',
                onCompleted: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    }
    if (mounted) _load(); // vừa làm/bỏ dở xong: làm mới trạng thái thẻ
  }

  @override
  Widget build(BuildContext context) {
    switch (_info.state) {
      case PlacementState.loading:
      case PlacementState.hidden:
        return const SizedBox.shrink();
      case PlacementState.notTaken:
        return _card(
          emoji: '🧭',
          title: 'Kiểm tra trình độ (khoảng 3 phút)',
          subtitle: 'Không bắt buộc — làm để biết nên bắt đầu học từ cấp nào. Bạn có thể học ngay bên dưới.',
          primaryLabel: 'Làm bài kiểm tra',
          onPrimary: _openTest,
          onLater: _dismiss,
        );
      case PlacementState.inProgress:
        return _card(
          emoji: '🧭',
          title: 'Bạn đang làm dở bài kiểm tra trình độ',
          subtitle: 'Tiếp tục từ chỗ đã dừng, hoặc để sau và học ngay bên dưới.',
          primaryLabel: 'Tiếp tục',
          onPrimary: _openTest,
          onLater: _dismiss,
        );
      case PlacementState.completed:
        final rec = _info.recommendedLevel;
        return _card(
          emoji: '🎯',
          title: 'Trình độ của bạn: ${_info.overallLevel ?? '-'}',
          subtitle: rec == null
              ? 'Chọn cấp phù hợp trong Lộ trình bên dưới.'
              : 'Gợi ý bắt đầu: $rec${_info.recommendedTopic == null ? '' : ' · ${_info.recommendedTopic}'}',
          primaryLabel: rec == null ? null : 'Bắt đầu học từ $rec',
          onPrimary: rec == null ? null : () => widget.onStartFromLevel(widget.lang, rec),
          onLater: null,
        );
    }
  }

  Widget _card({
    required String emoji,
    required String title,
    required String subtitle,
    required String? primaryLabel,
    required VoidCallback? onPrimary,
    required VoidCallback? onLater,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _indigo.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: _textGrey, height: 1.4)),
            ]),
          ),
        ]),
        if (primaryLabel != null || onLater != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (primaryLabel != null)
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            if (onLater != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onLater,
                child: const Text('Để sau', style: TextStyle(color: _textGrey, fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ],
      ]),
    );
  }
}
