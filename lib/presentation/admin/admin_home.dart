import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../data/datasources/firestore_repository.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDecks': 0,
    'totalFlashcards': 0,
    'pendingReports': 0,
  };
  bool _isLoading = true;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadUnreadNotificationsCount();
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    try {
      final count = await _firestoreRepo.getUnreadNotificationsCount(userId);
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = count;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading unread notifications count: $e');
    }
  }

  Widget _buildAvatarIcon() {
    final currentUser = AuthService.currentUser;
    final avatarUrl = currentUser?['avatarUrl'] ?? currentUser?['photoUrl'];
    final userName = currentUser?['name'] ?? 'Admin';
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final stats = await _firestoreRepo.getAdminStatistics();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
      debugPrint('✅ Admin statistics loaded: $stats');
    } catch (e) {
      debugPrint('❌ Error loading admin statistics: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thống kê: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings, size: 24),
              const SizedBox(width: 8),
              const Text('Quản trị viên'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Về trang chủ',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings, size: 24),
            const SizedBox(width: 8),
            const Text('Quản trị viên'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Về trang chủ',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.home,
                (route) => false,
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.notifications).then((_) {
                    // Reload unread count when returning from notifications screen
                    _loadUnreadNotificationsCount();
                  });
                },
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadNotificationsCount > 99 ? '99+' : '$_unreadNotificationsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.settings,
                arguments: true, // fromAdmin = true
              );
            },
            icon: _buildAvatarIcon(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào, Admin!',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quản lý hệ thống Flashcard Study Deck',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick stats
            Text(
              'Thống kê tổng quan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _AdminStatCard(
                  icon: Icons.people,
                  label: 'Người dùng',
                  value: '${_stats['totalUsers']}',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.manageUsers);
                  },
                ),
                _AdminStatCard(
                  icon: Icons.collections_bookmark,
                  label: 'Tổng Deck',
                  value: '${_stats['totalDecks']}',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.manageDecks);
                  },
                ),
                _AdminStatCard(
                  icon: Icons.credit_card,
                  label: 'Tổng Flashcard',
                  value: '${_stats['totalFlashcards']}',
                  color: Colors.orange,
                  onTap: () {},
                ),
                _AdminStatCard(
                  icon: Icons.report,
                  label: 'Báo cáo',
                  value: '${_stats['pendingReports']}',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.manageReports);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Management sections
            Text(
              'Quản lý',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _ManagementCard(
              icon: Icons.people_outline,
              title: 'Quản lý người dùng',
              description: 'Xem, chỉnh sửa và quản lý tài khoản người dùng',
              color: Colors.blue,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageUsers);
              },
            ),
            const SizedBox(height: 12),
            _ManagementCard(
              icon: Icons.collections_bookmark_outlined,
              title: 'Quản lý Deck',
              description: 'Duyệt, xóa và quản lý các deck trong hệ thống',
              color: Colors.green,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageDecks);
              },
            ),
            const SizedBox(height: 12),
            _ManagementCard(
              icon: Icons.report_outlined,
              title: 'Quản lý báo cáo',
              description: 'Xem và xử lý các báo cáo từ người dùng',
              color: Colors.red,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.manageReports);
              },
            ),
            const SizedBox(height: 12),
            _ManagementCard(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard',
              description: 'Xem thống kê chi tiết và biểu đồ',
              color: Colors.purple,
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.adminDashboard);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _AdminStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

