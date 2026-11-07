# taiwanmate_ai

A new Flutter project.

## Phiên bản Flutter (bắt buộc)

**Flutter 3.44.2** (stable, Dart 3.12.2) — bản đang build production (CTO chốt 07/11/2026).

- Mọi phiên (người hoặc AI) chạy `flutter pub get`, `flutter test`, `flutter build web` bằng **đúng bản này**; FVM đọc `.fvmrc`.
- Chốt chặn: `test/flutter_version_pin_test.dart` đỏ khi chạy test bằng bản khác. (`environment.flutter: 3.44.2` trong `pubspec.yaml` chỉ chặn bản CŨ hơn — pub bỏ qua cận trên của ràng buộc Flutter, đã thử với 3.47.7.)
- **Không commit `pubspec.lock` bị đổi do lệch SDK.** Bản khác (vd 3.47.x) tự đổi ~16 dòng của các gói đi kèm SDK và thêm mục vào `analysis_options.yaml` — hoàn tác những thay đổi đó.
- Tải bản Linux (kiểm sha256 trong `releases_linux.json` của Flutter): `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.2-stable.tar.xz` — sha256 `b0de1d19754688ec6769c9a067db3b0594479d3d767f971bfecfc132904c8d5e`.
- Bản web trong `docs/` là bản đang phát hành (GitHub Pages): chỉ build khi được duyệt.
- Nâng bản: sửa `pubspec.yaml` + `.fvmrc` + mục này trong cùng 1 commit, chạy lại toàn bộ test.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
