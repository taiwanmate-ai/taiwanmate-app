import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:js' as js;

// ─── Design System (nhất quán với home/login) ─────────────────
class _DS {
  static const bg = Color(0xFFF5F6FA);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const orange = Color(0xFFFF6B35);
  static const orangeLight = Color(0xFFFFF0EC);
  static const blue = Color(0xFF2979FF);
  static const blueLight = Color(0xFFE8F0FF);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _inputController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  // Text tab
  String _result = '';
  String _resultSimplified = '';
  String _resultEnglish = '';
  String _resultVietnamese = '';
  String _pinyin = '';
  String _explanation = '';
  bool _isLoading = false;
  String _sourceLang = 'auto';
  String _targetLang = 'zh-TW';
  int _selectedScript = 0;

  // History
  final List<Map<String, String>> _history = [];

  // Image tab
  String? _imageBase64;
  String _imageResult = '';
  String _imageResultSimplified = '';
  String _imageResultEnglish = '';
  String _imageResultVietnamese = '';
  String _imagePinyin = '';
  String _imageExplanation = '';
  String _extractedText = '';
  bool _imageLoading = false;
  String _imageTargetLang = 'zh-TW';

  // Voice tab
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _audioChunks = [];
  bool _isRecording = false;
  bool _voiceLoading = false;
  String _transcript = '';
  String _voiceResult = '';
  String _voiceResultSimplified = '';
  String _voiceResultEnglish = '';
  String _voiceResultVietnamese = '';
  String _voicePinyin = '';
  String _voiceExplanation = '';
  String _voiceTargetLang = 'zh-TW';

  // Quick phrases
  static const _quickPhrases = [
    {'vi': 'Tôi không hiểu', 'icon': '🤔'},
    {'vi': 'Bao nhiêu tiền?', 'icon': '💰'},
    {'vi': 'Nhà vệ sinh ở đâu?', 'icon': '🚻'},
    {'vi': 'Gọi xe giúp tôi', 'icon': '🚕'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inputController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getDisplayTabs({
    required String targetLang,
    required String traditional,
    required String simplified,
    required String english,
    required String vietnamese,
  }) {
    switch (targetLang) {
      case 'zh-TW':
        return [
          if (traditional.isNotEmpty) {'label': '繁 Phồn thể', 'value': traditional, 'lang': 'zh-TW'},
          if (simplified.isNotEmpty) {'label': '简 Giản thể', 'value': simplified, 'lang': 'zh-CN'},
        ];
      case 'en':
        return [if (english.isNotEmpty) {'label': '🇺🇸 English', 'value': english, 'lang': 'en'}];
      case 'vi':
        return [if (vietnamese.isNotEmpty) {'label': '🇻🇳 Tiếng Việt', 'value': vietnamese, 'lang': 'vi'}];
      default:
        return [if (traditional.isNotEmpty) {'label': '繁 Phồn thể', 'value': traditional, 'lang': 'zh-TW'}];
    }
  }

  Future<void> _translate({String? overrideText}) async {
    final text = overrideText ?? _inputController.text.trim();
    if (text.isEmpty) return;
    if (overrideText != null) _inputController.text = overrideText;
    setState(() {
      _isLoading = true;
      _result = ''; _resultSimplified = ''; _resultEnglish = '';
      _resultVietnamese = ''; _pinyin = ''; _explanation = '';
      _selectedScript = 0;
    });
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ));
      Response? response;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          response = await dio.post(
            'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/text',
            data: {'text': text, 'target_lang': _targetLang},
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
          break;
        } catch (e) {
          if (attempt == 1) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      setState(() {
        _result = response!.data['translated'] ?? '';
        _resultSimplified = response!.data['translated_simplified'] ?? '';
        _resultEnglish = response!.data['translated_english'] ?? '';
        _resultVietnamese = response!.data['translated_vietnamese'] ?? response.data['explanation'] ?? '';
        _pinyin = response!.data['pinyin'] ?? '';
        _explanation = response!.data['explanation'] ?? '';
      });
      // Lưu history
      if (_result.isNotEmpty) {
        setState(() {
          _history.insert(0, {'input': text, 'result': _result, 'pinyin': _pinyin});
          if (_history.length > 5) _history.removeLast();
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          final limit = detail['limit'] ?? 20;
          setState(() => _result = '');
          if (mounted) _showQuotaDialog('dịch văn bản', limit);
          return;
        }
      }
      setState(() => _result = 'Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      setState(() => _result = 'Lỗi kết nối. Vui lòng thử lại.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _swapLanguages() {
    setState(() {
      if (_sourceLang != 'auto') {
        final temp = _sourceLang;
        _sourceLang = _targetLang;
        _targetLang = temp;
      }
      _inputController.text = _result;
      _result = ''; _resultSimplified = ''; _resultEnglish = '';
      _resultVietnamese = ''; _pinyin = ''; _explanation = '';
    });
  }

  void _pickImage() {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    input.onChange.listen((e) {
      final file = input.files!.first;
      final urlReader = html.FileReader();
      urlReader.readAsDataUrl(file);
      urlReader.onLoadEnd.listen((_) {
        final img = html.ImageElement();
        img.src = urlReader.result as String;
        img.onLoad.listen((_) {
          double ratio = 1.0;
          if (img.width! > 1600 || img.height! > 1200) {
            ratio = (img.width! > img.height!) ? 1600 / img.width! : 1200 / img.height!;
          }
          final w = (img.width! * ratio).toInt();
          final h = (img.height! * ratio).toInt();
          final canvas = html.CanvasElement(width: w, height: h);
          canvas.context2D.drawImageScaled(img, 0, 0, w, h);
          final compressed = canvas.toDataUrl('image/jpeg', 0.92);
          setState(() {
            _imageBase64 = compressed.split(',')[1];
            _imageResult = ''; _imageResultSimplified = ''; _imageResultEnglish = '';
            _imageResultVietnamese = ''; _imagePinyin = ''; _imageExplanation = ''; _extractedText = '';
          });
        });
      });
    });
  }

  Future<void> _translateImage() async {
    if (_imageBase64 == null) return;
    setState(() => _imageLoading = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/image',
        data: {'image_base64': _imageBase64, 'target_lang': _imageTargetLang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _extractedText = response.data['extracted_text'] ?? '';
        _imageResult = response.data['translated'] ?? '';
        _imageResultSimplified = response.data['translated_simplified'] ?? '';
        _imageResultEnglish = response.data['translated_english'] ?? '';
        _imageResultVietnamese = response.data['translated_vietnamese'] ?? response.data['explanation'] ?? '';
        _imagePinyin = response.data['pinyin'] ?? '';
        _imageExplanation = response.data['explanation'] ?? '';
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          final limit = detail['limit'] ?? 5;
          setState(() => _imageResult = '');
          if (mounted) _showQuotaDialog('dịch ảnh', limit);
          return;
        }
      }
      setState(() => _imageResult = 'Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      setState(() => _imageResult = 'Lỗi: $e');
    } finally {
      setState(() => _imageLoading = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      final stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
      _audioChunks = [];
      _mediaRecorder = html.MediaRecorder(stream);
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;
        if (blobEvent.data != null && blobEvent.data!.size > 0) _audioChunks.add(blobEvent.data!);
      });
      _mediaRecorder!.start();
      setState(() {
        _isRecording = true;
        _transcript = ''; _voiceResult = ''; _voiceResultSimplified = '';
        _voiceResultEnglish = ''; _voiceResultVietnamese = ''; _voicePinyin = ''; _voiceExplanation = '';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi microphone: $e')));
    }
  }

  Future<void> _stopRecording() async {
    if (_mediaRecorder == null) return;
    _mediaRecorder!.stop();
    setState(() { _isRecording = false; _voiceLoading = true; });
    await Future.delayed(const Duration(milliseconds: 500));
    final blob = html.Blob(_audioChunks, 'audio/webm');
    final reader = html.FileReader();
    reader.readAsDataUrl(blob);
    reader.onLoadEnd.listen((_) async {
      final dataUrl = reader.result as String;
      await _translateVoice(dataUrl.split(',')[1]);
    });
  }

  Future<void> _translateVoice(String audioBase64) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 60), receiveTimeout: const Duration(seconds: 60)));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/voice',
        data: {'audio_base64': audioBase64, 'target_lang': _voiceTargetLang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _transcript = response.data['transcript'] ?? '';
        _voiceResult = response.data['translated'] ?? '';
        _voiceResultSimplified = response.data['translated_simplified'] ?? '';
        _voiceResultEnglish = response.data['translated_english'] ?? '';
        _voiceResultVietnamese = response.data['translated_vietnamese'] ?? response.data['explanation'] ?? '';
        _voicePinyin = response.data['pinyin'] ?? '';
        _voiceExplanation = response.data['explanation'] ?? '';
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final detail = e.response?.data?['detail'];
        if (detail is Map && detail['code'] == 'QUOTA_EXCEEDED') {
          final limit = detail['limit'] ?? 3;
          setState(() => _voiceResult = '');
          if (mounted) _showQuotaDialog('dịch giọng nói', limit);
          return;
        }
      }
      setState(() => _voiceResult = 'Lỗi kết nối. Vui lòng thử lại.');
    } catch (e) {
      setState(() => _voiceResult = 'Lỗi: $e');
    } finally {
      setState(() => _voiceLoading = false);
    }
  }

  Future<void> _saveVocabulary(String chinese, String pinyin, String vietnamese) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio();
      await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/vocabulary',
        data: {'chinese': chinese, 'pinyin': pinyin, 'vietnamese': vietnamese, 'source': 'translate'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [Text('✅ Đã lưu từ vựng!')]),
          backgroundColor: _DS.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Từ này đã lưu rồi!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showQuotaDialog(String featureName, int limit) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Hết lượt $featureName hôm nay',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Gói Free giới hạn $limit lượt/ngày.\nNâng VIP để dùng không giới hạn!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _DS.textGrey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanh toán VIP sắp ra mắt!')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '⭐ Nâng lên VIP — NT\$149/tháng',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Để sau', style: TextStyle(color: _DS.textGrey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  bool _isSpeaking = false;

  Future<void> _speak(String text, {String lang = 'zh-TW'}) async {
    if (_isSpeaking) return; // chặn gọi chồng nhau
    setState(() => _isSpeaking = true);
    try {
      final token = await _storage.read(key: 'access_token');
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.bytes,
      ));
      final response = await dio.post(
        'https://taiwanmate-backend-production.up.railway.app/api/v1/translate/tts',
        data: {'text': text, 'lang': lang},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final b64 = base64Encode(response.data as List<int>);
      // dùng js eval để set playbackRate — giống learn_screen
      js.context.callMethod('eval', ['''
        (function() {
          if (window._translateAudio) {
            window._translateAudio.pause();
            window._translateAudio = null;
          }
          var a = new Audio("data:audio/mpeg;base64,$b64");
          a.playbackRate = ${lang == 'zh-TW' || lang == 'zh-CN' ? 0.75 : 0.9};
          window._translateAudio = a;
          setTimeout(function() { a.play(); }, 300);
        })();
      ''']);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi phát âm. Thử lại sau.')),
      );
    } finally {
      await Future.delayed(const Duration(milliseconds: 3000));
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.bg,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTextTab(), _buildImageTab(), _buildVoiceTab()],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(children: [
        const Text('Dịch thuật', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _DS.textDark, letterSpacing: -0.5)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: _DS.orangeLight, borderRadius: BorderRadius.circular(20)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('🇻🇳', style: TextStyle(fontSize: 14)),
            SizedBox(width: 4),
            Text('⇄', style: TextStyle(fontSize: 12, color: _DS.orange, fontWeight: FontWeight.w800)),
            SizedBox(width: 4),
            Text('🇹🇼', style: TextStyle(fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: _DS.textGrey,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.text_fields_rounded, size: 15), SizedBox(width: 5), Text('Văn bản'),
            ])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.image_rounded, size: 15), SizedBox(width: 5), Text('Ảnh'),
            ])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.mic_rounded, size: 15), SizedBox(width: 5), Text('Giọng nói'),
            ])),
          ],
        ),
      ),
    );
  }

  // ── TEXT TAB ──────────────────────────────────────────────────
  Widget _buildTextTab() {
    final charCount = _inputController.text.length;
    const maxChars = 500;
    final isNearLimit = charCount > 400;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Language pill selector
        _buildLangPills(),
        const SizedBox(height: 14),

        // Input card
        Container(
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radius),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(children: [
            TextField(
              controller: _inputController,
              style: const TextStyle(color: Colors.black, fontSize: 16, height: 1.5),
              maxLines: 5,
              maxLength: maxChars,
              decoration: InputDecoration(
                hintText: 'Nhập văn bản cần dịch...',
                hintStyle: TextStyle(color: _DS.textGrey.withOpacity(0.6), fontSize: 15),
                filled: true,
                fillColor: Colors.white,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                counterText: '',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
              child: Row(children: [
                // Char counter
                Text(
                  '$charCount/$maxChars',
                  style: TextStyle(fontSize: 11, color: isNearLimit ? Colors.red : _DS.textGrey, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                // Clear
                if (_inputController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _inputController.clear();
                      setState(() { _result = ''; _resultSimplified = ''; _resultEnglish = ''; _resultVietnamese = ''; _pinyin = ''; _explanation = ''; });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.clear_rounded, size: 16, color: _DS.textGrey),
                    ),
                  ),
                const SizedBox(width: 8),
                // Translate button
                GestureDetector(
                  onTap: _isLoading ? null : _translate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.translate_rounded, size: 15, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Dịch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                          ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // Quick phrases
        _buildQuickPhrases(),

        const SizedBox(height: 14),

        // Result
        if (_result.isNotEmpty || _resultEnglish.isNotEmpty || _resultVietnamese.isNotEmpty)
          _buildResultCard(
            targetLang: _targetLang,
            traditional: _result, simplified: _resultSimplified,
            english: _resultEnglish, vietnamese: _resultVietnamese,
            pinyin: _pinyin, explanation: _explanation,
            chineseForSave: _sourceLang == 'zh-TW' ? _inputController.text : _result,
            vietnameseForSave: _sourceLang == 'vi' ? _inputController.text : _resultVietnamese,
          ),

        // History
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildHistory(),
        ],
      ]),
    );
  }

  Widget _buildLangPills() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Source lang
        Expanded(child: _buildLangPill(
          langs: const [
            {'value': 'auto', 'label': '🔍 Tự động'},
            {'value': 'vi', 'label': '🇻🇳 Tiếng Việt'},
            {'value': 'zh-TW', 'label': '🇹🇼 Tiếng Trung'},
            {'value': 'en', 'label': '🇺🇸 English'},
          ],
          selected: _sourceLang,
          onChanged: (v) => setState(() => _sourceLang = v),
        )),
        // Swap button
        GestureDetector(
          onTap: _swapLanguages,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _DS.orangeLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: _DS.orange, size: 20),
          ),
        ),
        // Target lang
        Expanded(child: _buildLangPill(
          langs: const [
            {'value': 'zh-TW', 'label': '🇹🇼 Tiếng Trung'},
            {'value': 'vi', 'label': '🇻🇳 Tiếng Việt'},
            {'value': 'en', 'label': '🇺🇸 English'},
          ],
          selected: _targetLang,
          onChanged: (v) => setState(() => _targetLang = v),
        )),
      ]),
    );
  }

  Widget _buildLangPill({
    required List<Map<String, String>> langs,
    required String selected,
    required Function(String) onChanged,
  }) {
    final current = langs.firstWhere((l) => l['value'] == selected, orElse: () => langs.first);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(24)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
                decoration: BoxDecoration(color: _DS.textGrey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ...langs.map((l) => ListTile(
              title: Text(l['label']!, style: TextStyle(fontWeight: l['value'] == selected ? FontWeight.w800 : FontWeight.w500, color: l['value'] == selected ? _DS.orange : _DS.textDark)),
              trailing: l['value'] == selected ? const Icon(Icons.check_rounded, color: _DS.orange) : null,
              onTap: () { onChanged(l['value']!); Navigator.pop(context); },
            )),
            const SizedBox(height: 16),
          ]),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _DS.orangeLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(current['label']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.orange), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _DS.orange),
        ]),
      ),
    );
  }

  Widget _buildQuickPhrases() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Câu hay dùng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: _quickPhrases.map((p) => GestureDetector(
          onTap: () => _translate(overrideText: p['vi']),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _DS.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _DS.orange.withOpacity(0.25)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(p['icon']!, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(p['vi']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.textDark)),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }

  Widget _buildHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.history_rounded, size: 16, color: _DS.textGrey),
        const SizedBox(width: 6),
        const Text('Lịch sử dịch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textGrey)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _history.clear()),
          child: const Text('Xóa tất cả', style: TextStyle(fontSize: 12, color: _DS.orange, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      ...(_history.map((h) => GestureDetector(
        onTap: () => _translate(overrideText: h['input']),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _DS.white,
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h['input']!, style: const TextStyle(fontSize: 13, color: _DS.textGrey), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(h['result']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _DS.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
              if ((h['pinyin'] ?? '').isNotEmpty)
                Text(h['pinyin']!, style: const TextStyle(fontSize: 11, color: _DS.orange, fontStyle: FontStyle.italic)),
            ])),
            const Icon(Icons.north_west_rounded, size: 16, color: _DS.textGrey),
          ]),
        ),
      ))),
    ]);
  }

  // ── IMAGE TAB ─────────────────────────────────────────────────
  Widget _buildImageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildSingleLangSelector(
          value: _imageTargetLang,
          onChanged: (v) => setState(() => _imageTargetLang = v),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity, height: 200,
            decoration: BoxDecoration(
              color: _DS.white,
              borderRadius: BorderRadius.circular(_DS.radius),
              border: Border.all(
                color: _imageBase64 != null ? _DS.orange.withOpacity(0.5) : _DS.textGrey.withOpacity(0.2),
                width: _imageBase64 != null ? 2 : 1,
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: _imageBase64 != null
                ? ClipRRect(borderRadius: BorderRadius.circular(19), child: Image.memory(base64Decode(_imageBase64!), fit: BoxFit.contain))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: _DS.orangeLight, shape: BoxShape.circle),
                      child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: _DS.orange),
                    ),
                    const SizedBox(height: 12),
                    const Text('Nhấn để chọn ảnh', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textDark)),
                    const SizedBox(height: 4),
                    Text('Hỗ trợ: JPG, PNG, WEBP', style: TextStyle(fontSize: 12, color: _DS.textGrey.withOpacity(0.7))),
                  ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildOutlineBtn(label: 'Chọn ảnh khác', icon: Icons.photo_library_rounded, onTap: _pickImage)),
          const SizedBox(width: 12),
          Expanded(child: _buildGradientBtn(
            label: _imageLoading ? 'Đang dịch...' : 'Dịch ảnh',
            icon: Icons.translate_rounded,
            loading: _imageLoading,
            enabled: _imageBase64 != null,
            onTap: _translateImage,
          )),
        ]),
        const SizedBox(height: 14),
        if (_imageResult.isNotEmpty || _imageResultEnglish.isNotEmpty || _imageResultVietnamese.isNotEmpty)
          _buildResultCard(
            targetLang: _imageTargetLang,
            traditional: _imageResult, simplified: _imageResultSimplified,
            english: _imageResultEnglish, vietnamese: _imageResultVietnamese,
            pinyin: _imagePinyin, explanation: _imageExplanation,
            chineseForSave: _extractedText, vietnameseForSave: _imageResultVietnamese,
          ),
      ]),
    );
  }

  // ── VOICE TAB ─────────────────────────────────────────────────
  Widget _buildVoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _buildSingleLangSelector(
          value: _voiceTargetLang,
          onChanged: (v) => setState(() => _voiceTargetLang = v),
        ),
        const SizedBox(height: 48),

        // Mic with pulse rings
        SizedBox(
          width: 180, height: 180,
          child: Stack(alignment: Alignment.center, children: [
            // Pulse rings khi đang ghi âm
            if (_isRecording) ...[
              _PulseRing(size: 160, color: Colors.red, opacity: 0.1),
              _PulseRing(size: 140, color: Colors.red, opacity: 0.15),
              _PulseRing(size: 120, color: Colors.red, opacity: 0.2),
            ],
            // Mic button
            GestureDetector(
              onTap: _voiceLoading ? null : (_isRecording ? _stopRecording : _startRecording),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isRecording ? 100 : 84,
                height: _isRecording ? 100 : 84,
                decoration: BoxDecoration(
                  gradient: _isRecording
                      ? const LinearGradient(colors: [Colors.red, Color(0xFFB71C1C)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? Colors.red : _DS.orange).withOpacity(0.45),
                    blurRadius: _isRecording ? 30 : 16,
                    spreadRadius: _isRecording ? 4 : 0,
                    offset: const Offset(0, 6),
                  )],
                ),
                child: _voiceLoading
                    ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                    : Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 42, color: Colors.white),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        Text(
          _isRecording ? '● Đang ghi âm...' : (_voiceLoading ? 'Đang xử lý...' : 'Nhấn để bắt đầu'),
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: _isRecording ? Colors.red : _DS.textGrey,
          ),
        ),
        if (_isRecording) ...[
          const SizedBox(height: 6),
          Text('Nhấn lại để dừng và dịch', style: TextStyle(fontSize: 12, color: Colors.red.withOpacity(0.7))),
        ],

        const SizedBox(height: 32),

        if (_transcript.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _DS.white,
              borderRadius: BorderRadius.circular(_DS.radius),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.record_voice_over_rounded, size: 15, color: _DS.orange),
                const SizedBox(width: 6),
                const Text('Bạn đã nói:', style: TextStyle(fontSize: 12, color: _DS.orange, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text(_transcript, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _DS.textDark)),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (_voiceResult.isNotEmpty || _voiceResultEnglish.isNotEmpty || _voiceResultVietnamese.isNotEmpty)
          _buildResultCard(
            targetLang: _voiceTargetLang,
            traditional: _voiceResult, simplified: _voiceResultSimplified,
            english: _voiceResultEnglish, vietnamese: _voiceResultVietnamese,
            pinyin: _voicePinyin, explanation: _voiceExplanation,
            chineseForSave: _voiceResult, vietnameseForSave: _transcript,
          ),
      ]),
    );
  }

  // ── SHARED WIDGETS ────────────────────────────────────────────
  Widget _buildSingleLangSelector({required String value, required Function(String) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _DS.orange),
          items: const [
            DropdownMenuItem(value: 'zh-TW', child: Text('🇹🇼 Dịch sang Tiếng Trung')),
            DropdownMenuItem(value: 'vi', child: Text('🇻🇳 Dịch sang Tiếng Việt')),
            DropdownMenuItem(value: 'en', child: Text('🇺🇸 Dịch sang Tiếng Anh')),
          ],
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  Widget _buildOutlineBtn({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          border: Border.all(color: _DS.textGrey.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: _DS.textDark),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: _DS.textDark, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildGradientBtn({required String label, required IconData icon, required bool loading, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled && !loading ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)])
              : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade200]),
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          boxShadow: enabled ? [BoxShadow(color: _DS.orange.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildResultCard({
    required String targetLang,
    required String traditional, required String simplified,
    required String english, required String vietnamese,
    required String pinyin, required String explanation,
    String chineseForSave = '', String vietnameseForSave = '',
  }) {
    final tabs = _getDisplayTabs(targetLang: targetLang, traditional: traditional, simplified: simplified, english: english, vietnamese: vietnamese);
    if (tabs.isEmpty) return const SizedBox.shrink();

    final safeIndex = _selectedScript.clamp(0, tabs.length - 1);
    final currentTab = tabs[safeIndex];
    final displayText = currentTab['value'] ?? '';
    final displayLang = currentTab['lang'] ?? 'zh-TW';
    final isChinese = displayLang == 'zh-TW' || displayLang == 'zh-CN';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _DS.white,
        borderRadius: BorderRadius.circular(_DS.radius),
        boxShadow: [BoxShadow(color: _DS.orange.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: _DS.orange.withOpacity(0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Script tab switcher
        if (tabs.length > 1)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final isSelected = _selectedScript == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedScript = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(colors: [_DS.orange, Color(0xFFFFB300)]) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tabs[i]['label'] ?? '', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : _DS.textGrey)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Main translation
        Padding(
          padding: EdgeInsets.fromLTRB(16, tabs.length > 1 ? 0 : 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (pinyin.isNotEmpty && isChinese) ...[
              Text(pinyin, style: const TextStyle(fontSize: 13, color: _DS.orange, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
            ],
            Text(
              displayText.isNotEmpty ? displayText : 'Không có bản dịch',
              style: TextStyle(
                fontSize: isChinese ? 32 : 22,
                fontWeight: FontWeight.w900,
                color: displayText.isNotEmpty ? _DS.textDark : _DS.textGrey,
                height: 1.3,
              ),
            ),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _DS.bg, borderRadius: BorderRadius.circular(10)),
                child: Text(explanation, style: const TextStyle(fontSize: 13, color: _DS.textGrey, height: 1.5)),
              ),
            ],
          ]),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (displayText.isNotEmpty)
              _buildActionBtn(icon: Icons.volume_up_rounded, label: 'Nghe', onTap: () => _speak(displayText, lang: displayLang)),
            const SizedBox(width: 8),
            _buildActionBtn(
              icon: Icons.copy_rounded, label: 'Sao chép',
              onTap: () {
                Clipboard.setData(ClipboardData(text: displayText));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Đã sao chép!'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 1),
                ));
              },
            ),
            if (isChinese) ...[
              const SizedBox(width: 8),
              _buildActionBtn(
                icon: Icons.bookmark_add_rounded, label: 'Lưu từ',
                onTap: () => _saveVocabulary(
                  chineseForSave.isNotEmpty ? chineseForSave : traditional, pinyin,
                  vietnameseForSave.isNotEmpty ? vietnameseForSave : explanation,
                ),
                isPrimary: true,
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildActionBtn({required IconData icon, required String label, required VoidCallback onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? _DS.orangeLight : _DS.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isPrimary ? _DS.orange : _DS.textGrey),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPrimary ? _DS.orange : _DS.textGrey)),
        ]),
      ),
    );
  }
}

// ─── Pulse Ring Widget ────────────────────────────────────────
class _PulseRing extends StatefulWidget {
  final double size;
  final Color color;
  final double opacity;
  const _PulseRing({required this.size, required this.color, required this.opacity});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
    _scale = Tween<double>(begin: 0.8, end: 1.3).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: widget.opacity, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_fade.value),
          ),
        ),
      ),
    );
  }
}
