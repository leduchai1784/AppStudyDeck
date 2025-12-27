# 🔥 QUICK FIX: Lỗi Permission-Denied

## ⚠️ Nguyên nhân chính:
**Rules chưa được deploy lên Firebase Console!**

## ✅ Giải pháp NGAY LẬP TỨC:

### Bước 1: Mở Firebase Console
1. Vào: https://console.firebase.google.com/
2. Chọn project: **appstudydeck-e036d**

### Bước 2: Vào Firestore Rules
1. Click **Firestore Database** (bên trái)
2. Click tab **Rules** (ở trên)

### Bước 3: Copy và Paste Rules
1. Mở file `firestore.rules` trong project
2. **Copy TOÀN BỘ** nội dung (Ctrl+A, Ctrl+C)
3. **Paste** vào Firebase Console (Ctrl+V)
4. Click nút **Publish** (màu xanh, góc trên bên phải)

### Bước 4: Kiểm tra
- Đợi vài giây để rules được deploy
- Chạy lại app
- Lỗi sẽ hết!

---

## 🔍 Nếu vẫn còn lỗi, kiểm tra:

### 1. User đã đăng nhập chưa?
```dart
// Kiểm tra trong code
if (AuthService.isLoggedIn) {
  print('✅ User đã đăng nhập');
} else {
  print('❌ User chưa đăng nhập');
}
```

### 2. User document đã tồn tại trong Firestore chưa?
- Vào Firebase Console → Firestore Database → Data
- Kiểm tra collection `users` có document với ID = user UID không

### 3. Deck có field `isPublic` và `approvalStatus` không?
- Vào Firestore Database → Data → collection `decks`
- Kiểm tra các document có field:
  - `isPublic` (boolean)
  - `approvalStatus` (string: 'pending', 'approved', 'rejected')

---

## 📝 Lưu ý quan trọng:

1. **Rules phải được deploy** - Chỉnh sửa file local KHÔNG có tác dụng!
2. **Rules có hiệu lực ngay** sau khi deploy (vài giây)
3. **Kiểm tra console logs** để xem lỗi chi tiết

---

## 🚀 Deploy bằng CLI (nếu có Firebase CLI):

```bash
firebase login
firebase use appstudydeck-e036d
firebase deploy --only firestore:rules
```

