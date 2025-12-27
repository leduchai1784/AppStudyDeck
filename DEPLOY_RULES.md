# Hướng dẫn Deploy Firestore Security Rules

## Cách 1: Deploy qua Firebase Console (Khuyến nghị - Nhanh nhất)

1. Mở trình duyệt và vào [Firebase Console](https://console.firebase.google.com/)
2. Chọn project: **appstudydeck-e036d**
3. Vào **Firestore Database** → tab **Rules**
4. Copy **TOÀN BỘ** nội dung từ file `firestore.rules` trong project này
5. Paste vào Firebase Console
6. Nhấn nút **Publish** (màu xanh ở góc trên bên phải)
7. Đợi vài giây để rules được deploy

## Cách 2: Deploy qua Firebase CLI

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

## Kiểm tra sau khi deploy

1. Vào Firebase Console → Firestore Database → Rules
2. Kiểm tra xem rules mới đã được áp dụng chưa
3. Chạy lại app và kiểm tra xem lỗi permission-denied đã hết chưa

## Lưu ý

- Rules sẽ có hiệu lực ngay sau khi deploy (thường trong vòng vài giây)
- Nếu vẫn còn lỗi, kiểm tra lại:
  - User đã đăng nhập chưa?
  - User document đã được tạo trong Firestore chưa?
  - Deck có field `isPublic` và `approvalStatus` chưa?

