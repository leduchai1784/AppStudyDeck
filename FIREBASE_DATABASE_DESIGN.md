# Thiết kế Cơ sở Dữ liệu Firebase cho Flashcard Study Deck

## Tổng quan

Dự án Flashcard Study Deck sử dụng **Firebase Firestore** làm cơ sở dữ liệu NoSQL. Tài liệu này mô tả chi tiết cấu trúc database, các collections, documents, security rules và indexes cần thiết.

---

## 1. Cấu trúc Collections

### 1.1. Collection: `users`

**Mục đích**: Lưu trữ thông tin người dùng (cả admin và user thường)

**Document Structure**:
```json
{
  "userId": "string (document ID)",
  "email": "string",
  "name": "string",
  "role": "string (admin | user)",
  "isBlocked": "boolean",
  "avatarUrl": "string (optional)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "lastLoginAt": "timestamp (optional)",
  "provider": "string (email | google | facebook)",
  "providerId": "string (optional, ID từ provider như Google ID)",
  "photoUrl": "string (optional, URL ảnh đại diện từ Google)",
  "emailVerified": "boolean (trạng thái xác thực email)",
  "phoneNumber": "string (optional)",
  "locale": "string (optional, ngôn ngữ từ Google profile)",
  "statistics": {
    "totalDecksCreated": "number",
    "totalFlashcardsCreated": "number",
    "totalDecksStudied": "number",
    "totalFlashcardsStudied": "number",
    "totalStudyTime": "number (minutes)"
  }
}
```

**Indexes cần thiết**:
- `email` (ascending) - Unique
- `role` (ascending)
- `isBlocked` (ascending)
- `createdAt` (descending)

**Security Rules**:
- Read: User có thể đọc thông tin của chính mình, admin có thể đọc tất cả
- Write: User chỉ có thể cập nhật thông tin của chính mình, admin có thể cập nhật tất cả

---

### 1.2. Collection: `decks`

**Mục đích**: Lưu trữ thông tin các deck flashcard

**Document Structure**:
```json
{
  "deckId": "string (document ID)",
  "name": "string",
  "description": "string",
  "authorId": "string (reference to users)",
  "authorName": "string",
  "flashcardCount": "number",
  "viewCount": "number",
  "favoriteCount": "number",
  "isPublic": "boolean",
  "approvalStatus": "string (pending | approved | rejected)",
  "rejectionReason": "string (optional, khi rejected)",
  "tags": ["string"],
  "category": "string (optional)",
  "difficulty": "string (beginner | intermediate | advanced)",
  "language": "string (optional)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "approvedAt": "timestamp (optional)",
  "approvedBy": "string (admin userId, optional)"
}
```

**Indexes cần thiết**:
- `authorId` (ascending) + `createdAt` (descending)
- `isPublic` (ascending) + `approvalStatus` (ascending) + `createdAt` (descending)
- `approvalStatus` (ascending) + `createdAt` (descending)
- `favoriteCount` (descending)
- `viewCount` (descending)
- `tags` (array-contains)
- `category` (ascending)

**Security Rules**:
- Read: 
  - Public decks (approved): Tất cả user đã đăng nhập
  - Private decks: Chỉ author hoặc admin
  - Pending/rejected: Chỉ author và admin
- Write:
  - Create: User đã đăng nhập
  - Update: Chỉ author hoặc admin
  - Delete: Chỉ author hoặc admin
  - Approval: Chỉ admin

---

### 1.3. Collection: `flashcards`

**Mục đích**: Lưu trữ các flashcard thuộc về deck

**Document Structure**:
```json
{
  "flashcardId": "string (document ID)",
  "deckId": "string (reference to decks)",
  "front": "string",
  "back": "string",
  "tags": ["string"],
  "order": "number (thứ tự trong deck)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isActive": "boolean (true nếu flashcard còn hoạt động)"
}
```

**Indexes cần thiết**:
- `deckId` (ascending) + `order` (ascending)
- `deckId` (ascending) + `createdAt` (descending)
- `tags` (array-contains)

**Security Rules**:
- Read: User có thể đọc flashcard của deck public hoặc deck của chính họ
- Write:
  - Create: User có thể tạo flashcard cho deck của chính họ
  - Update: Chỉ author của deck hoặc admin
  - Delete: Chỉ author của deck hoặc admin

---

### 1.4. Collection: `user_deck_progress`

**Mục đích**: Theo dõi tiến độ học tập của user với từng deck

**Document Structure**:
```json
{
  "progressId": "string (document ID)",
  "userId": "string (reference to users)",
  "deckId": "string (reference to decks)",
  "totalFlashcards": "number",
  "studiedFlashcards": "number",
  "knownFlashcards": "number",
  "unknownFlashcards": "number",
  "currentStreak": "number (ngày học liên tiếp)",
  "lastStudyDate": "timestamp",
  "firstStudyDate": "timestamp",
  "totalStudyTime": "number (minutes)",
  "completionPercentage": "number (0-100)",
  "isCompleted": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Document ID Format**: `${userId}_${deckId}` (composite key)

**Indexes cần thiết**:
- `userId` (ascending) + `lastStudyDate` (descending)
- `userId` (ascending) + `completionPercentage` (descending)
- `deckId` (ascending) + `completionPercentage` (descending)

**Security Rules**:
- Read: User chỉ có thể đọc progress của chính mình, admin có thể đọc tất cả
- Write: User chỉ có thể tạo/cập nhật progress của chính mình

---

### 1.5. Collection: `user_flashcard_progress`

**Mục đích**: Theo dõi chi tiết tiến độ học của user với từng flashcard

**Document Structure**:
```json
{
  "progressId": "string (document ID)",
  "userId": "string (reference to users)",
  "flashcardId": "string (reference to flashcards)",
  "deckId": "string (reference to decks)",
  "isKnown": "boolean",
  "reviewCount": "number",
  "lastReviewDate": "timestamp",
  "nextReviewDate": "timestamp (Spaced Repetition)",
  "easeFactor": "number (2.5 default, cho Spaced Repetition)",
  "interval": "number (days, cho Spaced Repetition)",
  "correctStreak": "number",
  "incorrectStreak": "number",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Document ID Format**: `${userId}_${flashcardId}` (composite key)

**Indexes cần thiết**:
- `userId` (ascending) + `nextReviewDate` (ascending)
- `userId` (ascending) + `deckId` (ascending) + `isKnown` (ascending)
- `deckId` (ascending) + `isKnown` (ascending)

**Security Rules**:
- Read: User chỉ có thể đọc progress của chính mình
- Write: User chỉ có thể tạo/cập nhật progress của chính mình

---

### 1.6. Collection: `deck_favorites`

**Mục đích**: Lưu trữ các deck được user yêu thích (many-to-many relationship)

**Document Structure**:
```json
{
  "favoriteId": "string (document ID)",
  "userId": "string (reference to users)",
  "deckId": "string (reference to decks)",
  "createdAt": "timestamp"
}
```

**Document ID Format**: `${userId}_${deckId}` (composite key)

**Indexes cần thiết**:
- `userId` (ascending) + `createdAt` (descending)
- `deckId` (ascending) + `createdAt` (descending)

**Security Rules**:
- Read: User chỉ có thể đọc favorites của chính mình
- Write: User chỉ có thể tạo/xóa favorites của chính mình

---

### 1.7. Collection: `reports`

**Mục đích**: Lưu trữ các báo cáo từ user về nội dung không phù hợp

**Document Structure**:
```json
{
  "reportId": "string (document ID)",
  "reporterId": "string (reference to users)",
  "reporterName": "string",
  "reportType": "string (inappropriate_content | spam | copyright | other)",
  "content": "string",
  "targetType": "string (deck | flashcard | user)",
  "targetId": "string (ID của đối tượng bị báo cáo)",
  "status": "string (pending | resolved | rejected)",
  "adminNotes": "string (optional, ghi chú của admin)",
  "resolvedBy": "string (admin userId, optional)",
  "resolvedAt": "timestamp (optional)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes cần thiết**:
- `status` (ascending) + `createdAt` (descending)
- `targetType` (ascending) + `targetId` (ascending)
- `reporterId` (ascending) + `createdAt` (descending)

**Security Rules**:
- Read: User chỉ có thể đọc reports của chính mình, admin có thể đọc tất cả
- Write:
  - Create: User đã đăng nhập có thể tạo report
  - Update: Chỉ admin có thể cập nhật status và adminNotes

---

### 1.8. Collection: `study_sessions`

**Mục đích**: Lưu trữ lịch sử các phiên học tập (optional, cho analytics)

**Document Structure**:
```json
{
  "sessionId": "string (document ID)",
  "userId": "string (reference to users)",
  "deckId": "string (reference to decks)",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "duration": "number (minutes)",
  "flashcardsStudied": "number",
  "flashcardsKnown": "number",
  "flashcardsUnknown": "number",
  "createdAt": "timestamp"
}
```

**Indexes cần thiết**:
- `userId` (ascending) + `startTime` (descending)
- `deckId` (ascending) + `startTime` (descending)

**Security Rules**:
- Read: User chỉ có thể đọc sessions của chính mình, admin có thể đọc tất cả
- Write: User chỉ có thể tạo sessions của chính mình

---

## 2. Security Rules (Firestore Rules)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function isNotBlocked() {
      return isAuthenticated() && 
             !get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isBlocked;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isOwner(userId) || isAdmin();
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isOwner(userId) || isAdmin();
      allow delete: if isAdmin();
    }
    
    // Decks collection
    match /decks/{deckId} {
      allow read: if isAuthenticated() && isNotBlocked() && (
        resource.data.isPublic == true && resource.data.approvalStatus == 'approved' ||
        resource.data.authorId == request.auth.uid ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && isNotBlocked() && 
                     request.resource.data.authorId == request.auth.uid;
      
      allow update: if isAuthenticated() && isNotBlocked() && (
        resource.data.authorId == request.auth.uid ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        resource.data.authorId == request.auth.uid ||
        isAdmin()
      );
    }
    
    // Flashcards collection
    match /flashcards/{flashcardId} {
      allow read: if isAuthenticated() && isNotBlocked();
      
      allow create: if isAuthenticated() && isNotBlocked() && 
                     exists(/databases/$(database)/documents/decks/$(request.resource.data.deckId)) &&
                     get(/databases/$(database)/documents/decks/$(request.resource.data.deckId)).data.authorId == request.auth.uid;
      
      allow update: if isAuthenticated() && isNotBlocked() && (
        exists(/databases/$(database)/documents/decks/$(resource.data.deckId)) &&
        get(/databases/$(database)/documents/decks/$(resource.data.deckId)).data.authorId == request.auth.uid ||
        isAdmin()
      );
      
      allow delete: if isAuthenticated() && (
        exists(/databases/$(database)/documents/decks/$(resource.data.deckId)) &&
        get(/databases/$(database)/documents/decks/$(resource.data.deckId)).data.authorId == request.auth.uid ||
        isAdmin()
      );
    }
    
    // User deck progress
    match /user_deck_progress/{progressId} {
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isAdmin()
      );
      
      allow create, update: if isAuthenticated() && isNotBlocked() && 
                             request.resource.data.userId == request.auth.uid;
      
      allow delete: if isAdmin();
    }
    
    // User flashcard progress
    match /user_flashcard_progress/{progressId} {
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isAdmin()
      );
      
      allow create, update: if isAuthenticated() && isNotBlocked() && 
                             request.resource.data.userId == request.auth.uid;
      
      allow delete: if isAdmin();
    }
    
    // Deck favorites
    match /deck_favorites/{favoriteId} {
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isAdmin()
      );
      
      allow create, delete: if isAuthenticated() && isNotBlocked() && 
                             request.resource.data.userId == request.auth.uid;
    }
    
    // Reports
    match /reports/{reportId} {
      allow read: if isAuthenticated() && (
        resource.data.reporterId == request.auth.uid ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && isNotBlocked() && 
                     request.resource.data.reporterId == request.auth.uid;
      
      allow update: if isAdmin();
    }
    
    // Study sessions
    match /study_sessions/{sessionId} {
      allow read: if isAuthenticated() && (
        resource.data.userId == request.auth.uid ||
        isAdmin()
      );
      
      allow create: if isAuthenticated() && isNotBlocked() && 
                     request.resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 3. Firebase Authentication

### 3.1. Authentication Providers

- **Email/Password**: Đăng nhập và đăng ký cơ bản
- **Google Sign-In**: Đăng nhập bằng Google (tùy chọn)
- **Facebook Login**: Đăng nhập bằng Facebook (tùy chọn)

### 3.2. Custom Claims

Sử dụng Custom Claims để lưu trữ role của user:
```javascript
// Set custom claim khi user đăng ký/đăng nhập
admin.auth().setCustomUserClaims(uid, {
  role: 'user' // hoặc 'admin'
});
```

---

## 4. Cloud Functions (Optional)

### 4.1. Functions cần thiết

1. **onDeckCreate**: Tự động set `approvalStatus = 'pending'` khi tạo deck mới
2. **onDeckDelete**: Xóa tất cả flashcards khi deck bị xóa
3. **onFlashcardCreate**: Tự động tăng `flashcardCount` trong deck
4. **onFlashcardDelete**: Tự động giảm `flashcardCount` trong deck
5. **onFavoriteToggle**: Tự động cập nhật `favoriteCount` trong deck
6. **onDeckView**: Tự động tăng `viewCount` khi user xem deck
7. **updateUserStatistics**: Cập nhật thống kê user khi có thay đổi

---

## 5. Indexes cần tạo trong Firestore

### Composite Indexes:

1. **decks**:
   - `authorId` (Ascending) + `createdAt` (Descending)
   - `isPublic` (Ascending) + `approvalStatus` (Ascending) + `createdAt` (Descending)
   - `approvalStatus` (Ascending) + `createdAt` (Descending)
   - `favoriteCount` (Descending)
   - `viewCount` (Descending)

2. **flashcards**:
   - `deckId` (Ascending) + `order` (Ascending)
   - `deckId` (Ascending) + `createdAt` (Descending)

3. **user_deck_progress**:
   - `userId` (Ascending) + `lastStudyDate` (Descending)
   - `userId` (Ascending) + `completionPercentage` (Descending)

4. **user_flashcard_progress**:
   - `userId` (Ascending) + `nextReviewDate` (Ascending)
   - `userId` (Ascending) + `deckId` (Ascending) + `isKnown` (Ascending)

5. **deck_favorites**:
   - `userId` (Ascending) + `createdAt` (Descending)
   - `deckId` (Ascending) + `createdAt` (Descending)

6. **reports**:
   - `status` (Ascending) + `createdAt` (Descending)
   - `targetType` (Ascending) + `targetId` (Ascending)

---

## 6. Quan hệ giữa các Collections

```
users (1) ──< (many) decks
decks (1) ──< (many) flashcards
users (many) ──< (many) decks (through deck_favorites)
users (1) ──< (many) user_deck_progress
users (1) ──< (many) user_flashcard_progress
users (1) ──< (many) reports
users (1) ──< (many) study_sessions
```

---

## 7. Best Practices

### 7.1. Data Modeling

1. **Denormalization**: Lưu `authorName` trong deck để tránh join query
2. **Aggregated Data**: Lưu `flashcardCount`, `favoriteCount` trong deck để tránh count query
3. **Composite Keys**: Sử dụng composite keys cho many-to-many relationships (favorites, progress)

### 7.2. Query Optimization

1. **Pagination**: Luôn sử dụng `limit()` và `startAfter()` cho list queries
2. **Field Selection**: Chỉ select các fields cần thiết
3. **Index Usage**: Đảm bảo tất cả queries đều sử dụng indexes

### 7.3. Security

1. **Input Validation**: Validate tất cả input ở client và server
2. **Rate Limiting**: Implement rate limiting cho các operations quan trọng
3. **Data Validation**: Sử dụng Firestore Rules để validate data structure

---

## 8. Migration từ Mock API

### 8.1. Bước chuyển đổi

1. **Setup Firebase Project**: Tạo project mới trên Firebase Console
2. **Install Dependencies**: 
   ```yaml
   dependencies:
     firebase_core: ^2.24.2
     cloud_firestore: ^4.13.6
     firebase_auth: ^4.15.3
   ```
3. **Initialize Firebase**: Setup trong `main.dart`
4. **Create Repository Layer**: Tạo repository để abstract Firebase operations
5. **Migrate Data**: Script để migrate data từ mock sang Firestore
6. **Update Services**: Thay thế MockApi bằng FirestoreRepository

---

## 9. Monitoring & Analytics

### 9.1. Firestore Metrics cần theo dõi

- Read operations per day
- Write operations per day
- Storage size
- Index size
- Query performance

### 9.2. Custom Events (Firebase Analytics)

- `deck_viewed`
- `deck_created`
- `flashcard_studied`
- `deck_favorited`
- `study_session_completed`
- `report_submitted`

---

## 10. Backup & Recovery

1. **Scheduled Backups**: Sử dụng Firestore Export để backup định kỳ
2. **Point-in-time Recovery**: Enable point-in-time recovery cho production
3. **Data Retention**: Set retention policy cho các collections

---

## Kết luận

Thiết kế này cung cấp:
- ✅ Cấu trúc database rõ ràng và scalable
- ✅ Security rules đầy đủ
- ✅ Indexes tối ưu cho performance
- ✅ Support đầy đủ các tính năng của ứng dụng
- ✅ Dễ dàng mở rộng trong tương lai

**Lưu ý**: Khi implement, nên bắt đầu với các collections cơ bản (users, decks, flashcards) trước, sau đó mới thêm các collections phụ trợ (progress, favorites, reports).
