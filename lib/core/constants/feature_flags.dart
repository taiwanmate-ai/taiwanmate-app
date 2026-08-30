/// feature_flags.dart — co hang so BAT/TAT tinh nang don gian, KHONG xoa
/// code lien quan (2026-08-31).
///
/// Muc dich: cho phep an/hien 1 tinh nang CHUA san sang/tam ngung ma
/// KHONG can xoa/viet lai code — chi doi gia tri `true`/`false` roi
/// build lai. Dat cac cot rieng le (giong tinh than premium_model_access
/// o backend: moi flag 1 hang so RIENG, KHONG gop chung enum/map) de
/// de theo doi tung tinh nang doc lap.
library;

/// Tab "Cộng đồng" o thanh dieu huong duoi cung (xem main_shell.dart +
/// app_router.dart) — dat false de AN HOAN TOAN khoi UI (khong chi mo/
/// khong hien BottomNavigationBarItem) VA khong dang ky StatefulShellBranch/
/// GoRoute tuong ung trong appRouter, dam bao CommunityScreen KHONG BAO
/// GIO duoc mount/goi API (/community/posts, /community/sos...) khi cờ
/// nay tat, du user co the nao co gang dieu huong toi.
const bool kCommunityTabEnabled = false;
