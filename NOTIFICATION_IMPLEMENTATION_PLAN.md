# Kế Hoạch Triển Khai Hệ Thống Thông Báo

## 📋 Tổng Quan

Dựa trên các chức năng hiện tại của project, đây là kế hoạch triển khai hệ thống thông báo đầy đủ và phù hợp.

---

## 🎯 Các Loại Thông Báo Cần Implement

### 1. **Thông Báo Cho Admin** (Ưu tiên cao)

#### 1.1. Khi User Report Deck
- **Trigger**: `reportDeck()` trong `FirestoreRepository`
- **Người nhận**: Tất cả Admin
- **Type**: `report_created`
- **Nội dung**: 
  - Title: "Có báo cáo mới"
  - Message: "Deck '{deckName}' đã bị báo cáo bởi {reporterName}"
  - Data: `{reportId, deckId, reporterId, reporterName}`

#### 1.2. Khi Có Deck Public Mới (Đã có code nhưng chưa được gọi)
- **Trigger**: `createDeck()` hoặc `updateDeck()` khi `isPublic = true`
- **Người nhận**: Tất cả Admin
- **Type**: `deck_public`
- **Nội dung**: 
  - Title: "Deck đã được công khai"
  - Message: "Deck '{deckName}' của {authorName} đã được công khai"
  - Data: `{deckId, authorId, authorName}`

---

### 2. **Thông Báo Cho User** (Ưu tiên cao)

#### 2.1. Khi Admin Resolve Report
- **Trigger**: `updateReportStatus(status: 'resolved')` trong `FirestoreRepository`
- **Người nhận**: User đã báo cáo (reporterId)
- **Type**: `report_resolved`
- **Nội dung**:
  - Title: "Báo cáo đã được xử lý"
  - Message: "Báo cáo của bạn về deck '{deckName}' đã được admin xử lý"
  - Data: `{reportId, deckId, adminNotes?}`

#### 2.2. Khi Admin Reject Report
- **Trigger**: `updateReportStatus(status: 'rejected')`
- **Người nhận**: User đã báo cáo (reporterId)
- **Type**: `report_rejected`
- **Nội dung**:
  - Title: "Báo cáo đã bị từ chối"
  - Message: "Báo cáo của bạn về deck '{deckName}' đã bị từ chối"
  - Data: `{reportId, deckId, adminNotes?}`

#### 2.3. Khi Admin Hide Deck
- **Trigger**: `hideDeck()` trong `FirestoreRepository`
- **Người nhận**: Author của deck (authorId)
- **Type**: `deck_hidden`
- **Nội dung**:
  - Title: "Deck của bạn đã bị ẩn"
  - Message: "Deck '{deckName}' của bạn đã bị admin ẩn. Lý do: {reason}"
  - Data: `{deckId, reason}`

#### 2.4. Khi Admin Restore Deck
- **Trigger**: `restoreDeck()` trong `FirestoreRepository`
- **Người nhận**: Author của deck (authorId)
- **Type**: `deck_restored`
- **Nội dung**:
  - Title: "Deck của bạn đã được khôi phục"
  - Message: "Deck '{deckName}' của bạn đã được admin khôi phục"
  - Data: `{deckId}`

#### 2.5. Khi Admin Block User
- **Trigger**: `toggleBlockUser(userId, isBlocked: true)`
- **Người nhận**: User bị khóa (userId)
- **Type**: `user_blocked`
- **Nội dung**:
  - Title: "Tài khoản của bạn đã bị khóa"
  - Message: "Tài khoản của bạn đã bị admin khóa. Vui lòng liên hệ hỗ trợ."
  - Data: `{}`

#### 2.6. Khi Admin Unblock User
- **Trigger**: `toggleBlockUser(userId, isBlocked: false)`
- **Người nhận**: User được mở khóa (userId)
- **Type**: `user_unblocked`
- **Nội dung**:
  - Title: "Tài khoản của bạn đã được mở khóa"
  - Message: "Tài khoản của bạn đã được admin mở khóa. Bạn có thể sử dụng lại dịch vụ."
  - Data: `{}`

---

### 3. **Thông Báo Tùy Chọn** (Ưu tiên thấp - có thể thêm sau)

#### 3.1. Khi User Favorite Deck
- **Trigger**: Khi user thêm deck vào favorite
- **Người nhận**: Author của deck
- **Type**: `deck_favorited`
- **Nội dung**:
  - Title: "Deck của bạn được yêu thích"
  - Message: "{userName} đã thêm deck '{deckName}' vào yêu thích"
  - Data: `{deckId, userId, userName}`

#### 3.2. Khi User Study Deck
- **Trigger**: Khi user hoàn thành study session
- **Người nhận**: Author của deck (nếu deck public)
- **Type**: `deck_studied`
- **Nội dung**:
  - Title: "Deck của bạn được học"
  - Message: "{userName} đã học deck '{deckName}' của bạn"
  - Data: `{deckId, userId, userName, sessionId}`

---

## 🔧 Cách Implement

### Bước 1: Tạo Helper Functions trong FirestoreRepository

```dart
// Thêm vào FirestoreRepository

/// Notify admins about new report
Future<void> _notifyAdminsAboutNewReport({
  required String reportId,
  required String deckId,
  required String deckName,
  required String reporterId,
  required String reporterName,
}) async {
  try {
    final adminUsers = await _getAdminUsers();
    if (adminUsers.isEmpty) return;

    final batch = _firestore.batch();
    for (var admin in adminUsers) {
      final adminId = admin['userId'] as String;
      final notificationRef = _notificationsCollection.doc();
      
      batch.set(notificationRef, {
        'userId': adminId,
        'type': 'report_created',
        'title': 'Có báo cáo mới',
        'message': 'Deck "$deckName" đã bị báo cáo bởi $reporterName',
        'data': {
          'reportId': reportId,
          'deckId': deckId,
          'reporterId': reporterId,
          'reporterName': reporterName,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    debugPrint('✅ Notified ${adminUsers.length} admin(s) about new report: $reportId');
  } catch (e) {
    debugPrint('❌ Error notifying admins about report: $e');
  }
}

/// Notify user about report resolution
Future<void> _notifyUserAboutReportResolution({
  required String reporterId,
  required String reportId,
  required String deckId,
  required String deckName,
  required String status, // 'resolved' or 'rejected'
  String? adminNotes,
}) async {
  try {
    final type = status == 'resolved' ? 'report_resolved' : 'report_rejected';
    final title = status == 'resolved' 
        ? 'Báo cáo đã được xử lý' 
        : 'Báo cáo đã bị từ chối';
    final message = status == 'resolved'
        ? 'Báo cáo của bạn về deck "$deckName" đã được admin xử lý'
        : 'Báo cáo của bạn về deck "$deckName" đã bị từ chối';

    await createNotification(
      userId: reporterId,
      type: type,
      title: title,
      message: message,
      data: {
        'reportId': reportId,
        'deckId': deckId,
        'adminNotes': adminNotes,
      },
    );
    debugPrint('✅ Notified user $reporterId about report resolution');
  } catch (e) {
    debugPrint('❌ Error notifying user about report: $e');
  }
}

/// Notify author about deck status change
Future<void> _notifyAuthorAboutDeckStatus({
  required String authorId,
  required String deckId,
  required String deckName,
  required String status, // 'hidden' or 'restored'
  String? reason,
}) async {
  try {
    final type = status == 'hidden' ? 'deck_hidden' : 'deck_restored';
    final title = status == 'hidden'
        ? 'Deck của bạn đã bị ẩn'
        : 'Deck của bạn đã được khôi phục';
    final message = status == 'hidden'
        ? 'Deck "$deckName" của bạn đã bị admin ẩn.${reason != null ? " Lý do: $reason" : ""}'
        : 'Deck "$deckName" của bạn đã được admin khôi phục';

    await createNotification(
      userId: authorId,
      type: type,
      title: title,
      message: message,
      data: {
        'deckId': deckId,
        if (reason != null) 'reason': reason,
      },
    );
    debugPrint('✅ Notified author $authorId about deck status: $status');
  } catch (e) {
    debugPrint('❌ Error notifying author: $e');
  }
}

/// Notify user about account status change
Future<void> _notifyUserAboutAccountStatus({
  required String userId,
  required bool isBlocked,
}) async {
  try {
    final type = isBlocked ? 'user_blocked' : 'user_unblocked';
    final title = isBlocked
        ? 'Tài khoản của bạn đã bị khóa'
        : 'Tài khoản của bạn đã được mở khóa';
    final message = isBlocked
        ? 'Tài khoản của bạn đã bị admin khóa. Vui lòng liên hệ hỗ trợ.'
        : 'Tài khoản của bạn đã được admin mở khóa. Bạn có thể sử dụng lại dịch vụ.';

    await createNotification(
      userId: userId,
      type: type,
      title: title,
      message: message,
      data: {},
    );
    debugPrint('✅ Notified user $userId about account status: ${isBlocked ? "blocked" : "unblocked"}');
  } catch (e) {
    debugPrint('❌ Error notifying user about account status: $e');
  }
}
```

### Bước 2: Gọi Notifications trong các Functions

#### 2.1. Trong `reportDeck()`:
```dart
Future<void> reportDeck(String deckId, String reporterId, String reporterName, String reason) async {
  try {
    // ... existing code ...
    
    // Get deck info for notification
    final deckData = await getDeckById(deckId);
    final deckName = deckData?['name'] ?? 'Unnamed Deck';
    
    // Create report
    final reportRef = await _reportsCollection.add({...});
    final reportId = reportRef.id;
    
    // Notify admins
    await _notifyAdminsAboutNewReport(
      reportId: reportId,
      deckId: deckId,
      deckName: deckName,
      reporterId: reporterId,
      reporterName: reporterName,
    );
    
    debugPrint('✅ Deck reported: $deckId');
  } catch (e) {
    // ... error handling ...
  }
}
```

#### 2.2. Trong `updateReportStatus()`:
```dart
Future<void> updateReportStatus({
  required String reportId,
  required String status,
  String? adminNotes,
  String? resolvedBy,
}) async {
  try {
    // Get report data first
    final reportData = await getReportById(reportId);
    if (reportData == null) throw Exception('Report not found');
    
    // ... update report status ...
    
    // Notify reporter if resolved or rejected
    if (status == 'resolved' || status == 'rejected') {
      final reporterId = reportData['reporterId'] as String?;
      final deckId = reportData['deckId'] as String?;
      
      if (reporterId != null && deckId != null) {
        // Get deck name
        final deckData = await getDeckById(deckId);
        final deckName = deckData?['name'] ?? 'Unnamed Deck';
        
        await _notifyUserAboutReportResolution(
          reporterId: reporterId,
          reportId: reportId,
          deckId: deckId,
          deckName: deckName,
          status: status,
          adminNotes: adminNotes,
        );
      }
    }
  } catch (e) {
    // ... error handling ...
  }
}
```

#### 2.3. Trong `hideDeck()`:
```dart
Future<void> hideDeck(String deckId, String reason) async {
  try {
    // Get deck data first
    final deckData = await getDeckById(deckId);
    if (deckData == null) throw Exception('Deck not found');
    
    final authorId = deckData['authorId'] as String?;
    final deckName = deckData['name'] as String? ?? 'Unnamed Deck';
    
    // ... update deck status ...
    
    // Notify author
    if (authorId != null) {
      await _notifyAuthorAboutDeckStatus(
        authorId: authorId,
        deckId: deckId,
        deckName: deckName,
        status: 'hidden',
        reason: reason,
      );
    }
    
    debugPrint('✅ Deck hidden: $deckId');
  } catch (e) {
    // ... error handling ...
  }
}
```

#### 2.4. Trong `restoreDeck()`:
```dart
Future<void> restoreDeck(String deckId) async {
  try {
    // Get deck data first
    final deckData = await getDeckById(deckId);
    if (deckData == null) throw Exception('Deck not found');
    
    final authorId = deckData['authorId'] as String?;
    final deckName = deckData['name'] as String? ?? 'Unnamed Deck';
    
    // ... update deck status ...
    
    // Notify author
    if (authorId != null) {
      await _notifyAuthorAboutDeckStatus(
        authorId: authorId,
        deckId: deckId,
        deckName: deckName,
        status: 'restored',
      );
    }
    
    debugPrint('✅ Deck restored: $deckId');
  } catch (e) {
    // ... error handling ...
  }
}
```

#### 2.5. Trong `toggleBlockUser()`:
```dart
Future<void> toggleBlockUser(String userId, bool isBlocked) async {
  try {
    // ... update user status ...
    
    // Notify user about status change
    await _notifyUserAboutAccountStatus(
      userId: userId,
      isBlocked: isBlocked,
    );
    
    debugPrint('✅ User $userId ${isBlocked ? "blocked" : "unblocked"}');
  } catch (e) {
    // ... error handling ...
  }
}
```

#### 2.6. Trong `createDeck()` - Kích hoạt thông báo cho admin:
```dart
Future<String> createDeck(Map<String, dynamic> deckData) async {
  try {
    // ... create deck ...
    
    // Notify admins if deck is public
    if (data['isPublic'] == true && data['status'] == 'public') {
      try {
        await _notifyAdminsAboutNewPublicDeck(deckId, data);
      } catch (e) {
        // Don't fail deck creation if notification fails
        debugPrint('⚠️ Error notifying admins: $e');
      }
    }
    
    return deckId;
  } catch (e) {
    // ... error handling ...
  }
}
```

---

## 🎨 Cải Thiện UI/UX

### 1. Thêm Icons và Colors cho các Type mới

Trong `NotificationsScreen`, cập nhật `_getNotificationIcon()` và `_getNotificationColor()`:

```dart
IconData _getNotificationIcon(String type) {
  switch (type) {
    case 'deck_approved':
      return Icons.check_circle;
    case 'deck_rejected':
      return Icons.cancel;
    case 'deck_created':
      return Icons.add_circle;
    case 'deck_public':
      return Icons.public;
    case 'deck_pending_approval':
      return Icons.pending;
    case 'report_resolved':
      return Icons.flag;
    case 'report_created':        // NEW
      return Icons.report;
    case 'report_rejected':        // NEW
      return Icons.cancel_outlined;
    case 'deck_hidden':            // NEW
      return Icons.visibility_off;
    case 'deck_restored':          // NEW
      return Icons.restore;
    case 'user_blocked':           // NEW
      return Icons.block;
    case 'user_unblocked':         // NEW
      return Icons.check_circle_outline;
    default:
      return Icons.notifications;
  }
}

Color _getNotificationColor(String type) {
  switch (type) {
    case 'deck_approved':
      return Colors.green;
    case 'deck_rejected':
      return Colors.red;
    case 'deck_created':
      return Colors.blue;
    case 'deck_public':
      return Colors.blue;
    case 'deck_pending_approval':
      return Colors.orange;
    case 'report_resolved':
      return Colors.orange;
    case 'report_created':         // NEW
      return Colors.red;
    case 'report_rejected':        // NEW
      return Colors.red;
    case 'deck_hidden':            // NEW
      return Colors.red;
    case 'deck_restored':          // NEW
      return Colors.green;
    case 'user_blocked':           // NEW
      return Colors.red;
    case 'user_unblocked':         // NEW
      return Colors.green;
    default:
      return Colors.grey;
  }
}
```

### 2. Cập nhật Navigation Logic

Trong `_handleNotificationTap()`:

```dart
void _handleNotificationTap(NotificationModel notification) {
  if (!notification.isRead) {
    _markAsRead(notification.id);
  }

  final data = notification.data;
  if (data != null) {
    // Deck-related notifications
    if (notification.type.startsWith('deck_') || 
        notification.type == 'report_created' ||
        notification.type == 'report_resolved' ||
        notification.type == 'report_rejected') {
      final deckId = data['deckId'] as String?;
      if (deckId != null) {
        Navigator.pushNamed(
          context,
          AppRoutes.deckDetail,
          arguments: deckId,
        );
        return;
      }
    }
    
    // Report-related notifications (for admin)
    if (notification.type == 'report_created') {
      final reportId = data['reportId'] as String?;
      if (reportId != null) {
        Navigator.pushNamed(
          context,
          AppRoutes.reportDetail,
          arguments: reportId,
        );
        return;
      }
    }
  }
}
```

---

## ⚡ Real-time Updates (Optional - Nâng cao)

### Sử dụng Firestore Stream để real-time notifications:

```dart
Stream<List<NotificationModel>> getUserNotificationsStream(String userId) {
  return _notificationsCollection
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return NotificationModel.fromJson({
        ...data,
        'id': doc.id,
      });
    }).toList();
  });
}
```

Sử dụng trong `NotificationsScreen`:

```dart
StreamBuilder<List<NotificationModel>>(
  stream: _firestoreRepo.getUserNotificationsStream(userId),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return ErrorWidget(snapshot.error!);
    }
    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }
    // ... display notifications ...
  },
)
```

---

## 📊 Tóm Tắt Implementation

### Ưu tiên cao (Cần làm ngay):
1. ✅ Notify admin khi có report mới
2. ✅ Notify user khi report được resolve/reject
3. ✅ Notify author khi deck bị hide/restore
4. ✅ Notify user khi bị block/unblock
5. ✅ Kích hoạt notify admin khi deck public (đã có code)

### Ưu tiên thấp (Có thể thêm sau):
1. ⚠️ Notify author khi deck được favorite
2. ⚠️ Notify author khi deck được study
3. ⚠️ Real-time updates với Stream

---

## 🔍 Testing Checklist

- [ ] Test notify admin khi user report deck
- [ ] Test notify user khi admin resolve/reject report
- [ ] Test notify author khi admin hide/restore deck
- [ ] Test notify user khi admin block/unblock
- [ ] Test notify admin khi deck public
- [ ] Test UI hiển thị đúng icon và color
- [ ] Test navigation từ notification
- [ ] Test mark as read/unread
- [ ] Test delete notification
- [ ] Test unread count badge

---

**Cập nhật lần cuối**: 2024

