# 🔥 FIX LỖI PERMISSION-DENIED - HƯỚNG DẪN CHI TIẾT

## ✅ ĐÃ SỬA TRONG FILE `firestore.rules`:

1. **Đơn giản hóa function `isNotBlocked()`** - Tránh lỗi khi user document chưa tồn tại
2. **Bỏ `isNotBlocked()` khỏi rule đọc decks** - Tránh lỗi khi query với `.where()`
3. **Xử lý `approvalStatus` null** - Cho phép đọc deck khi `approvalStatus` là `null`

## 🚀 BƯỚC QUAN TRỌNG: DEPLOY RULES LÊN FIREBASE

### ⚠️ LƯU Ý QUAN TRỌNG:
**File `firestore.rules` trong project chỉ là file LOCAL!**
**Bạn PHẢI copy và paste vào Firebase Console để rules có hiệu lực!**

### 📋 CÁCH DEPLOY (Chọn 1 trong 2):

---

## CÁCH 1: Deploy qua Firebase Console (KHUYẾN NGHỊ - NHANH NHẤT)

### Bước 1: Mở Firebase Console
1. Vào trình duyệt: https://console.firebase.google.com/
2. Đăng nhập nếu chưa đăng nhập
3. Chọn project: **appstudydeck-e036d**

### Bước 2: Vào Firestore Rules
1. Click **Firestore Database** (menu bên trái)
2. Click tab **Rules** (ở trên cùng, bên cạnh tab "Data")

### Bước 3: Copy Rules từ file local
1. Mở file `firestore.rules` trong project của bạn
2. **Chọn TẤT CẢ** (Ctrl+A hoặc Cmd+A)
3. **Copy** (Ctrl+C hoặc Cmd+C)

### Bước 4: Paste vào Firebase Console
1. **Xóa TẤT CẢ** nội dung cũ trong Firebase Console (Ctrl+A, Delete)
2. **Paste** nội dung mới (Ctrl+V hoặc Cmd+V)
3. Click nút **Publish** (màu xanh, góc trên bên phải)

### Bước 5: Kiểm tra
- Đợi vài giây (thường 2-5 giây)
- Bạn sẽ thấy thông báo "Rules published successfully"
- **Chạy lại app** - Lỗi sẽ hết!

---

## CÁCH 2: Deploy qua Firebase CLI

### Bước 1: Cài đặt Firebase CLI (nếu chưa có)
```bash
npm install -g firebase-tools
```

### Bước 2: Đăng nhập Firebase
```bash
firebase login
```

### Bước 3: Set project
```bash
firebase use appstudydeck-e036d
```

### Bước 4: Deploy rules
```bash
firebase deploy --only firestore:rules
```

---

## 🔍 KIỂM TRA SAU KHI DEPLOY

### 1. Kiểm tra trong Firebase Console
- Vào Firestore Database → Rules
- Xem rules mới đã được lưu chưa
- Kiểm tra không có lỗi syntax (nếu có lỗi sẽ hiển thị màu đỏ)

### 2. Kiểm tra trong app
- Chạy lại app
- Kiểm tra console logs:
  ```
  ✅ Nếu thành công: "✅ Public decks query succeeded"
  ❌ Nếu vẫn lỗi: "❌ Error loading decks: permission-denied"
  ```

---

## 🐛 NẾU VẪN CÒN LỖI

### Kiểm tra 1: User đã đăng nhập chưa?
```dart
// Thêm vào code để debug
print('User logged in: ${AuthService.isLoggedIn}');
print('User UID: ${AuthService.currentUserId}');
```

**Nếu `isLoggedIn = false` hoặc `currentUserId = null`:**
- ❌ User chưa đăng nhập
- ✅ Phải đăng nhập trước khi query decks

### Kiểm tra 2: User document đã tồn tại chưa?
- Vào Firebase Console → Firestore Database → Data
- Kiểm tra collection `users` có document với ID = user UID không
- Nếu chưa có, user cần đăng ký/đăng nhập để tạo document

### Kiểm tra 3: Deck có field đúng không?
- Vào Firestore Database → Data → collection `decks`
- Kiểm tra các document có field:
  - `isPublic` (boolean)
  - `approvalStatus` (string: 'pending', 'approved', 'rejected', hoặc null)
  - `authorId` (string)

---

## 📝 TÓM TẮT THAY ĐỔI TRONG RULES

### Trước (Có lỗi):
```javascript
allow read: if isAuthenticated() && isNotBlocked() && (...)
// isNotBlocked() gây lỗi khi query vì check user document
```

### Sau (Đã sửa):
```javascript
allow read: if isAuthenticated() && (...)
// Bỏ isNotBlocked() khỏi rule đọc để tránh lỗi khi query
// Vẫn giữ isNotBlocked() cho create/update operations
```

---

## ✅ KẾT QUẢ MONG ĐỢI

Sau khi deploy rules:
- ✅ User đã đăng nhập có thể đọc decks công khai
- ✅ User có thể đọc decks của chính mình
- ✅ Admin có thể đọc tất cả decks
- ❌ Không còn lỗi permission-denied khi query decks

---

## 🆘 CẦN HỖ TRỢ?

Nếu vẫn gặp lỗi sau khi deploy:
1. Kiểm tra lại console logs để xem lỗi chi tiết
2. Kiểm tra Firebase Console → Rules xem có lỗi syntax không
3. Đảm bảo user đã đăng nhập trước khi query

