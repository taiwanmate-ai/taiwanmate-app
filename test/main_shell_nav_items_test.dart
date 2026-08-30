/// AUDIT "an tab Cong dong" (2026-08-31).
///
/// Unit test THUAN (khong can widget/router/network — buildMainShellNavItems()
/// la ham top-level KHONG phu thuoc BuildContext) goi TRUC TIEP ham CHINH
/// MainShell.build() dung de sinh danh sach BottomNavigationBarItem, xac
/// nhan:
///   1. kCommunityTabEnabled dang la false (gia tri that trong production).
///   2. "Cộng đồng" KHONG con trong danh sach.
///   3. Dung 7 item con lai, THEO DUNG THU TU (Home, Dịch, Học, AI Chat,
///      Live, Công cụ, Cá nhân) — day la bang chung KHACH QUAN chong
///      lech index giua danh sach items (main_shell.dart) va danh sach
///      branches (app_router.dart), vi 2 danh sach nay PHAI dong bo vi
///      tri/so luong de _onTap()->goBranch(index) dieu huong dung tab.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/shared/widgets/main_shell.dart';
import 'package:chinesemate/core/constants/feature_flags.dart';

void main() {
  test('kCommunityTabEnabled dang tat (production)', () {
    expect(kCommunityTabEnabled, isFalse);
  });

  test('buildMainShellNavItems() an hoan toan tab Cong dong, giu dung 7 tab con lai theo dung thu tu', () {
    final items = buildMainShellNavItems();

    expect(
      items.any((i) => i.label == 'Cộng đồng'),
      isFalse,
      reason: 'Tab "Cộng đồng" PHAI bi loai HOAN TOAN khoi danh sach khi kCommunityTabEnabled=false, khong chi an bang style',
    );

    const expectedLabels = ['Home', 'Dịch', 'Học', 'AI Chat', 'Live', 'Công cụ', 'Cá nhân'];
    expect(
      items.length,
      expectedLabels.length,
      reason: 'PHAI con dung ${expectedLabels.length} tab (khong thua/thieu do loi filter)',
    );
    for (var i = 0; i < expectedLabels.length; i++) {
      expect(
        items[i].label,
        expectedLabels[i],
        reason: 'Tab vi tri $i (dung de goBranch($i)) phai la "${expectedLabels[i]}" — lech vi tri o day se khien bam tab sai dieu huong sai route',
      );
    }
  });
}
