# Quản lý chi tiêu

Ứng dụng di động giúp người dùng theo dõi tài khoản và các khoản thu, chi tại một nơi. 

## Chức năng chính

- Quản lý tài khoản: thêm tài khoản, theo dõi số dư và xem danh sách tài khoản.
- Quản lý giao dịch thu, chi và cập nhật số dư tài khoản.
- Phân loại giao dịch theo danh mục như ăn uống, mua sắm, di chuyển, hóa đơn, giải trí, lương và chuyển tiền.
- Xem tổng số dư, tổng thu và tổng chi; ứng dụng dùng biểu đồ để trực quan hóa dữ liệu.
- Hỗ trợ nhận diện thông báo giao dịch ngân hàng qua dịch vụ đọc thông báo Android (Tính năng này cần người dùng tự cấp quyền truy cập thông báo trong Cài đặt của thiết bị).

## Công nghệ sử dụng

- **Android Native Notification Listener Service**:
  • Lắng nghe thông báo từ các ứng dụng ngân hàng và ví điện tử phổ biến: Vietcombank, MB Bank, Agribank, BIDV, Momo, ZaloPay, Techcombank,...
  • Sử dụng Regex để tự động phân tích:
    ◦ Số tiền (Amount)
    ◦ Loại giao dịch (Thu nhập / Chi tiêu)
    ◦ Số dư sau giao dịch (Balance after)
    ◦ Số tài khoản / Ví (Account number)
  • Tự động kiểm tra: Nếu tài khoản chưa tồn tại trong SQLite, ứng dụng sẽ tự động tạo tài khoản mới; nếu đã có, tự động ghi nhận giao dịch và cập nhật số dư.
- **Flutter và Dart**: xây dựng ứng dụng di động đa nền tảng. Dự án yêu cầu Dart SDK tương thích với `^3.13.3` (khai báo trong `pubspec.yaml`).
- **SQLite (`sqflite`)**: lưu dữ liệu tài khoản, giao dịch và danh mục trên thiết bị.
- **`fl_chart`**: hiển thị biểu đồ thống kê.
- **`shared_preferences`**: lưu một số thiết lập đơn giản trên thiết bị.
- **`intl`**: định dạng số liệu và ngày tháng.
- **Android Studio, Android SDK và Java 17**: cần để biên dịch/chạy ứng dụng Android. Android Studio thường cung cấp JDK đi kèm; nếu cài JDK riêng, dùng Java 17.

Các thư viện Dart/Flutter được khai báo trong `pubspec.yaml` và cài tự động bằng `flutter pub get`, không cần cài từng thư viện thủ công.

## Cài đặt và chạy dự án

### Yêu cầu

- Git.
- Flutter SDK có Dart SDK tương thích với `^3.13.3`.
- Android Studio và Android SDK để chạy trên Android hoặc máy ảo Android.
- Java 17 (có thể dùng JDK đi kèm Android Studio).

### 1. Clone mã nguồn

Mở Terminal/PowerShell tại thư mục muốn lưu dự án và chạy:

```bash
git clone https://github.com/tieutien2312-hash/ql_chi_tieu.git
cd ql_chi_tieu
```

### 2. Kiểm tra môi trường Flutter

```bash
flutter doctor
```

Cài bổ sung các thành phần còn thiếu theo kết quả lệnh, đặc biệt là Android SDK và giấy phép Android SDK nếu phát triển cho Android.

### 3. Cài các thư viện phụ thuộc

Tại thư mục dự án (cùng cấp với `pubspec.yaml`), chạy:

```bash
flutter pub get
```

### 4. Chạy ứng dụng trên Android

Khởi động máy ảo Android trong Android Studio hoặc kết nối điện thoại đã bật **Tùy chọn nhà phát triển** và **Gỡ lỗi USB**. Kiểm tra thiết bị:

```bash
flutter devices
```

Sau đó chạy ứng dụng:

```bash
flutter run
```

### Tạo APK (tùy chọn)

```bash
flutter build apk --release
```

APK được tạo tại `build/app/outputs/flutter-apk/app-release.apk`. Cấu hình hiện tại dùng khóa debug để ký bản release phục vụ chạy thử; cần thiết lập khóa ký release riêng trước khi phát hành rộng rãi.

## Cấu trúc thư mục

- `lib/`: mã nguồn Dart, gồm màn hình, mô hình dữ liệu và dịch vụ.
- `android/`: cấu hình và mã tích hợp Android.
- `assets/`: tài nguyên hình ảnh và biểu tượng ứng dụng.
- `pubspec.yaml`: thông tin dự án và danh sách thư viện phụ thuộc.

## Lưu ý

- Điểm vào ứng dụng là `lib/main.dart`.
- Ứng dụng lưu tài khoản và giao dịch cục bộ bằng SQLite. Gỡ ứng dụng khỏi thiết bị có thể làm mất dữ liệu.
- Tính năng nhận thông báo giao dịch cần được cấp quyền truy cập thông báo trong Cài đặt Android.
