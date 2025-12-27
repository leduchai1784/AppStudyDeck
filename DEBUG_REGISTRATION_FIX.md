# Hướng dẫn Debug Lỗi Đăng Ký

## Các bước kiểm tra khi gặp lỗi "Lỗi kết nối mạng"

### 1. Kiểm tra Console Logs

Khi đăng ký, xem console logs để tìm lỗi cụ thể:

```
🔄 Starting registration process...
📧 Email: ...
👤 Name: ...
📝 Step 1: Creating user in Firebase Auth...
✅ Step 1 completed: User created in Firebase Auth with ID: ...
✅ Step 2 completed: User is authenticated
📝 Step 3: Preparing user data for Firestore...
💾 Step 4: Creating user document in Firestore...
```

Nếu thấy lỗi `❌`, đó là nguyên nhân.

### 2. Các lỗi thường gặp và cách sửa

#### Lỗi: `PERMISSION_DENIED`
**Nguyên nhân**: Security Rules không cho phép user tạo document

**Cách sửa**:
1. Vào Firebase Console > Firestore Database > Rules
2. Đảm bảo có rule sau:
```javascript
match /users/{userId} {
  allow create: if isAuthenticated() && 
                 request.auth.uid == userId &&
                 request.resource.data.keys().hasAll(['email', 'name', 'role', 'isBlocked', 'statistics']);
}
```
3. Click "Publish" để deploy rules

#### Lỗi: `UNAVAILABLE`
**Nguyên nhân**: Firestore không khả dụng hoặc không có internet

**Cách sửa**:
1. Kiểm tra kết nối internet
2. Kiểm tra Firebase Console xem Firestore có đang hoạt động không
3. Thử lại sau vài phút

#### Lỗi: `User not authenticated`
**Nguyên nhân**: User chưa được authenticate sau khi tạo trong Firebase Auth

**Cách sửa**:
1. Kiểm tra Firebase Auth đã được enable chưa
2. Kiểm tra email/password authentication method đã được enable trong Firebase Console

#### Lỗi: `Document was not created`
**Nguyên nhân**: Document không được tạo sau khi gọi set()

**Cách sửa**:
1. Kiểm tra Security Rules (xem trên)
2. Kiểm tra internet connection
3. Xem console logs để tìm lỗi cụ thể

### 3. Kiểm tra Firebase Configuration

1. **Kiểm tra Firebase đã được initialize chưa**:
   - Xem `lib/main.dart` có gọi `FirebaseService.initialize()` chưa
   - Xem console có log "Firebase initialized" không

2. **Kiểm tra Firebase Options**:
   - File `lib/core/firebase/firebase_options.dart` phải có đầy đủ config
   - File `android/app/google-services.json` phải tồn tại (cho Android)
   - File `ios/Runner/GoogleService-Info.plist` phải tồn tại (cho iOS)

3. **Kiểm tra Security Rules đã được deploy**:
   - Vào Firebase Console > Firestore Database > Rules
   - Xem có nút "Publish" màu xanh không (nếu có nghĩa là chưa deploy)
   - Copy nội dung từ file `firestore.rules` và paste vào, sau đó click "Publish"

### 4. Test thủ công trong Firebase Console

1. Vào Firebase Console > Firestore Database
2. Thử tạo document thủ công trong collection `users`:
   - Document ID: một UID bất kỳ
   - Fields:
     - email: "test@example.com"
     - name: "Test User"
     - role: "user"
     - isBlocked: false
     - statistics: {object với các fields}
     - createdAt: timestamp
     - updatedAt: timestamp

3. Nếu không tạo được → Vấn đề ở Security Rules
4. Nếu tạo được → Vấn đề ở code

### 5. Kiểm tra Logs chi tiết

Trong code đã có logging chi tiết. Xem console để tìm:
- `❌ ERROR`: Lỗi cụ thể
- `❌ FirebaseException`: Lỗi từ Firebase
- `❌ Stack trace`: Stack trace để debug

### 6. Các bước debug nhanh

1. **Kiểm tra internet**: Mở browser, vào google.com
2. **Kiểm tra Firebase Console**: Vào console.firebase.google.com, xem project có hoạt động không
3. **Kiểm tra Security Rules**: Xem rules đã được deploy chưa
4. **Xem console logs**: Tìm lỗi cụ thể trong logs
5. **Test với user khác**: Thử đăng ký với email khác

### 7. Liên hệ hỗ trợ

Nếu vẫn không giải quyết được, cung cấp:
- Console logs đầy đủ (copy từ đầu đến cuối)
- Screenshot Firebase Console > Firestore Database > Rules
- Platform đang test (Android/iOS/Web)
- Error message chính xác

