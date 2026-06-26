import "package:flutter/material.dart";
import "package:dio/dio.dart";

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, dynamic>> _news = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final response = await dio.get(
        "https://taiwanmate-backend-production.up.railway.app/api/v1/news/feed",
      );
      final list = List<Map<String, dynamic>>.from(response.data["news"] ?? []);
      if (mounted) setState(() { _news = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = "Khong tai duoc tin tuc. Keo de thu lai."; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Tin tuc song con",
            style: TextStyle(color: Color(0xFF1A1D2E), fontWeight: FontWeight.w900, fontSize: 18)),
        iconTheme: const IconThemeData(color: Color(0xFF1A1D2E)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNews,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF8A8FA3)))),
                  ])
                : _news.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text("Chua co tin tuc moi", style: TextStyle(color: Color(0xFF8A8FA3)))),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _news.length,
                        itemBuilder: (context, i) => _buildCard(_news[i]),
                      ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final isHigh = n["importance"] == "high";
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHigh ? const Color(0xFFFF3D57) : const Color(0xFFE2E8F0),
          width: isHigh ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isHigh ? const Color(0xFFFFEBEE) : const Color(0xFFEEEDFE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isHigh ? "🔴 Quan trong" : "🟡 Chu y",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isHigh ? const Color(0xFFFF3D57) : const Color(0xFFFF6B35)),
            ),
          ),
          const Spacer(),
          Text(n["source"] as String? ?? "", style: const TextStyle(fontSize: 10, color: Color(0xFF8A8FA3))),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n["emoji"] as String? ?? "📰", style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(n["title_vi"] as String? ?? "",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1D2E), height: 1.3))),
        ]),
        const SizedBox(height: 8),
        Text(n["summary_vi"] as String? ?? "",
            style: const TextStyle(fontSize: 13, color: Color(0xFF4A5568), height: 1.5)),
        if ((n["action"] as String? ?? "").isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF0EC), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Text("💡", style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(n["action"] as String? ?? "",
                  style: const TextStyle(fontSize: 12, color: Color(0xFFFF6B35), fontWeight: FontWeight.w600))),
            ]),
          ),
        ],
      ]),
    );
  }
}
