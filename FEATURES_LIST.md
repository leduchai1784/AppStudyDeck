# Danh Sách Chức Năng Chính - Flashcard Study Deck

## 📋 Mục lục
1. [Chức năng User](#chức-năng-user)
2. [Chức năng Admin](#chức-năng-admin)

---

## 👤 Chức năng User

### 🔐 1. Xác thực (Authentication)

#### 1.1. Đăng ký (Register)
- ✅ Đăng ký tài khoản mới với Email/Password
- ✅ Nhập thông tin: Email, Password, Họ tên
- ✅ Validate email và password
- ✅ Tự động tạo user document trong Firestore
- ✅ Tự động đăng nhập sau khi đăng ký thành công

#### 1.2. Đăng nhập (Login)
- ✅ Đăng nhập bằng Email/Password
- ✅ Đăng nhập bằng Google Sign-In
- ✅ Lưu trạng thái đăng nhập
- ✅ Tự động kiểm tra user bị khóa
- ✅ Redirect tự động sau khi đăng nhập

#### 1.3. Quên mật khẩu (Forgot Password)
- ✅ Gửi email reset mật khẩu
- ✅ Nhập email để nhận link reset

#### 1.4. Đăng xuất (Logout)
- ✅ Đăng xuất khỏi tài khoản
- ✅ Xóa session và redirect về Login

---

### 🏠 2. Trang chủ (Home)

#### 2.1. Dashboard
- ✅ Hiển thị thông tin chào mừng
- ✅ Thống kê nhanh:
  - Tổng số Deck đã tạo
  - Tổng số Flashcard đã tạo
  - Số Flashcard đã học hôm nay
  - Điểm số (User Score)
- ✅ Hiển thị số thông báo chưa đọc

#### 2.2. Thao tác nhanh (Quick Actions)
- ✅ Bắt đầu học → Chuyển đến danh sách Deck
- ✅ Tạo Deck mới → Dialog tạo deck
- ✅ Quản lý Deck → Chuyển đến danh sách Deck
- ✅ Xem thống kê → Chuyển đến Statistics

#### 2.3. Deck gần đây
- ✅ Hiển thị 3 deck gần đây nhất
- ✅ Tap để xem chi tiết deck

---

### 📚 3. Quản lý Deck

#### 3.1. Danh sách Deck (Deck List)
- ✅ Hiển thị tất cả deck:
  - Deck công khai của tất cả user
  - Deck riêng tư của chính mình
- ✅ Tìm kiếm deck theo tên, mô tả
- ✅ Lọc deck:
  - Tất cả
  - Deck của tôi
  - Deck yêu thích
- ✅ Sắp xếp theo:
  - Mới nhất
  - Phổ biến nhất (viewCount)
  - Yêu thích nhất (favoriteCount)
- ✅ Thêm deck vào yêu thích/Bỏ yêu thích
- ✅ Tap deck để xem chi tiết

#### 3.2. Chi tiết Deck (Deck Detail)
- ✅ Hiển thị thông tin deck:
  - Tên deck
  - Mô tả
  - Tác giả
  - Số lượng flashcard
  - Số lượt xem
  - Số lượt yêu thích
- ✅ Danh sách flashcards trong deck
- ✅ Các thao tác:
  - ✅ Thêm flashcard mới
  - ✅ Thêm flashcard hàng loạt (CSV)
  - ✅ Sửa thông tin deck
  - ✅ Xóa deck
  - ✅ Bắt đầu học deck
  - ✅ Thêm/Bỏ yêu thích
  - ✅ Báo cáo deck (nếu vi phạm)

#### 3.3. Tạo Deck mới
- ✅ Dialog tạo deck:
  - Nhập tên deck
  - Nhập mô tả
  - Chọn quyền riêng tư (Public/Private)
- ✅ Tự động tạo deck document trong Firestore
- ✅ Redirect đến Deck Detail sau khi tạo

#### 3.4. Sửa Deck
- ✅ Sửa tên deck
- ✅ Sửa mô tả
- ✅ Thay đổi quyền riêng tư (Public/Private)
- ✅ Chỉ author mới có thể sửa

#### 3.5. Xóa Deck
- ✅ Xóa deck và tất cả flashcards liên quan
- ✅ Chỉ author mới có thể xóa
- ✅ Xác nhận trước khi xóa

---

### 🃏 4. Quản lý Flashcard

#### 4.1. Thêm Flashcard đơn lẻ
- ✅ Form thêm flashcard:
  - Nhập mặt trước (Front)
  - Nhập mặt sau (Back)
  - Thêm tags (tùy chọn)
- ✅ Tự động tăng flashcardCount của deck
- ✅ Tự động set order cho flashcard

#### 4.2. Thêm Flashcard hàng loạt (Bulk Add)
- ✅ Chọn file CSV từ thiết bị
- ✅ Parse CSV với format:
  - `front,back` hoặc
  - `front,back,tags`
- ✅ Validate dữ liệu trước khi import
- ✅ Batch create flashcards
- ✅ Hiển thị kết quả import (thành công/lỗi)

#### 4.3. Sửa Flashcard
- ✅ Sửa mặt trước (Front)
- ✅ Sửa mặt sau (Back)
- ✅ Sửa tags
- ✅ Chỉ author của deck mới có thể sửa

#### 4.4. Xóa Flashcard
- ✅ Xóa flashcard
- ✅ Tự động giảm flashcardCount của deck
- ✅ Chỉ author của deck mới có thể xóa

---

### 📖 5. Học tập (Study)

#### 5.1. Chế độ học
- ✅ Hiển thị flashcard từng cái một
- ✅ Flip card để xem mặt sau
- ✅ Đánh dấu "Đã biết" (Known)
- ✅ Đánh dấu "Chưa biết" (Unknown)
- ✅ Điều hướng: Previous/Next card
- ✅ Hiển thị tiến độ: `currentIndex / totalCards`

#### 5.2. Theo dõi tiến độ
- ✅ Lưu progress cho từng flashcard:
  - `isKnown` (true/false)
  - `reviewCount` (số lần đã review)
  - `lastReviewDate`
  - `correctStreak` / `incorrectStreak`
- ✅ Cập nhật deck progress:
  - `studiedFlashcards`
  - `knownFlashcards`
  - `unknownFlashcards`
  - `lastStudyDate`
  - `completionPercentage`
- ✅ Lưu study session:
  - Thời gian bắt đầu/kết thúc
  - Số flashcard đã học
  - Số flashcard đã biết/chưa biết

#### 5.3. Hoàn thành phiên học
- ✅ Hiển thị dialog khi hoàn thành
- ✅ Thống kê phiên học:
  - Tổng số flashcard đã học
  - Số flashcard đã biết
  - Số flashcard chưa biết
  - Thời gian học
- ✅ Cập nhật thống kê user

---

### 🔍 6. Tìm kiếm (Search)

#### 6.1. Tìm kiếm Deck
- ✅ Tìm kiếm theo:
  - Tên deck
  - Mô tả deck
  - Tags
- ✅ Hiển thị kết quả tìm kiếm
- ✅ Tap để xem chi tiết deck

#### 6.2. Tìm kiếm Flashcard
- ✅ Tìm kiếm theo:
  - Nội dung mặt trước (Front)
  - Nội dung mặt sau (Back)
  - Tags
- ✅ Hiển thị flashcard và deck chứa nó
- ✅ Tap để xem chi tiết flashcard

---

### 📊 7. Thống kê (Statistics)

#### 7.1. Thống kê tổng quan
- ✅ Tổng số Deck đã tạo
- ✅ Tổng số Flashcard đã tạo
- ✅ Tổng số Deck đã học
- ✅ Tổng số Flashcard đã học
- ✅ Tổng thời gian học (phút)
- ✅ Chuỗi ngày học liên tiếp (Streak)
- ✅ Số deck yêu thích

#### 7.2. Thống kê theo thời gian
- ✅ Hôm nay:
  - Số flashcard đã học
  - Thời gian học
  - Số deck đã học
- ✅ Tuần này:
  - Số flashcard đã học
  - Thời gian học
  - Số deck đã học
- ✅ Tháng này:
  - Số flashcard đã học
  - Thời gian học
  - Số deck đã học

#### 7.3. Thống kê chi tiết
- ✅ Số flashcard đã biết
- ✅ Số deck đã hoàn thành
- ✅ Thời gian trung bình mỗi phiên học
- ✅ Tiến độ học theo từng deck:
  - Tên deck
  - Số flashcard đã học / Tổng số
  - Phần trăm hoàn thành
  - Ngày học gần nhất

---

### 🔔 8. Thông báo (Notifications)

#### 8.1. Danh sách thông báo
- ✅ Hiển thị tất cả thông báo
- ✅ Đánh dấu đã đọc/chưa đọc
- ✅ Đếm số thông báo chưa đọc
- ✅ Xóa thông báo

#### 8.2. Các loại thông báo
- ✅ Thông báo hệ thống
- ✅ Thông báo về deck yêu thích
- ✅ Thông báo về báo cáo

---

### ⚙️ 9. Cài đặt (Settings)

#### 9.1. Thông tin cá nhân
- ✅ Xem thông tin tài khoản:
  - Tên
  - Email
  - Avatar
  - Ngày tham gia
- ✅ Chỉnh sửa thông tin:
  - Sửa tên
  - Sửa email (với xác thực lại)
  - Upload avatar mới

#### 9.2. Bảo mật
- ✅ Đổi mật khẩu (với xác thực mật khẩu hiện tại)
- ✅ Gửi email xác thực

#### 9.3. Giao diện
- ✅ Chuyển đổi Dark/Light theme
- ✅ Lưu preference vào SharedPreferences

#### 9.4. Khác
- ✅ Đăng xuất
- ✅ Truy cập Admin Panel (nếu là admin)

---

## 👨‍💼 Chức năng Admin

### 🏠 1. Admin Home

#### 1.1. Thống kê tổng quan
- ✅ Tổng số người dùng
- ✅ Tổng số Deck
- ✅ Tổng số Flashcard
- ✅ Số báo cáo chờ xử lý
- ✅ Tap vào từng thống kê để xem chi tiết

#### 1.2. Thao tác nhanh
- ✅ Quản lý người dùng
- ✅ Quản lý Deck
- ✅ Quản lý báo cáo
- ✅ Xem Dashboard

---

### 👥 2. Quản lý Người dùng (Manage Users)

#### 2.1. Danh sách người dùng
- ✅ Hiển thị tất cả người dùng trong hệ thống
- ✅ Tìm kiếm theo:
  - Tên
  - Email
- ✅ Lọc theo:
  - Tất cả
  - Người dùng (role = 'user')
  - Admin (role = 'admin')
  - Bị khóa (isBlocked = true)
- ✅ Sắp xếp theo:
  - Ngày tham gia (mới nhất)
  - Tên (A-Z)
  - Email (A-Z)

#### 2.2. Chi tiết người dùng (User Detail)
- ✅ Xem thông tin chi tiết:
  - Tên, Email
  - Role (admin/user)
  - Trạng thái (active/blocked)
  - Ngày tham gia
  - Lần đăng nhập cuối
  - Provider (email/google)
- ✅ Chỉnh sửa thông tin:
  - Sửa tên
  - Sửa email
- ✅ Quản lý tài khoản:
  - Khóa/Mở khóa tài khoản
  - Đặt lại mật khẩu
  - Xóa người dùng (cần xác nhận)
- ✅ Xem thống kê:
  - Số deck đã tạo
  - Số flashcard đã tạo
  - Số deck đã học
  - Số flashcard đã học
  - Tổng thời gian học

---

### 📚 3. Quản lý Deck (Manage Decks)

#### 3.1. Danh sách Deck công khai
- ✅ Hiển thị tất cả deck công khai (isPublic = true)
- ✅ Tìm kiếm theo:
  - Tên deck
  - Mô tả
  - Tên tác giả
- ✅ Hiển thị thông tin:
  - Tên deck
  - Tác giả
  - Số flashcard
  - Số lượt xem
- ✅ Tap để xem chi tiết và review

#### 3.2. Review Deck (Deck Review)
- ✅ Xem thông tin deck chi tiết:
  - Tên, mô tả
  - Tác giả
  - Số flashcard
  - Trạng thái (public/private/reported/hidden)
- ✅ Xem preview flashcards trong deck
- ✅ Các thao tác:
  - ✅ Ẩn deck (Hide) - Set status = 'hidden'
  - ✅ Khôi phục deck (Restore) - Set status = 'public'
  - ✅ Xóa deck và tất cả flashcards liên quan
  - ✅ Xem chi tiết tác giả

---

### 📢 4. Quản lý Báo cáo (Manage Reports)

#### 4.1. Danh sách báo cáo
- ✅ Hiển thị tất cả báo cáo
- ✅ Tìm kiếm theo:
  - Loại báo cáo
  - Nội dung
  - Tên người báo cáo
- ✅ Lọc theo trạng thái:
  - Tất cả
  - Chờ xử lý (pending)
  - Đã xử lý (resolved)
  - Đã từ chối (rejected)
- ✅ Sắp xếp theo ngày tạo (mới nhất)

#### 4.2. Chi tiết báo cáo (Report Detail)
- ✅ Xem thông tin báo cáo:
  - Loại báo cáo (inappropriate_content/spam/copyright/other)
  - Người báo cáo
  - Nội dung báo cáo
  - Đối tượng bị báo cáo (deck/flashcard/user)
  - Trạng thái
  - Ngày tạo
- ✅ Xem nội dung liên quan:
  - Xem deck/flashcard/user bị báo cáo
- ✅ Xử lý báo cáo:
  - ✅ Chấp nhận và xử lý:
    - Set status = 'resolved'
    - Ghi chú của admin
    - Có thể tự động ẩn deck/flashcard
    - Có thể tự động khóa user (nếu vi phạm nghiêm trọng)
  - ✅ Từ chối báo cáo:
    - Set status = 'rejected'
    - Ghi chú lý do từ chối
  - ✅ Xóa báo cáo

---

### 📊 5. Dashboard

#### 5.1. Thống kê chi tiết
- ✅ Tổng số người dùng
- ✅ Số người dùng hoạt động
- ✅ Tổng số Deck:
  - Deck công khai
  - Deck bị báo cáo
  - Deck đã ẩn
- ✅ Tổng số Flashcard
- ✅ Thống kê báo cáo:
  - Tổng số báo cáo
  - Báo cáo chờ xử lý
  - Báo cáo đã xử lý

#### 5.2. Hoạt động hôm nay
- ✅ Số user mới đăng ký
- ✅ Số deck mới được tạo
- ✅ Số báo cáo mới

#### 5.3. Biểu đồ (Future)
- ⚠️ Biểu đồ cột: Số user/deck/flashcard theo thời gian
- ⚠️ Biểu đồ tròn: Phân bố deck theo trạng thái
- ⚠️ Biểu đồ đường: Xu hướng tăng trưởng người dùng

#### 5.4. Hoạt động gần đây (Future)
- ⚠️ Danh sách các hoạt động:
  - User mới đăng ký
  - Deck mới được tạo
  - Deck được ẩn/khôi phục
  - Report mới
  - User bị khóa/mở khóa

---

### ⚙️ 6. Cài đặt Admin

#### 6.1. Thông tin cá nhân
- ✅ Xem và chỉnh sửa thông tin admin
- ✅ Upload avatar

#### 6.2. Bảo mật
- ✅ Đổi mật khẩu
- ✅ Quản lý session

#### 6.3. Khác
- ✅ Đăng xuất
- ✅ Quay về trang User Home

---

## 📝 Tóm tắt

### User có thể:
- ✅ Đăng ký, đăng nhập, quản lý tài khoản
- ✅ Tạo và quản lý deck/flashcard
- ✅ Học tập và theo dõi tiến độ
- ✅ Tìm kiếm deck/flashcard
- ✅ Xem thống kê học tập
- ✅ Quản lý yêu thích
- ✅ Báo cáo nội dung vi phạm

### Admin có thể:
- ✅ Quản lý tất cả người dùng (xem, sửa, khóa, xóa)
- ✅ Quản lý tất cả deck công khai (xem, ẩn, xóa)
- ✅ Xử lý báo cáo từ người dùng
- ✅ Xem thống kê tổng quan hệ thống
- ✅ Dashboard với biểu đồ và hoạt động

---

**Cập nhật lần cuối**: 2024

