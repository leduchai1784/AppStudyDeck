# Hướng dẫn Sửa Lỗi Network Request Failed

## Lỗi: `network-request-failed`

Lỗi này xảy ra khi Firebase Auth không thể kết nối đến server. Đã thực hiện các sửa đổi sau:

### 1. Đã thêm vào AndroidManifest.xml:
- ✅ INTERNET permission
- ✅ ACCESS_NETWORK_STATE permission  
- ✅ Network Security Config để cho phép cleartext traffic
- ✅ usesCleartextTraffic="true"

### 2. Đã tạo network_security_config.xml:
- ✅ Cho phép cleartext traffic cho Firebase domains
- ✅ Trust Firebase, Google APIs domains

## Các bước kiểm tra và sửa:

### Bước 1: Rebuild ứng dụng
```bash
flutter clean
flutter pub get
flutter run
```

### Bước 2: Kiểm tra Android Emulator có internet không

1. Mở Android Emulator
2. Vào Settings > Network & Internet
3. Kiểm tra WiFi/Mobile data đã bật chưa
4. Mở Chrome trong emulator, thử vào google.com

**Nếu emulator không có internet:**
- Restart emulator
- Hoặc tạo emulator mới với internet enabled
- Hoặc test trên thiết bị thật

### Bước 3: Kiểm tra Firewall/Antivirus

Firewall hoặc Antivirus có thể chặn kết nối đến Firebase:

1. Tạm thời tắt Firewall/Antivirus
2. Thử đăng ký lại
3. Nếu thành công → Thêm exception cho Flutter/Firebase

### Bước 4: Kiểm tra Proxy/VPN

Nếu đang dùng Proxy hoặc VPN:

1. Tắt Proxy/VPN
2. Thử đăng ký lại
3. Nếu thành công → Cấu hình Proxy để cho phép Firebase domains

### Bước 5: Kiểm tra Firebase Console

1. Vào Firebase Console: https://console.firebase.google.com
2. Kiểm tra project có hoạt động không
3. Kiểm tra Authentication > Sign-in method:
   - Email/Password phải được **Enable**
   - Nếu chưa enable → Click Enable và Save

### Bước 6: Test trên thiết bị thật

Nếu emulator vẫn lỗi:

1. Build APK: `flutter build apk`
2. Cài đặt trên thiết bị Android thật
3. Test đăng ký

### Bước 7: Kiểm tra Logs chi tiết

Xem console logs để tìm thêm thông tin:

```
❌ FirebaseAuthException: network-request-failed - A network error...
```

Nếu thấy thêm thông tin như:
- `timeout` → Kết nối quá chậm
- `interrupted connection` → Kết nối bị ngắt
- `unreachable host` → Không thể đến được server

## Giải pháp nhanh:

### Nếu đang dùng Android Emulator:
1. **Restart emulator** (thường giải quyết được 80% trường hợp)
2. Hoặc **tạo emulator mới** với internet enabled
3. Hoặc **test trên thiết bị thật**

### Nếu đang dùng thiết bị thật:
1. Kiểm tra **WiFi/Mobile data** đã bật chưa
2. Kiểm tra **Firewall/Antivirus** có chặn không
3. Thử **tắt VPN/Proxy** nếu có
4. Kiểm tra **Firebase Console** > Authentication > Sign-in method

## Kiểm tra nhanh:

1. **Mở browser trong emulator/device** → Vào google.com
   - Nếu không vào được → Vấn đề về internet
   - Nếu vào được → Vấn đề về Firebase config

2. **Kiểm tra Firebase Console** → Authentication > Sign-in method
   - Email/Password phải được Enable

3. **Xem console logs** khi đăng ký
   - Tìm dòng có `❌ FirebaseAuthException`
   - Xem error code và message chi tiết

## Nếu vẫn không được:

1. **Rebuild project hoàn toàn:**
   ```bash
   flutter clean
   cd android
   ./gradlew clean
   cd ..
   flutter pub get
   flutter run
   ```

2. **Kiểm tra google-services.json:**
   - File `android/app/google-services.json` phải tồn tại
   - File phải đúng với Firebase project

3. **Kiểm tra Firebase Options:**
   - File `lib/core/firebase/firebase_options.dart` phải có đầy đủ config
   - Project ID phải đúng

4. **Thử với Firebase project khác:**
   - Tạo Firebase project mới
   - Setup lại Firebase trong Flutter
   - Test lại

## Liên hệ hỗ trợ:

Nếu vẫn không giải quyết được, cung cấp:
- Platform (Android Emulator/Device/Version)
- Console logs đầy đủ
- Screenshot Firebase Console > Authentication > Sign-in method
- Đã thử các bước nào ở trên

