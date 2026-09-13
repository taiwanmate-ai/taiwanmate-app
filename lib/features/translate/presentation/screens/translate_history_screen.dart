/// Idea #5 tu audit translate_screen.dart (2026-09-13): "Lich su dich vinh
/// vien, co the tim kiem" — thay the danh sach _history trong bo nho (toi
/// da 5 muc, mat het khi tat app) bang man hinh doc GET /translate/history
/// (backend da ghi san moi luot dich tu truoc, chi thieu API doc). Tap vao
/// 1 muc se dan van ban goc vao o nhap cua man hinh Dich (giong VoiceHistory
/// nhung KHONG the "tiep tuc phien" — moi luot dich la doc lap).
library;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:chinesemate/core/constants/api_constants.dart';

const _typeLabels = {
  '': 'Tất cả',
  'fast': 'Nhanh',
  'image': 'Ảnh',
  'voice': 'Giọng nói',
  'text': 'Học sâu',
};

class TranslateHistoryScreen extends StatefulWidget {
  const TranslateHistoryScreen({super.key});
  @override
  State<TranslateHistoryScreen> createState() => _TranslateHistoryScreenState();
}

class _TranslateHistoryScreenState extends State<TranslateHistoryScreen> {
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  bool _isLoading = true;
  String _typeFilter = '';
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool loadMore = false}) async {
    setState(() => _isLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      final res = await dio.get(
        '${ApiConstants.baseUrl}/translate/history',
        queryParameters: {
          'q': _searchController.text.trim(),
          if (_typeFilter.isNotEmpty) 'translation_type': _typeFilter,
          'limit': _pageSize,
          'offset': loadMore ? _items.length : 0,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final newItems = List<Map<String, dynamic>>.from(res.data['items'] ?? []);
      setState(() {
        _total = res.data['total'] ?? 0;
        _items = loadMore ? [..._items, ...newItems] : newItems;
      });
    } catch (e) {
      if (!loadMore) setState(() => _items = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'Hôm nay, ${DateFormat.Hm().format(dt)}';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isYesterday) return 'Hôm qua, ${DateFormat.Hm().format(dt)}';
    return DateFormat('dd/MM/yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử dịch')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Tìm trong lịch sử...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _load();
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _typeLabels.entries.map((e) {
              final selected = _typeFilter == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _typeFilter = e.key);
                    _load();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading && _items.isEmpty
              ? Center(child: CircularProgressIndicator(color: scheme.primary))
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isNotEmpty
                            ? 'Không tìm thấy kết quả'
                            : 'Chưa có lịch sử dịch nào',
                        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (!_isLoading &&
                              _items.length < _total &&
                              n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                            _load(loadMore: true);
                          }
                          return false;
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                title: Text(
                                  item['original_text'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['translated_text'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7)),
                                    ),
                                    Text(
                                      _formatTime(item['created_at']),
                                      style: TextStyle(
                                          fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4)),
                                    ),
                                  ],
                                ),
                                onTap: () => Navigator.pop(context, item['original_text']),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}
