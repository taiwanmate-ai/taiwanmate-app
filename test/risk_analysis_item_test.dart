// parseRiskAnalysisItem() — audit toan app 2026-10-06. Field 'level' TRUOC DAY dung "as String"
// tin mu (crash neu AI/backend tra kieu khac String cho field nay, du da co guard "raw is Map"
// cho ca item). Backend da chuan hoa rieng (_normalize_risk_analysis), day la luoi an toan
// THEM o mobile.
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/translate/presentation/screens/translate_screen.dart';

void main() {
  test('dung schema giu nguyen', () {
    final r = parseRiskAnalysisItem({'clause': 'Điều 5', 'level': 'NGUY_HIEM', 'note': 'Dưới lương tối thiểu'});
    expect(r, {'level': 'NGUY_HIEM', 'clause': 'Điều 5', 'note': 'Dưới lương tối thiểu', 'icon': '🔴'});
  });

  test('level la so (sai kieu) -> ep ve chuoi bang .toString(), khong crash', () {
    final r = parseRiskAnalysisItem({'clause': 'A', 'level': 1, 'note': 'n'});
    expect(r['level'], '1');
    expect(r['icon'], '⚪'); // khong khop NGUY_HIEM/CO_LOI -> icon trung tinh, khong crash
  });

  test('item khong phai Map (vd 1 chuỗi trần) -> khong crash, tra gia tri mac dinh', () {
    final r = parseRiskAnalysisItem('chuỗi lạc trong list');
    expect(r, {'level': 'BINH_THUONG', 'clause': '', 'note': '', 'icon': '⚪'});
  });

  test('CO_LOI -> icon xanh', () {
    expect(parseRiskAnalysisItem({'level': 'CO_LOI'})['icon'], '🟢');
  });

  test('thieu field -> mac dinh rong, khong crash', () {
    final r = parseRiskAnalysisItem(<String, dynamic>{});
    expect(r, {'level': 'BINH_THUONG', 'clause': '', 'note': '', 'icon': '⚪'});
  });
}
