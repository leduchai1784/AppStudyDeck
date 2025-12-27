# 📋 Danh sách chức năng Admin

## 🏠 1. Admin Home Screen (`admin_home.dart`)

### Chức năng hiện có:
- ✅ Thống kê tổng quan (đang dùng MockApi)
  - Tổng số người dùng
  - Tổng số Deck
  - Tổng số Flashcard
  - Số báo cáo chờ xử lý

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository** để lấy dữ liệu thực từ Firestore
- ⚠️ **Load thống kê từ Firestore**:
  - Đếm số user trong collection `users`
  - Đếm số deck trong collection `decks`
  - Đếm số flashcard trong collection `flashcards`
  - Đếm số report có `status = 'pending'` trong collection `reports`

---

## 👥 2. Quản lý Người dùng (`manage_users_screen.dart`)

### Chức năng hiện có:
- ✅ Hiển thị danh sách người dùng (đang dùng MockApi)
- ✅ Tìm kiếm người dùng (theo tên, email)
- ✅ Lọc theo: Tất cả / Người dùng / Admin / Bị khóa
- ✅ Xem chi tiết người dùng

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getAllUsers()` - Lấy tất cả users từ collection `users`
  - `searchUsers(query)` - Tìm kiếm users (fuzzy search)
  - Filter theo `role` và `isBlocked`

### Chi tiết User (`user_detail_screen.dart`):
- ✅ Xem thông tin người dùng
- ✅ Chỉnh sửa thông tin (tên, email)
- ✅ Đặt lại mật khẩu
- ✅ Khóa/Mở khóa tài khoản
- ✅ Xem thống kê: Deck, Flashcard, Đã học, Ngày tham gia
- ⚠️ **Xóa người dùng** (chưa implement)

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getUserById(userId)` - Lấy user từ `users` collection
  - `updateUser(userId, data)` - Cập nhật user
  - `resetUserPassword(userId, newPassword)` - Reset password (cần Firebase Auth Admin SDK hoặc Cloud Functions)
  - `toggleBlockUser(userId)` - Set `isBlocked = true/false`
  - `deleteUser(userId)` - Xóa user (cần xóa cả dữ liệu liên quan)
  - `getUserStatistics(userId)` - Lấy thống kê của user (decks, flashcards, progress)

---

## 📚 3. Quản lý Deck (`manage_decks_screen.dart`)

### Chức năng hiện có:
- ✅ Hiển thị danh sách deck (đang dùng MockApi)
- ✅ Tìm kiếm deck (theo tên, mô tả)
- ✅ Lọc theo: Tất cả / Đã duyệt / Chờ duyệt / Bị từ chối
- ✅ Xem chi tiết và duyệt deck

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getAllDecksForAdmin()` - Lấy tất cả decks từ collection `decks`
  - `searchDecks(query)` - Tìm kiếm decks (fuzzy search)
  - Filter theo `approvalStatus`: `approved`, `pending`, `rejected`

### Duyệt Deck (`deck_review_screen.dart`):
- ✅ Xem thông tin deck chi tiết
- ✅ Xem preview flashcard trong deck
- ✅ **Duyệt deck** (approve) - Set `approvalStatus = 'approved'`
- ✅ **Từ chối deck** (reject) - Set `approvalStatus = 'rejected'` + lý do

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getDeckById(deckId)` - Lấy deck từ `decks` collection
  - `getFlashcardsByDeck(deckId)` - Lấy flashcards của deck
  - `approveDeck(deckId)` - Update `approvalStatus = 'approved'`, `isPublic = true`
  - `rejectDeck(deckId, reason)` - Update `approvalStatus = 'rejected'`, `isPublic = false`
  - `deleteDeck(deckId)` - Xóa deck và tất cả flashcards liên quan

---

## 📢 4. Quản lý Báo cáo (`manage_reports_screen.dart`)

### Chức năng hiện có:
- ✅ Hiển thị danh sách báo cáo (đang dùng MockApi)
- ✅ Tìm kiếm báo cáo (theo loại, nội dung)
- ✅ Lọc theo: Tất cả / Chờ xử lý / Đã xử lý / Đã từ chối
- ✅ Xem chi tiết báo cáo

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getAllReports()` - Lấy tất cả reports từ collection `reports`
  - `searchReports(query)` - Tìm kiếm reports
  - Filter theo `status`: `pending`, `resolved`, `rejected`

### Chi tiết Báo cáo (`report_detail_screen.dart`):
- ✅ Xem thông tin báo cáo chi tiết
- ✅ Xem nội dung liên quan (deck/flashcard/user)
- ✅ **Chấp nhận và xử lý** - Set `status = 'resolved'`
- ✅ **Từ chối báo cáo** - Set `status = 'rejected'`
- ✅ **Đánh dấu đã xử lý** - Set `status = 'resolved'`
- ⚠️ **Xóa báo cáo** (chưa implement)

### Cần làm:
- ⚠️ **Thay MockApi bằng FirestoreRepository**:
  - `getReportById(reportId)` - Lấy report từ `reports` collection
  - `updateReportStatus(reportId, status)` - Update `status` và `resolvedBy`, `resolvedAt`
  - `deleteReport(reportId)` - Xóa report
  - **Xử lý báo cáo**: Khi chấp nhận báo cáo, có thể tự động:
    - Xóa deck/flashcard nếu vi phạm
    - Khóa user nếu vi phạm nghiêm trọng
    - Gửi thông báo cho người báo cáo

---

## 📊 5. Dashboard (`dashboard_screen.dart`)

### Chức năng hiện có:
- ✅ Hiển thị thống kê tổng quan (hardcode = 0)
- ⚠️ **Biểu đồ thống kê** (chưa có dữ liệu)
- ⚠️ **Hoạt động gần đây** (chưa có dữ liệu)

### Cần làm:
- ⚠️ **Load dữ liệu thực từ Firestore**:
  - Tổng người dùng
  - Tổng Deck
  - Tổng Flashcard
  - Hoạt động hôm nay (số deck mới, số user mới, số report mới)
  
- ⚠️ **Thêm biểu đồ** (có thể dùng `fl_chart` package):
  - Biểu đồ cột: Số user/deck/flashcard theo thời gian (7 ngày, 30 ngày)
  - Biểu đồ tròn: Phân bố deck theo trạng thái (approved/pending/rejected)
  - Biểu đồ đường: Xu hướng tăng trưởng người dùng

- ⚠️ **Hoạt động gần đây**:
  - Danh sách các hoạt động gần đây:
    - User mới đăng ký
    - Deck mới được tạo
    - Deck được duyệt/từ chối
    - Report mới
    - User bị khóa/mở khóa

---

## 🔧 Các phương thức cần thêm vào FirestoreRepository:

### User Management:
```dart
// Lấy tất cả users (admin only)
Future<List<Map<String, dynamic>>> getAllUsers({int limit = 100}) async

// Tìm kiếm users
Future<List<Map<String, dynamic>>> searchUsers(String query) async

// Cập nhật user (admin only)
Future<void> updateUser(String userId, Map<String, dynamic> updates) async

// Khóa/Mở khóa user
Future<void> toggleBlockUser(String userId, bool isBlocked) async

// Reset password (cần Cloud Functions hoặc Admin SDK)
Future<void> resetUserPassword(String userId, String newPassword) async

// Xóa user (cần xóa cả dữ liệu liên quan)
Future<void> deleteUser(String userId) async

// Lấy thống kê của user
Future<Map<String, dynamic>> getUserStatistics(String userId) async
```

### Deck Management:
```dart
// Lấy tất cả decks (admin only - không filter)
Future<List<Map<String, dynamic>>> getAllDecksForAdmin({int limit = 100}) async

// Duyệt deck
Future<void> approveDeck(String deckId) async

// Từ chối deck
Future<void> rejectDeck(String deckId, String reason) async

// Xóa deck (admin only)
Future<void> deleteDeck(String deckId) async
```

### Report Management:
```dart
// Lấy tất cả reports (admin only)
Future<List<Map<String, dynamic>>> getAllReports({int limit = 100}) async

// Cập nhật trạng thái report
Future<void> updateReportStatus(String reportId, String status, {String? adminNotes}) async

// Xóa report
Future<void> deleteReport(String reportId) async
```

### Statistics:
```dart
// Lấy thống kê tổng quan cho admin
Future<Map<String, dynamic>> getAdminStatistics() async

// Lấy hoạt động gần đây
Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 20}) async
```

---

## 📝 Gợi ý thứ tự implement:

### Ưu tiên 1 (Quan trọng nhất):
1. ✅ **Admin Home Screen** - Load thống kê từ Firestore
2. ✅ **Quản lý Users** - Thay MockApi bằng Firestore
3. ✅ **Quản lý Decks** - Thay MockApi bằng Firestore
4. ✅ **Quản lý Reports** - Thay MockApi bằng Firestore

### Ưu tiên 2:
5. ✅ **Dashboard** - Load dữ liệu thực và thêm biểu đồ
6. ✅ **User Detail** - Load thống kê thực của user
7. ✅ **Deck Review** - Xem preview flashcard và duyệt deck

### Ưu tiên 3:
8. ✅ **Hoạt động gần đây** - Log các hoạt động quan trọng
9. ✅ **Xóa user/deck/report** - Implement delete functions
10. ✅ **Reset password** - Implement qua Cloud Functions

---

## 🔐 Security Rules cần cập nhật:

- Admin chỉ có thể đọc/ghi tất cả collections
- User thường không thể đọc/ghi admin-only collections
- Cần kiểm tra `isAdmin()` trong security rules

