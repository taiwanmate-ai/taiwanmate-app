# Hướng dẫn owner: build bản Android 1.0.0 (56) để tải lên Google Play

Script `scripts\build_android.ps1` đã chạy xanh trên CI Windows (Windows PowerShell 5.1, workflow `android-build`). CI có thử cả 2 trường hợp script phải dừng: versionCode không lớn hơn Play, và baseUrl trỏ vào localhost. Bản `.aab` của CI ký bằng khóa tạm, **không dùng để tải lên**.

Bản này gồm:
- màn hình "Chặng tiếp theo ra mắt ngày X";
- các sửa lỗi đã có trên web từ bản 55.

Giáo trình mới vẫn chỉ hiện với tài khoản trong allowlist, vì server quyết định chuyện này, không phải app.

## 1. Chuẩn bị (PowerShell, từng dòng)

```powershell
cd C:\taiwanmate\app                       # thư mục repo app trên máy (đổi nếu khác)
git checkout main
git pull origin main
git log --oneline -1                       # phải là commit có "version 1.0.0+56" hoặc mới hơn
flutter --version                          # dòng đầu phải là: Flutter 3.44.2
Test-Path android\key.properties           # phải in True (file ký bản phát hành, không có trong git)
```

Nếu repo app **không** nằm trên ổ C:, Kotlin có thể báo lỗi `Could not close incremental caches`. Khi đó chạy thêm dòng sau một lần, và không commit thay đổi này:

```powershell
Add-Content android\gradle.properties "`nkotlin.incremental=false"
```

## 2. Chạy

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_android.ps1
```

Script hỏi `Nhap versionCode LON NHAT dang co tren Play Console`. Mở Play Console, vào **App bundle explorer**, xem số lớn nhất (ví dụ `55`), gõ số đó rồi Enter.

## 3. Thấy gì là đúng

| Bước | Màn hình đúng |
|---|---|
| 1/5 | `OK: Flutter 3.44.2` |
| 2/5 | `OK: baseUrl = server production` · `OK: keystore …, alias …` · `pubspec.yaml: versionName 1.0.0, versionCode 56` · `OK: versionCode 56 > 55` |
| 3/5 | danh sách package, không có chữ `LOI` |
| 4/5 | 5–15 phút, cuối cùng `√ Built build\app\outputs\bundle\release\app-release.aab` |
| 5/5 | `File: …app-release.aab (khoảng 110 MB)` · `SHA-256: …` · `Chu ky SHA-1: …` · `XONG: 1.0.0 (56)` |

**Kiểm tra chữ ký:** dòng `Chu ky SHA-1` phải trùng với **Upload key certificate → SHA-1** trên Play Console (Setup → App integrity). Nếu không trùng thì đừng tải lên; báo CTO.

**Nếu thấy chữ `LOI:` màu đỏ:** script đã dừng. Chụp màn hình gửi CTO.

## 4. Tải lên

Play Console → Testing → **Internal testing** → Create new release → tải `build\app\outputs\bundle\release\app-release.aab`.
- Cài thử trên điện thoại bằng tài khoản owner.
- Kiểm tra: mở tab Học, vào một bài tình huống, học xong bài mới cuối cùng, phải thấy thẻ "Chặng … ra mắt …".
- Thấy đúng thì mới chuyển sang Production.

## Hoàn tác

Bản internal chưa tới tay người dùng. Nếu đã lên Production mà có lỗi: Play Console → Production → **Halt rollout**, rồi báo CTO. Không cần làm gì trên máy.
