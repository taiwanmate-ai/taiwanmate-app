/// SentenceAccumulator — Buoc 4b (2026-08-15), ham thuan (khong
/// BuildContext, khong mang, khong TTS) tach 1 chuoi DELTA text lien tuc
/// (tu AI streaming qua VoiceWebSocketService) thanh CAC CAU HOAN CHINH
/// ngay khi co du dau cau ket thuc (。！？.!?), giu lai phan con thieu dau
/// cau cho delta tiep theo.
///
/// Day la logic "khi nao 1 cau du de bat dau TTS ngay" — tach RIENG khoi
/// VoiceWebSocketService (chi lo protocol WebSocket) va
/// CompanionVoiceController (chi lo fetch/phat TTS), giong dung tinh than
/// "moi lop 1 trach nhiem" da dung xuyen suot app nay — de test doc lap
/// bang chuoi delta gia lap (khong can WebSocket that/TTS that).
///
/// Dau cau nhan dien khop DUNG voi MultilingualTtsSegmenter (._endsSentence)
/// — 。！？.!? — dam bao "1 cau hoan chinh" theo dinh nghia nay CUNG la
/// don vi ma segmenter se tach dung khi CompanionVoiceController.
/// appendStreamingSentence() goi _segmenter.segment() sau do.
library;

class SentenceAccumulator {
  final StringBuffer _buffer = StringBuffer();
  static final RegExp _sentenceEnd = RegExp('[。！？.!?]');

  /// True neu DA TUNG tra ve it nhat 1 cau thuc su (co noi dung) — dung de
  /// biet mot doan chi toan dau cau o DAU 1 lan goi addDelta() la phan
  /// "duoi" cua 1 cau da tra ve o lan goi TRUOC (khong the noi lai duoc
  /// nua), khac voi truong hop chua tung co cau nao (giu nguyen hanh vi cu).
  bool _hasEmittedSentence = false;

  /// Them 1 doan delta text moi (vd 1 token/1 vai ky tu tu AI streaming).
  /// Tra ve danh sach CAU HOAN CHINH phat hien duoc trong lan goi nay (co
  /// the rong neu chua du 1 cau nao, co the co NHIEU cau neu delta nay
  /// chua gon nhieu dau cau lien tiep). Phan con thieu dau cau duoc GIU
  /// LAI noi bo cho lan addDelta() tiep theo.
  ///
  /// QUAN TRONG (fix 2026-08-27, phat hien qua benchmark Speech
  /// Naturalizer): dau "..." (3 dau cham lien tiep, AI duoc khuyen dung de
  /// tao khoang ngat tu nhien — xem kVoiceNaturalizerInstruction) la 3 lan
  /// khop _sentenceEnd LIEN TIEP — co the toi trong CUNG 1 delta, hoac RAI
  /// RAC qua NHIEU delta rieng (vd token-by-token, moi dau cham 1 token).
  /// Neu tach ngay tai moi dau cham, cac dau cham sau se tro thanh "cau"
  /// RONG CHI CO 1 KY TU "." — bi day qua TTS thanh 1 segment am thanh rac
  /// (chi phat 1 dau cham) thay vi la phan tiep cua cau truoc do. Xu ly:
  /// - Neu dau cau du thua nam TRONG CUNG 1 lan goi nay (sentences cua lan
  ///   goi nay da co san cau truoc do) -> NOI vao cuoi cau do.
  /// - Neu cau truoc do da tra ve o lan goi TRUOC (khong the sua lai chuoi
  ///   da tra ve) -> BO QUA (khong tao "cau" gia chi co dau cau), thay vi
  ///   danh doi lay 1 segment TTS rac.
  List<String> addDelta(String delta) {
    if (delta.isEmpty) return const [];
    _buffer.write(delta);
    final text = _buffer.toString();
    final sentences = <String>[];
    int lastEnd = 0;
    for (final match in _sentenceEnd.allMatches(text)) {
      final end = match.end;
      final chunk = text.substring(lastEnd, end).trim();
      lastEnd = end;
      if (chunk.isEmpty) continue;
      if (_isOnlyTerminators(chunk)) {
        if (sentences.isNotEmpty) {
          sentences[sentences.length - 1] = '${sentences.last}$chunk';
        } else if (!_hasEmittedSentence) {
          sentences.add(chunk);
          _hasEmittedSentence = true;
        }
        // else: cau truoc do da tra ve o lan goi truoc -> bo qua dau cau du.
        continue;
      }
      sentences.add(chunk);
      _hasEmittedSentence = true;
    }
    final remainder = text.substring(lastEnd);
    _buffer.clear();
    _buffer.write(remainder);
    return sentences;
  }

  static bool _isOnlyTerminators(String chunk) {
    for (final unit in chunk.split('')) {
      if (!_sentenceEnd.hasMatch(unit)) return false;
    }
    return true;
  }

  /// Goi khi stream ket thuc (server bao is_final=true) — tra ve phan
  /// CON LAI chua co dau cau ket thuc (AI co the ket thuc cau tra loi ma
  /// khong co dau cau, hoac cau cuoi bi cat) de KHONG mat noi dung; chuoi
  /// rong neu khong con gi con lai. Reset buffer sau khi goi.
  String flush() {
    final remainder = _buffer.toString().trim();
    _buffer.clear();
    return remainder;
  }
}
