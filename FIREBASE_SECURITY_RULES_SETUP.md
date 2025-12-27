# Hướng dẫn Setup Firebase Security Rules

## Vấn đề

Khi test Firebase connection, bạn có thể gặp lỗi:
```
[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
```

Lỗi này xảy ra vì collection `test` chưa có Security Rules trong Firebase Console.

## Giải pháp

### Bước 1: Deploy Security Rules

1. **Mở Firebase Console**: https://console.firebase.google.com/
2. **Chọn project**: `appstudydeck-e036d`
3. **Vào Firestore Database** > **Rules**
4. **Copy nội dung từ file `firestore.rules`** trong project này
5. **Paste vào Firebase Console**
6. **Click "Publish"** để deploy rules

### Bước 2: Kiểm tra Rules đã được deploy

Sau khi deploy, rules cho collection `test` sẽ cho phép:
- **Read**: User đã authenticated
- **Write**: User đã authenticated

### Bước 3: Test lại

1. **Đảm bảo bạn đã đăng nhập** (authenticated) trong app
2. **Chạy lại test Firebase connection**
3. **Kiểm tra kết quả**

## Security Rules cho Test Collection

```javascript
// Test collection - Allow read/write for authenticated users (for testing)
match /test/{testId} {
  allow read, write: if isAuthenticated();
}
```

**Lưu ý**: 
- Collection `test` chỉ dùng cho mục đích testing
- Trong production, bạn có thể xóa hoặc restrict rules này
- Đảm bảo user đã authenticated trước khi test

## Alternative: Test với collection khác

Nếu không muốn thêm rules cho `test`, bạn có thể test với collection đã có rules như `users`:

```dart
// Test với users collection (cần authenticated và đúng userId)
await firestore.collection('users').doc(userId).get();
```

## Troubleshooting

### Lỗi vẫn còn sau khi deploy rules?

1. **Kiểm tra user đã authenticated chưa**:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('User: ${user?.uid}');
   ```

2. **Kiểm tra rules đã được deploy**:
   - Vào Firebase Console > Firestore > Rules
   - Xem rules có chứa `match /test/{testId}` không

3. **Clear app cache và restart**:
   - Đôi khi cần restart app để rules mới có hiệu lực

4. **Kiểm tra Firebase project ID**:
   - Đảm bảo app đang kết nối đúng Firebase project

## Security Best Practices

⚠️ **Cảnh báo**: Rules cho `test` collection chỉ nên dùng trong development/testing. 

Trong production:
- Xóa hoặc restrict rules cho `test` collection
- Chỉ cho phép admin access
- Hoặc xóa collection `test` hoàn toàn
