import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../../data/models/notification_model.dart';
import '../../../core/services/auth_service.dart';
import '../../routes/app_routes.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final notificationsData = await _firestoreRepo.getUserNotifications(userId);
      final unreadCount = await _firestoreRepo.getUnreadNotificationsCount(userId);

      final notificationsList = notificationsData.map((data) {
        // Handle createdAt - could be Timestamp or String (ISO8601)
        DateTime createdAt;
        if (data['createdAt'] == null) {
          createdAt = DateTime.now();
        } else if (data['createdAt'] is Timestamp) {
          createdAt = (data['createdAt'] as Timestamp).toDate();
        } else if (data['createdAt'] is String) {
          try {
            createdAt = DateTime.parse(data['createdAt'] as String);
          } catch (e) {
            debugPrint('⚠️ Error parsing createdAt: $e');
            createdAt = DateTime.now();
          }
        } else {
          createdAt = DateTime.now();
        }

        return NotificationModel(
          id: data['notificationId'] ?? '',
          userId: data['userId'] ?? '',
          type: data['type'] ?? '',
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          data: data['data'] != null ? Map<String, dynamic>.from(data['data']) : null,
          isRead: data['isRead'] ?? false,
          createdAt: createdAt,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _notifications = notificationsList;
          _unreadCount = unreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thông báo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestoreRepo.markNotificationAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
      });
    } catch (e) {
      debugPrint('❌ Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    try {
      await _firestoreRepo.markAllNotificationsAsRead(userId);
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu tất cả là đã đọc'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestoreRepo.deleteNotification(notificationId);
      setState(() {
        _notifications.removeWhere((n) => n.id == notificationId);
        if (_notifications.any((n) => !n.isRead)) {
          _unreadCount = _notifications.where((n) => !n.isRead).length;
        } else {
          _unreadCount = 0;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thông báo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xóa thông báo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read if not read
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    // Navigate based on notification type
    final data = notification.data;
    if (data != null) {
      // Deck-related notifications - navigate to deck detail
      if (notification.type == 'deck_approved' || 
          notification.type == 'deck_rejected' ||
          notification.type == 'deck_created' ||
          notification.type == 'deck_public' ||
          notification.type == 'deck_pending_approval' ||
          notification.type == 'deck_hidden' ||
          notification.type == 'deck_restored' ||
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
      
      // Report-related notifications (for admin) - navigate to report detail
      if (notification.type == 'report_created') {
        final reportId = data['reportId'] as String?;
        if (reportId != null) {
          // Check if user is admin (can navigate to report detail)
          // For now, navigate to deck detail if available
          final deckId = data['deckId'] as String?;
          if (deckId != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.deckDetail,
              arguments: deckId,
            );
          }
          return;
        }
      }
    }
  }

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
      case 'report_created':
        return Icons.report;
      case 'report_rejected':
        return Icons.cancel_outlined;
      case 'deck_hidden':
        return Icons.visibility_off;
      case 'deck_restored':
        return Icons.restore;
      case 'user_blocked':
        return Icons.block;
      case 'user_unblocked':
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
      case 'report_created':
        return Colors.red;
      case 'report_rejected':
        return Colors.red;
      case 'deck_hidden':
        return Colors.red;
      case 'deck_restored':
        return Colors.green;
      case 'user_blocked':
        return Colors.red;
      case 'user_unblocked':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Đánh dấu tất cả'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có thông báo nào',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return Dismissible(
                        key: Key(notification.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          _deleteNotification(notification.id);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          color: notification.isRead
                              ? null
                              : Theme.of(context).colorScheme.primaryContainer.withAlpha((0.1 * 255).round()),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getNotificationColor(notification.type).withAlpha((0.2 * 255).round()),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                color: _getNotificationColor(notification.type),
                              ),
                            ),
                            title: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notification.message),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: notification.isRead
                                ? null
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            onTap: () => _handleNotificationTap(notification),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}

