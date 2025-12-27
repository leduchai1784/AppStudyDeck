# Hướng dẫn Debug Đăng ký không lưu vào Firestore

## Vấn đề

Khi đăng ký, tài khoản Firebase Auth được tạo nhưng dữ liệu không được lưu vào Firestore collection `users`.

## Các nguyên nhân có thể

### 1. Security Rules chưa được deploy
**Kiểm tra:**
- Vào Firebase Console > Firestore Database > Rules
- Xem có rules cho collection `users` không
- Rules cần có: `allow create: if isAuthenticated() && request.auth.uid == userId;`

**Giải pháp:**
- Copy nội dung từ file `firestore.rules` trong project
- Paste vào Firebase Console và click "Publish"

### 2. User chưa được authenticated khi tạo document
**Kiểm tra:**
- Xem console logs khi đăng ký
- Tìm log: `Creating user document in Firestore for userId: ...`
- Nếu thấy: `❌ ERROR: User not authenticated` → User chưa được authenticate

**Giải pháp:**
- Code đã có delay 300ms để đợi Firebase Auth khởi tạo
- Nếu vẫn lỗi, có thể cần tăng delay hoặc kiểm tra Firebase Auth initialization

### 3. User ID mismatch
**Kiểm tra:**
- Xem console logs: `❌ ERROR: User ID mismatch`
- So sánh `currentUserId` và `userId` trong log

**Giải pháp:**
- Đảm bảo `userCredential.user!.uid` khớp với `_auth.currentUser?.uid`

### 4. Permission denied từ Security Rules
**Kiểm tra:**
- Xem console logs: `Firestore error: permission-denied`
- Hoặc error message: "Không có quyền truy cập Firestore"

**Giải pháp:**
- Kiểm tra Security Rules đã được deploy chưa
- Đảm bảo user đã authenticated (`request.auth != null`)
- Đảm bảo `request.auth.uid == userId`

### 5. Nested Map (statistics) không được xử lý đúng
**Kiểm tra:**
- Xem console logs: `Statistics: ...`
- Kiểm tra xem statistics có được convert đúng không

**Giải pháp:**
- Code đã có xử lý recursive cho nested Map
- Nếu vẫn lỗi, có thể cần kiểm tra type của statistics object

## Cách debug

### Bước 1: Kiểm tra Console Logs

Khi đăng ký, xem các logs sau trong console:

```
Creating user document in Firestore for userId: [userId]
User data to save: [data]
📝 Preparing user data for Firestore...
💾 Saving user document to Firestore: users/[userId]
Data keys: [keys]
✅ Document written to Firestore
✅ Document set successfully, verifying...
✅ Verified: User document exists in Firestore
```

Nếu thấy bất kỳ log `❌ ERROR` nào, đó là nguyên nhân.

### Bước 2: Kiểm tra Firebase Console

1. Vào Firebase Console > Firestore Database
2. Xem collection `users`
3. Kiểm tra xem có document với ID = userId của user vừa đăng ký không
4. Nếu không có → Document không được tạo (lỗi Security Rules hoặc code)
5. Nếu có nhưng thiếu fields → Lỗi trong quá trình prepare data

### Bước 3: Kiểm tra Security Rules

1. Vào Firebase Console > Firestore Database > Rules
2. Xem rules cho collection `users`:
   ```javascript
   match /users/{userId} {
     allow create: if isAuthenticated() && request.auth.uid == userId;
   }
   ```
3. Đảm bảo rules đã được deploy (có nút "Publish" màu xanh)

### Bước 4: Test với Firebase Console

1. Tạo user document thủ công trong Firebase Console
2. Nếu thành công → Vấn đề ở code
3. Nếu không thành công → Vấn đề ở Security Rules

## Cấu trúc dữ liệu đúng

Khi đăng ký, document trong Firestore phải có cấu trúc:

```json
{
  "email": "user@example.com",
  "name": "User Name",
  "role": "user",
  "isBlocked": false,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "statistics": {
    "totalDecksCreated": 0,
    "totalFlashcardsCreated": 0,
    "totalDecksStudied": 0,
    "totalFlashcardsStudied": 0,
    "totalStudyTime": 0
  }
}
```

**Lưu ý:** 
- Document ID = `userId` (Firebase Auth UID)
- Không có field `userId` trong document data (chỉ có trong document ID)

## So sánh với thiết kế

Theo `FIREBASE_DATABASE_DESIGN.md`:
- Document ID: `userId` ✅ (đúng)
- Fields: `email`, `name`, `role`, `isBlocked`, `createdAt`, `updatedAt`, `statistics` ✅ (đúng)
- Optional: `avatarUrl`, `lastLoginAt` (có thể thêm sau)

## Checklist để fix

- [ ] Security Rules đã được deploy lên Firebase Console
- [ ] User đã authenticated sau khi đăng ký (check console logs)
- [ ] User ID khớp giữa Auth và Firestore (check console logs)
- [ ] Nested Map `statistics` được xử lý đúng (check console logs)
- [ ] Không có lỗi permission-denied (check console logs)
- [ ] Document được verify sau khi tạo (check console logs)

## Test lại

1. Xóa app và cài lại (để clear cache)
2. Đăng ký tài khoản mới
3. Xem console logs chi tiết
4. Kiểm tra Firebase Console > Firestore > users collection
5. Nếu vẫn lỗi, gửi console logs để debug tiếp
