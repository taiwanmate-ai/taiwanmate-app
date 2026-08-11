/// Bug nghiem trong da audit (2026-08-12): _cleanHistory o chat_screen.dart
/// TRUOC DAY dung .take(8) tren danh sach xep THEO THU TU THOI GIAN TANG
/// DAN (tin cu o dau, tin moi o cuoi) -> lay nham 8 tin CU NHAT thay vi 8
/// tin GAN NHAT. Hau qua: hoi thoai qua 8 tin la AI mat sach ngu canh gan
/// day nhat, co the tra loi SAI mot cach tu tin (khong chi "hoi lai") - da
/// xac nhan tai hien that qua gpt-4o-mini that (khong phai gia thuyet
/// "prompt qua tai rule" nhu nghi ngo ban dau, da bi bac bo bang thuc
/// nghiem: rut gon toi da system_prompt van khong sua duoc gi neu history
/// van thieu dung luot can thiet).
///
/// Ham thuan tuy (khong phu thuoc BuildContext/State) de co the unit test
/// truc tiep, khong can widget test.
library;

/// Loc bo tin rong/canh bao (⚠️), roi lay dung [limit] tin GAN NHAT (khong
/// phai [limit] tin dau tien), GIU NGUYEN thu tu thoi gian tang dan (cu ->
/// moi) trong ket qua tra ve - dung thu tu ma OpenAI messages array can.
List<Map<String, dynamic>> buildCleanChatHistory(
  List<Map<String, dynamic>> messages, {
  int limit = 8,
}) {
  final filtered = messages.where((m) {
    final content = m['content'];
    return content != null &&
        content is String &&
        !content.startsWith('⚠️') &&
        content.isNotEmpty;
  }).toList();

  final start = filtered.length > limit ? filtered.length - limit : 0;
  return filtered
      .sublist(start)
      .map((m) => {'role': m['role'], 'content': m['content']})
      .toList();
}
