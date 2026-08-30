/// Audit "Speech Naturalizer" cho Voice Chat (2026-08-24) — bóc tag
/// [MOOD:...] do AI tự chèn ở đầu MỖI câu (theo hướng dẫn thêm vào
/// system_prompt riêng cho Voice, xem voice_chat_screen.dart) TRƯỚC khi
/// đưa văn bản vào TTS — tag KHÔNG được đọc thành tiếng.
///
/// QUAN TRỌNG — parse ở cấp độ CÂU HOÀN CHỈNH (sau khi SentenceAccumulator
/// đã gom xong 1 câu), KHÔNG parse trên từng delta streaming thô — tránh
/// vấn đề tag bị cắt giữa chừng qua nhiều delta mạng (vd "[MOO" rồi
/// "D:play" rồi "ful]"). Vì mỗi câu đã hoàn chỉnh khi tới đây, tag (nếu
/// AI có chèn) LUÔN nguyên vẹn trong 1 chuỗi.
library;

/// Danh sách mood THU HẸP (xem docstring app/services/tts_style_map.py
/// phía backend — 2 nơi PHẢI khớp nhau, đây là 1 trong 2 "nguồn sự thật"
/// của tên mood, không tự ý thêm/đổi tên ở 1 bên mà không sửa bên kia).
const kValidMoods = {'neutral', 'happy', 'comforting', 'playful'};

const kDefaultMood = 'neutral';

final RegExp _moodTagRe = RegExp(r'^\s*\[MOOD:(\w+)\]\s*', caseSensitive: false);
final RegExp _moodTagStripAnyRe = RegExp(r'\[MOOD:\w+\]\s*', caseSensitive: false);

/// Bóc SẠCH mọi tag [MOOD:...] xuất hiện ở BẤT KỲ đâu trong chuỗi — dùng
/// cho hiển thị UI (_aiText, xem voice_chat_screen.dart) vì text hiển thị
/// được ghép từ delta THÔ (chưa qua extractMoodTag() theo câu), nên 1 tag
/// có thể tạm thời xuất hiện KHÔNG ở đầu chuỗi tích luỹ. An toàn gọi lại
/// nhiều lần (idempotent) — tag đang bị cắt dở (vd "[MOO") sẽ tự biến mất
/// khi phần còn lại của tag tới trong delta kế tiếp.
String stripMoodTagsForDisplay(String text) => text.replaceAll(_moodTagStripAnyRe, '');

class MoodExtractionResult {
  const MoodExtractionResult({required this.mood, required this.text});
  final String mood;
  final String text;
}

/// Bóc [MOOD:xxx] ở ĐẦU câu (nếu có) — trả về mood đã chuẩn hoá (fallback
/// 'neutral' nếu AI không chèn tag, hoặc chèn giá trị lạ không nằm trong
/// kValidMoods — KHÔNG BAO GIỜ để 1 giá trị không hợp lệ lọt xuống tầng
/// TTS) và phần text ĐÃ BỎ tag, sẵn sàng đưa vào MultilingualTtsSegmenter.
MoodExtractionResult extractMoodTag(String sentence) {
  final match = _moodTagRe.firstMatch(sentence);
  if (match == null) {
    return MoodExtractionResult(mood: kDefaultMood, text: sentence);
  }
  final raw = match.group(1)!.toLowerCase();
  final mood = kValidMoods.contains(raw) ? raw : kDefaultMood;
  return MoodExtractionResult(mood: mood, text: sentence.substring(match.end));
}

/// Đoạn instruction nối thêm vào system_prompt CHỈ CHO VOICE (xem
/// voice_chat_screen.dart — nối SAU buildSystemPromptV2(), KHÔNG đụng
/// companion_personality_engine.dart theo đúng yêu cầu "không rewrite
/// Personality Engine"). Gộp 2 việc trong CÙNG 1 đoạn, CÙNG 1 lần gọi
/// chat_stream() đã có — không thêm request/LLM call nào:
///   1. Speech Naturalizer — viết theo văn NÓI thay vì văn viết.
///   2. Mood tag — bắt buộc đánh dấu [MOOD:...] đầu mỗi câu để client bóc
///      ra chọn SSML prosody phù hợp (xem app/services/tts_style_map.py
///      phía backend — danh sách mood PHẢI khớp kValidMoods ở trên).
///
/// AN TOÀN: nhắc lại (không phải chỗ enforce chính — backend voice_ws.py
/// mới là nơi ép cứng "comforting" khi Safety Override kích hoạt, xem
/// docstring ở đó) để mô hình tự ý thức ngay từ bước sinh text, giảm khả
/// năng phải dựa 100% vào lớp ép sau.
const String kVoiceNaturalizerInstruction = '''

[HƯỚNG DẪN GIỌNG NÓI — CHỈ ÁP DỤNG CHO VOICE, KHÔNG ĐỔI NỘI DUNG/THÔNG TIN]
Đây là hội thoại bằng GIỌNG NÓI, không phải tin nhắn văn bản — hãy viết câu trả lời theo cách NGƯỜI THẬT NÓI CHUYỆN, không phải văn viết trang trọng:
- Câu ngắn, tự nhiên, có thể dùng dấu "..." để tạo khoảng ngắt tự nhiên khi phù hợp — NGOẠI TRỪ tiếng cười/từ tượng thanh lặp âm tiết (xem quy tắc riêng ngay dưới đây, "..." KHÔNG áp dụng cho trường hợp đó).
- Có thể dùng từ đệm tự nhiên của NGÔN NGỮ ĐANG NÓI trong câu đó (ví dụ "ừm", "nè", "nha", "nhỉ" cho tiếng Việt) — CHỈ khi thật sự tự nhiên, KHÔNG lạm dụng, KHÔNG thêm vào mọi câu.
- TIẾNG CƯỜI/TỪ TƯỢNG THANH LẶP ÂM TIẾT (haha, hihi, hehe, 哈哈, 呵呵...) PHẢI viết LIỀN thành 1 khối DUY NHẤT — KHÔNG chèn dấu "..." hay dấu chấm ở giữa các âm tiết hoặc ngay sau khối cười, KHÔNG tách rời từng âm tiết bằng khoảng trắng — KỂ CẢ KHI user tự viết/yêu cầu đúng dạng tách rời đó, LUÔN chuẩn hoá về dạng viết liền khi bạn tự sinh ra tiếng cười. Tiếng cười thật đọc NHANH, DỨT KHOÁT — không phải 1 khoảng dừng kịch tính.
  SAI: "Ha... Ha... Ha", "HA HA HA", "Haha... thật buồn cười", "哈...哈...哈"
  ĐÚNG: "Haha", "Hahaha", "哈哈哈"
- TUYỆT ĐỐI KHÔNG đổi ý nghĩa, KHÔNG thêm thông tin mới, KHÔNG bỏ nội dung học tập.
- KHÔNG được phá vỡ cấu trúc/quy tắc ngôn ngữ đã yêu cầu ở trên (nếu đang ở chế độ song ngữ: câu chính + (dịch Việt) trong ngoặc) — chỉ làm cách diễn đạt tự nhiên hơn, không đổi cấu trúc đó.

[MOOD TAG — BẮT BUỘC]
Đặt CHÍNH XÁC 1 tag ở ĐẦU MỖI câu, dạng [MOOD:tên_mood], chọn 1 trong 4 giá trị sau theo đúng cảm xúc của câu đó — KHÔNG dùng giá trị nào khác ngoài 4 giá trị này:
- neutral: câu thông tin/dạy học bình thường.
- happy: vui vẻ, khen, ăn mừng.
- comforting: an ủi, quan tâm thật sự, đồng cảm khi user buồn/mệt/stress — LUÔN dùng mood này khi user đang cần được an ủi, KHÔNG bao giờ dùng playful/happy trong tình huống đó.
- playful: đùa vui, trend, cà khịa nhẹ nhàng mang tính học tập.
Ví dụ: [MOOD:happy] Giỏi quá! Bạn tiến bộ nhiều lắm đó.
Tag KHÔNG được đọc thành tiếng — đây là format nội bộ, client sẽ tự bóc tag trước khi phát âm thanh.''';
