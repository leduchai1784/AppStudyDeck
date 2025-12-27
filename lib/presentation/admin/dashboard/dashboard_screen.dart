import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'activeUsers': 0,
    'totalDecks': 0,
    'publicDecks': 0,
    'reportedDecks': 0,
    'hiddenDecks': 0,
    'totalFlashcards': 0,
    'pendingReports': 0,
    'totalReports': 0,
    'resolvedReports': 0,
    'todayActivity': 0,
  };
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final stats = await _firestoreRepo.getAdminStatistics();
      final activities = await _firestoreRepo.getRecentActivities(limit: 10);
      
      // Calculate today's activity
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      int todayActivity = 0;
      for (var activity in activities) {
        final timestamp = activity['timestamp'];
        if (timestamp != null) {
          try {
            DateTime date;
            if (timestamp is Timestamp) {
              date = timestamp.toDate();
            } else if (timestamp is String) {
              date = DateTime.parse(timestamp);
            } else {
              continue;
            }
            if (date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart)) {
              todayActivity++;
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing timestamp: $e');
          }
        }
      }
      
      setState(() {
        _stats = {
          ...stats,
          'todayActivity': todayActivity,
        };
        _recentActivities = activities;
        _isLoading = false;
      });
      debugPrint('✅ Dashboard data loaded');
    } catch (e) {
      debugPrint('❌ Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
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
          title: const Text('Dashboard'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overview cards - Row 1
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Tổng người dùng',
                      value: '${_stats['totalUsers'] ?? 0}',
                      icon: Icons.people,
                      color: Colors.blue,
                      subtitle: '${_stats['activeUsers'] ?? 0} hoạt động (30 ngày)',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Tổng Deck',
                      value: '${_stats['totalDecks'] ?? 0}',
                      icon: Icons.collections_bookmark,
                      color: Colors.green,
                      subtitle: '${_stats['publicDecks'] ?? 0} công khai',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Overview cards - Row 2
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Tổng Flashcard',
                      value: '${_stats['totalFlashcards'] ?? 0}',
                      icon: Icons.credit_card,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Hoạt động hôm nay',
                      value: '${_stats['todayActivity'] ?? 0}',
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Moderation cards
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Báo cáo chờ xử lý',
                      value: '${_stats['pendingReports'] ?? 0}',
                      icon: Icons.report_problem,
                      color: Colors.red,
                      subtitle: '${_stats['totalReports'] ?? 0} tổng cộng',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Deck bị báo cáo',
                      value: '${_stats['reportedDecks'] ?? 0}',
                      icon: Icons.flag,
                      color: Colors.orange,
                      subtitle: '${_stats['hiddenDecks'] ?? 0} đã ẩn',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Charts section
              Text(
                'Biểu đồ thống kê',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              
              // Deck Status Chart
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trạng thái Deck',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _SimpleBarChart(
                        data: {
                          'Công khai': _stats['publicDecks'] ?? 0,
                          'Bị báo cáo': _stats['reportedDecks'] ?? 0,
                          'Đã ẩn': _stats['hiddenDecks'] ?? 0,
                        },
                        colors: [
                          Colors.green,
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Reports Status Chart
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trạng thái Báo cáo',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _SimplePieChart(
                        data: {
                          'Chờ xử lý': _stats['pendingReports'] ?? 0,
                          'Đã xử lý': _stats['resolvedReports'] ?? 0,
                        },
                        colors: [
                          Colors.orange,
                          Colors.green,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Recent activity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hoạt động gần đây',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_recentActivities.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        // TODO: Navigate to full activity list
                      },
                      child: const Text('Xem tất cả'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _recentActivities.isEmpty
                  ? _EmptyActivityList()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentActivities.length,
                      itemBuilder: (context, index) {
                        final activity = _recentActivities[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getActivityColor(activity['type']).withOpacity(0.1),
                              child: Icon(
                                _getActivityIcon(activity['type']),
                                color: _getActivityColor(activity['type']),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              activity['title'] ?? 'Hoạt động',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(activity['description'] ?? ''),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(activity['timestamp']),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Icon(Icons.chevron_right, size: 16),
                              ],
                            ),
                            onTap: () {
                              _handleActivityTap(activity);
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleActivityTap(Map<String, dynamic> activity) {
    final type = activity['type'] as String?;
    
    if (type == 'user_registered' && activity['userId'] != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.userDetail,
        arguments: activity['userId'],
      );
    } else if (type == 'deck_created' && activity['deckId'] != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.deckReview,
        arguments: activity['deckId'],
      );
    } else if (type == 'report_created' && activity['reportId'] != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.reportDetail,
        arguments: activity['reportId'],
      );
    }
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'user_registered':
        return Icons.person_add;
      case 'deck_created':
        return Icons.collections_bookmark;
      case 'report_created':
        return Icons.report;
      default:
        return Icons.history;
    }
  }

  Color _getActivityColor(String? type) {
    switch (type) {
      case 'user_registered':
        return Colors.blue;
      case 'deck_created':
        return Colors.green;
      case 'report_created':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} ngày trước';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;

  const _SimpleBarChart({
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Chưa có dữ liệu'),
        ),
      );
    }

    return Column(
      children: data.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final label = item.key;
        final value = item.value;
        final color = colors[index % colors.length];
        final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 24,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SimplePieChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;

  const _SimplePieChart({
    required this.data,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Chưa có dữ liệu'),
        ),
      );
    }

    return Column(
      children: data.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final label = item.key;
        final value = item.value;
        final color = colors[index % colors.length];
        final percentage = total > 0 ? (value / total * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '$value (${percentage.toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyActivityList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có hoạt động nào',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
