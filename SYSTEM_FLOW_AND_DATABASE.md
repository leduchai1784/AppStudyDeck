# Luồng Hoạt Động và Cơ Sở Dữ Liệu - Flashcard Study Deck

## 📋 Mục lục
1. [Tổng quan hệ thống](#tổng-quan-hệ-thống)
2. [Luồng hoạt động chính](#luồng-hoạt-động-chính)
3. [Cơ sở dữ liệu](#cơ-sở-dữ-liệu)
4. [Sơ đồ luồng](#sơ-đồ-luồng)

---

## 🎯 Tổng quan hệ thống

**Flashcard Study Deck** là ứng dụng học tập bằng flashcard được xây dựng trên Flutter với backend Firebase. Hệ thống hỗ trợ:
- Quản lý deck và flashcard
- Học tập và theo dõi tiến độ
- Quản trị viên quản lý nội dung và người dùng
- Xác thực đa phương thức (Email/Password, Google Sign-In)

---

## 🔄 Luồng hoạt động chính

### 1. Luồng khởi động ứng dụng

```
App Start
  ↓
Initialize Firebase
  ↓
Initialize AuthService
  ↓
Check Auth State
  ↓
┌─────────────────┬─────────────────┐
│   Đã đăng nhập  │  Chưa đăng nhập  │
└────────┬────────┴────────┬────────┘
         │                  │
    Check User Data    Login Screen
         │
    ┌────┴────┐
    │ Blocked?│
    └────┬────┘
         │
    ┌────┴────┐
    │   Yes   │  No
    └────┬────┘  └──→ Home Screen
         │
    Logout → Login Screen
```

**Chi tiết:**
1. **Khởi tạo Firebase**: `FirebaseService.initialize()`
2. **Khởi tạo Auth Service**: `AuthService.initialize()`
   - Load user data nếu đã đăng nhập
   - Lắng nghe thay đổi trạng thái auth
3. **Kiểm tra trạng thái**:
   - Nếu đã đăng nhập → Kiểm tra user có bị khóa không
   - Nếu bị khóa → Logout và chuyển đến Login
   - Nếu không bị khóa → Chuyển đến Home Screen
   - Nếu chưa đăng nhập → Chuyển đến Login Screen

---

### 2. Luồng xác thực (Authentication)

#### 2.1. Đăng ký (Register)

```
Register Screen
  ↓
Nhập: Email, Password, Name
  ↓
Validate Input
  ↓
Create User (Firebase Auth)
  ↓
Create User Document (Firestore)
  ├─ userId (document ID)
  ├─ email
  ├─ name
  ├─ role: 'user'
  ├─ isBlocked: false
  ├─ provider: 'email'
  └─ statistics: {...}
  ↓
Load User Data
  ↓
Redirect → Home Screen
```

**Các bước chi tiết:**
1. User nhập thông tin đăng ký
2. Validate email và password
3. Tạo tài khoản trong Firebase Auth
4. Tạo document trong Firestore collection `users`
5. Load user data vào memory
6. Chuyển đến Home Screen

#### 2.2. Đăng nhập (Login)

**Email/Password:**
```
Login Screen
  ↓
Nhập: Email, Password
  ↓
Firebase Auth Sign In
  ↓
Load User Data từ Firestore
  ↓
Check isBlocked
  ├─ Yes → Logout + Show Error
  └─ No → Update lastLoginAt → Home Screen
```

**Google Sign-In:**
```
Login Screen → Google Sign-In Button
  ↓
Google Sign-In Flow
  ↓
Get Google Credentials
  ↓
Firebase Auth Sign In với Credential
  ↓
Check User Document exists
  ├─ No → Create User Document với Google info
  └─ Yes → Load User Data
  ↓
Check isBlocked
  ├─ Yes → Logout + Show Error
  └─ No → Update lastLoginAt → Home Screen
```

#### 2.3. Quên mật khẩu

```
Forgot Password Screen
  ↓
Nhập Email
  ↓
Send Password Reset Email (Firebase Auth)
  ↓
Show Success Message
```

---

### 3. Luồng quản lý Deck

#### 3.1. Tạo Deck mới

```
Home Screen → Tạo Deck mới
  ↓
Show Dialog: Nhập Name, Description, Privacy
  ↓
Create Deck Document (Firestore)
  ├─ deckId (auto-generated)
  ├─ name
  ├─ description
  ├─ authorId (current user)
  ├─ authorName
  ├─ isPublic (true/false)
  ├─ flashcardCount: 0
  ├─ viewCount: 0
  ├─ favoriteCount: 0
  ├─ status: 'public' hoặc 'private'
  ├─ createdAt
  └─ updatedAt
  ↓
Redirect → Deck Detail Screen
```

#### 3.2. Xem danh sách Deck

```
Deck List Screen
  ↓
Load Decks từ Firestore
  ├─ Public decks (isPublic = true)
  └─ User's own decks (authorId = userId)
  ↓
Display List với:
  ├─ Deck name
  ├─ Description
  ├─ Flashcard count
  ├─ Author name
  ├─ Favorite status
  └─ View count
  ↓
User có thể:
  ├─ Tap deck → Deck Detail
  ├─ Favorite/Unfavorite
  └─ Search/Filter
```

#### 3.3. Xem chi tiết Deck

```
Deck Detail Screen
  ↓
Load Deck Info
  ↓
Load Flashcards của Deck
  ↓
Display:
  ├─ Deck info
  ├─ List flashcards
  └─ Actions:
      ├─ Add Flashcard
      ├─ Bulk Add (CSV)
      ├─ Edit Deck
      ├─ Delete Deck
      ├─ Study Deck
      └─ Favorite/Unfavorite
```

---

### 4. Luồng quản lý Flashcard

#### 4.1. Thêm Flashcard đơn lẻ

```
Deck Detail → Add Flashcard
  ↓
Flashcard Edit Screen
  ↓
Nhập: Front, Back, Tags (optional)
  ↓
Create Flashcard Document (Firestore)
  ├─ flashcardId (auto-generated)
  ├─ deckId
  ├─ front
  ├─ back
  ├─ tags: []
  ├─ order: auto-increment
  ├─ createdAt
  └─ updatedAt
  ↓
Update Deck flashcardCount (+1)
  ↓
Redirect → Deck Detail (refresh)
```

#### 4.2. Thêm Flashcard hàng loạt (CSV)

```
Deck Detail → Bulk Add
  ↓
File Picker → Chọn CSV file
  ↓
Parse CSV
  ├─ Format: front,back hoặc front,back,tags
  └─ Validate data
  ↓
Batch Create Flashcards
  ├─ Create multiple flashcard documents
  └─ Update deck flashcardCount
  ↓
Show Success/Error
  ↓
Redirect → Deck Detail (refresh)
```

#### 4.3. Sửa/Xóa Flashcard

```
Deck Detail → Tap Flashcard
  ↓
Flashcard Edit Screen
  ↓
Edit: Front, Back, Tags
  ↓
Update Flashcard Document
  ↓
Hoặc Delete Flashcard
  ├─ Delete document
  └─ Update deck flashcardCount (-1)
```

---

### 5. Luồng học tập (Study)

```
Home/Deck List → Study Deck
  ↓
Study Screen
  ↓
Load Flashcards từ Deck
  ↓
Initialize Study Session
  ├─ sessionStartTime = now()
  ├─ flashcardsStudied = 0
  ├─ flashcardsKnown = 0
  └─ flashcardsUnknown = 0
  ↓
Display Flashcard (Front)
  ↓
User Actions:
  ├─ Flip Card → Show Back
  ├─ Mark as Known
  │   ├─ Update user_flashcard_progress
  │   │   ├─ isKnown = true
  │   │   ├─ reviewCount++
  │   │   ├─ lastReviewDate = now()
  │   │   └─ correctStreak++
  │   └─ flashcardsKnown++
  │
  ├─ Mark as Unknown
  │   ├─ Update user_flashcard_progress
  │   │   ├─ isKnown = false
  │   │   ├─ reviewCount++
  │   │   ├─ lastReviewDate = now()
  │   │   └─ incorrectStreak++
  │   └─ flashcardsUnknown++
  │
  └─ Next/Previous Card
  ↓
Continue until all cards studied
  ↓
Save Study Session
  ├─ Create study_sessions document
  │   ├─ userId
  │   ├─ deckId
  │   ├─ startTime
  │   ├─ endTime
  │   ├─ duration (minutes)
  │   ├─ flashcardsStudied
  │   ├─ flashcardsKnown
  │   └─ flashcardsUnknown
  └─ Update user_deck_progress
      ├─ studiedFlashcards++
      ├─ knownFlashcards++
      ├─ unknownFlashcards++
      ├─ lastStudyDate = now()
      └─ completionPercentage = calculate()
  ↓
Show Completion Dialog
  ↓
Update Statistics
  ├─ Update user statistics
  └─ Update deck viewCount
```

**Chi tiết Study Flow:**
1. Load tất cả flashcards của deck
2. Hiển thị từng flashcard (front trước)
3. User có thể flip để xem back
4. User đánh dấu Known/Unknown
5. Lưu progress vào `user_flashcard_progress`
6. Cập nhật `user_deck_progress`
7. Khi hoàn thành → Lưu `study_sessions`
8. Cập nhật thống kê user và deck

---

### 6. Luồng Admin

#### 6.1. Admin Home

```
Admin Home Screen
  ↓
Load Statistics
  ├─ Total Users (count users collection)
  ├─ Total Decks (count decks collection)
  ├─ Total Flashcards (count flashcards collection)
  └─ Pending Reports (count reports where status = 'pending')
  ↓
Display Dashboard
  ↓
Quick Actions:
  ├─ Manage Users
  ├─ Manage Decks
  ├─ Manage Reports
  └─ View Dashboard
```

#### 6.2. Quản lý Users

```
Manage Users Screen
  ↓
Load All Users từ Firestore
  ↓
Display List với:
  ├─ Name, Email
  ├─ Role (admin/user)
  ├─ Status (blocked/active)
  └─ Statistics
  ↓
Actions:
  ├─ Search Users
  ├─ Filter (All/Admin/User/Blocked)
  ├─ View Detail
  │   ├─ Edit Info
  │   ├─ Block/Unblock
  │   ├─ Reset Password
  │   └─ View Statistics
  └─ Delete User
```

#### 6.3. Quản lý Decks (Public Decks)

```
Manage Decks Screen
  ↓
Load Public Decks từ Firestore
  ├─ Query: isPublic = true
  └─ Order by createdAt DESC
  ↓
Display List với:
  ├─ Deck name
  ├─ Author name
  ├─ Flashcard count
  └─ View count
  ↓
Actions:
  ├─ Search (by name, description, author)
  ├─ View Detail
  │   ├─ Review Deck
  │   ├─ View Flashcards
  │   ├─ Hide Deck (if inappropriate)
  │   └─ Delete Deck
  └─ Filter by User
```

#### 6.4. Quản lý Reports

```
Manage Reports Screen
  ↓
Load Reports từ Firestore
  ├─ Filter: status = 'pending'
  └─ Order by createdAt DESC
  ↓
Display List với:
  ├─ Report type
  ├─ Reporter name
  ├─ Target (deck/flashcard/user)
  ├─ Content
  └─ Status
  ↓
Actions:
  ├─ View Detail
  │   ├─ View Reported Content
  │   ├─ Resolve Report
  │   │   ├─ Update status = 'resolved'
  │   │   ├─ resolvedBy = adminId
  │   │   └─ resolvedAt = now()
  │   ├─ Reject Report
  │   │   └─ Update status = 'rejected'
  │   └─ Delete Report
  └─ Filter (Pending/Resolved/Rejected)
```

---

### 7. Luồng tìm kiếm

```
Search Screen
  ↓
User nhập keyword
  ↓
Search trong Firestore
  ├─ Search Decks:
  │   ├─ name contains keyword
  │   ├─ description contains keyword
  │   └─ tags array-contains keyword
  └─ Search Flashcards:
      ├─ front contains keyword
      ├─ back contains keyword
      └─ tags array-contains keyword
  ↓
Display Results
  ├─ Group by Deck
  └─ Show matching flashcards
  ↓
User có thể:
  ├─ Tap Deck → Deck Detail
  └─ Tap Flashcard → Flashcard Edit
```

---

### 8. Luồng thống kê

```
Statistics Screen
  ↓
Load User Statistics
  ├─ Total Decks Created
  ├─ Total Flashcards Created
  ├─ Total Decks Studied
  ├─ Total Flashcards Studied
  ├─ Total Study Time
  ├─ User Score
  └─ Today's Progress
  ↓
Load Deck Progress
  ├─ List decks với progress
  ├─ Completion percentage
  ├─ Known/Unknown flashcards
  └─ Last study date
  ↓
Display Charts/Graphs
  ├─ Study time chart
  ├─ Progress by deck
  └─ Daily activity
```

---

## 🗄️ Cơ sở dữ liệu

### Tổng quan

Hệ thống sử dụng **Firebase Firestore** (NoSQL) với các collections chính:

### 1. Collection: `users`

**Mục đích**: Lưu trữ thông tin người dùng

**Cấu trúc Document:**
```json
{
  "userId": "string (document ID)",
  "email": "string",
  "name": "string",
  "role": "admin | user",
  "isBlocked": "boolean",
  "avatarUrl": "string (optional)",
  "photoUrl": "string (optional)",
  "provider": "email | google",
  "providerId": "string (optional)",
  "emailVerified": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "lastLoginAt": "timestamp (optional)",
  "statistics": {
    "totalDecksCreated": "number",
    "totalFlashcardsCreated": "number",
    "totalDecksStudied": "number",
    "totalFlashcardsStudied": "number",
    "totalStudyTime": "number (minutes)"
  }
}
```

**Indexes:**
- `email` (ascending) - Unique
- `role` (ascending)
- `isBlocked` (ascending)
- `createdAt` (descending)

---

### 2. Collection: `decks`

**Mục đích**: Lưu trữ thông tin các deck flashcard

**Cấu trúc Document:**
```json
{
  "deckId": "string (document ID)",
  "name": "string",
  "description": "string",
  "authorId": "string",
  "authorName": "string",
  "flashcardCount": "number",
  "viewCount": "number",
  "favoriteCount": "number",
  "isPublic": "boolean",
  "status": "public | private | reported | hidden",
  "approvalStatus": "pending | approved | rejected (legacy)",
  "tags": ["string"],
  "category": "string (optional)",
  "difficulty": "beginner | intermediate | advanced",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `authorId` (ascending) + `createdAt` (descending)
- `isPublic` (ascending) + `status` (ascending) + `createdAt` (descending)
- `favoriteCount` (descending)
- `viewCount` (descending)
- `tags` (array-contains)

---

### 3. Collection: `flashcards`

**Mục đích**: Lưu trữ các flashcard thuộc về deck

**Cấu trúc Document:**
```json
{
  "flashcardId": "string (document ID)",
  "deckId": "string",
  "front": "string",
  "back": "string",
  "tags": ["string"],
  "order": "number",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "isActive": "boolean"
}
```

**Indexes:**
- `deckId` (ascending) + `order` (ascending)
- `deckId` (ascending) + `createdAt` (descending)
- `tags` (array-contains)

---

### 4. Collection: `user_deck_progress`

**Mục đích**: Theo dõi tiến độ học tập của user với từng deck

**Cấu trúc Document:**
```json
{
  "progressId": "string (document ID = userId_deckId)",
  "userId": "string",
  "deckId": "string",
  "totalFlashcards": "number",
  "studiedFlashcards": "number",
  "knownFlashcards": "number",
  "unknownFlashcards": "number",
  "currentStreak": "number",
  "lastStudyDate": "timestamp",
  "firstStudyDate": "timestamp",
  "totalStudyTime": "number (minutes)",
  "completionPercentage": "number (0-100)",
  "isCompleted": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `userId` (ascending) + `lastStudyDate` (descending)
- `userId` (ascending) + `completionPercentage` (descending)
- `deckId` (ascending) + `completionPercentage` (descending)

---

### 5. Collection: `user_flashcard_progress`

**Mục đích**: Theo dõi chi tiết tiến độ học của user với từng flashcard

**Cấu trúc Document:**
```json
{
  "progressId": "string (document ID = userId_flashcardId)",
  "userId": "string",
  "flashcardId": "string",
  "deckId": "string",
  "isKnown": "boolean",
  "reviewCount": "number",
  "lastReviewDate": "timestamp",
  "nextReviewDate": "timestamp (Spaced Repetition)",
  "easeFactor": "number (default: 2.5)",
  "interval": "number (days)",
  "correctStreak": "number",
  "incorrectStreak": "number",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `userId` (ascending) + `nextReviewDate` (ascending)
- `userId` (ascending) + `deckId` (ascending) + `isKnown` (ascending)
- `deckId` (ascending) + `isKnown` (ascending)

---

### 6. Collection: `deck_favorites`

**Mục đích**: Lưu trữ các deck được user yêu thích

**Cấu trúc Document:**
```json
{
  "favoriteId": "string (document ID = userId_deckId)",
  "userId": "string",
  "deckId": "string",
  "createdAt": "timestamp"
}
```

**Indexes:**
- `userId` (ascending) + `createdAt` (descending)
- `deckId` (ascending) + `createdAt` (descending)

---

### 7. Collection: `reports`

**Mục đích**: Lưu trữ các báo cáo từ user về nội dung không phù hợp

**Cấu trúc Document:**
```json
{
  "reportId": "string (document ID)",
  "reporterId": "string",
  "reporterName": "string",
  "reportType": "inappropriate_content | spam | copyright | other",
  "content": "string",
  "targetType": "deck | flashcard | user",
  "targetId": "string",
  "status": "pending | resolved | rejected",
  "adminNotes": "string (optional)",
  "resolvedBy": "string (admin userId, optional)",
  "resolvedAt": "timestamp (optional)",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

**Indexes:**
- `status` (ascending) + `createdAt` (descending)
- `targetType` (ascending) + `targetId` (ascending)
- `reporterId` (ascending) + `createdAt` (descending)

---

### 8. Collection: `study_sessions`

**Mục đích**: Lưu trữ lịch sử các phiên học tập

**Cấu trúc Document:**
```json
{
  "sessionId": "string (document ID)",
  "userId": "string",
  "deckId": "string",
  "startTime": "timestamp",
  "endTime": "timestamp",
  "duration": "number (minutes)",
  "flashcardsStudied": "number",
  "flashcardsKnown": "number",
  "flashcardsUnknown": "number",
  "createdAt": "timestamp"
}
```

**Indexes:**
- `userId` (ascending) + `startTime` (descending)
- `deckId` (ascending) + `startTime` (descending)

---

### Quan hệ giữa các Collections

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

## 📊 Sơ đồ luồng

### Sơ đồ tổng quan hệ thống

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER APP                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Presentation │  │   Domain     │  │     Data     │ │
│  │   (UI)       │→ │  (Business)  │→ │ (Repository) │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                    FIREBASE                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Auth       │  │  Firestore   │  │   Storage    │ │
│  │ (Users)      │  │  (Database)  │  │   (Files)     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Luồng xác thực

```
┌─────────────┐
│   App Start │
└──────┬──────┘
       │
       ↓
┌──────────────┐      ┌──────────────┐
│  Firebase    │      │   Auth       │
│ Initialize   │─────→│  Service     │
└──────────────┘      └──────┬───────┘
                             │
                    ┌────────┴────────┐
                    │  Check Auth     │
                    └────────┬────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
         ┌──────┴──────┐          ┌───────┴──────┐
         │ Logged In   │          │ Not Logged  │
         └──────┬──────┘          └──────┬───────┘
                │                       │
         ┌──────┴──────┐                │
         │ Check Block │                │
         └──────┬──────┘                │
                │                       │
        ┌───────┴───────┐               │
        │               │               │
    ┌───┴───┐      ┌────┴────┐          │
    │Blocked│      │ Active  │          │
    └───┬───┘      └────┬────┘          │
        │              │               │
        │         ┌────┴────┐          │
        │         │  Home   │          │
        │         └─────────┘          │
        │                              │
        └──────────→ Login Screen ←────┘
```

### Luồng học tập

```
┌──────────────┐
│ Select Deck  │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│ Load Cards   │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│ Show Card    │
│   (Front)    │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│  User Action │
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
Flip    Mark
   │       │
   │   ┌───┴───┐
   │   │       │
   │ Known  Unknown
   │   │       │
   │   └───┬───┘
   │       │
   └───┬───┘
       │
       ↓
┌──────────────┐
│ Save Progress│
│  - Flashcard │
│  - Deck      │
│  - Session   │
└──────┬───────┘
       │
       ↓
┌──────────────┐
│ Next Card?   │
└──────┬───────┘
       │
   ┌───┴───┐
   │       │
  Yes      No
   │       │
   │   ┌───┴───┐
   │   │ Show  │
   │   │Complete│
   │   └───────┘
   │
   └───→ Loop
```

---

## 🔐 Security Rules

### Nguyên tắc chung:
1. **Authentication Required**: Tất cả operations đều yêu cầu đăng nhập
2. **User Isolation**: User chỉ có thể đọc/ghi dữ liệu của chính mình
3. **Admin Privileges**: Admin có thể đọc/ghi tất cả
4. **Blocked Users**: User bị khóa không thể thực hiện operations

### Chi tiết Rules:
- **Users**: User chỉ đọc/ghi của mình, admin đọc/ghi tất cả
- **Decks**: Public decks ai cũng đọc được, chỉ author/admin mới sửa/xóa
- **Flashcards**: Đọc được nếu deck public hoặc của mình, chỉ author/admin sửa/xóa
- **Progress**: User chỉ đọc/ghi progress của mình
- **Reports**: User tạo report, admin xử lý

---

## 📝 Ghi chú quan trọng

1. **Post-Moderation Model**: Deck công khai ngay khi tạo, chỉ ẩn khi bị report
2. **Composite Keys**: Sử dụng `${userId}_${deckId}` cho progress và favorites
3. **Denormalization**: Lưu `authorName` trong deck để tránh join query
4. **Aggregated Data**: Lưu `flashcardCount`, `favoriteCount` để tránh count query
5. **Real-time Updates**: Sử dụng Firestore listeners cho real-time sync

---

## 🔗 Tài liệu liên quan

- `FIREBASE_DATABASE_DESIGN.md` - Chi tiết thiết kế database
- `FIREBASE_SETUP.md` - Hướng dẫn setup Firebase
- `ADMIN_FEATURES.md` - Chi tiết tính năng admin

---

**Cập nhật lần cuối**: 2024

