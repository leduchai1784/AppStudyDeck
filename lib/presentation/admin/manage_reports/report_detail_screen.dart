import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  
  const ReportDetailScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  Map<String, dynamic>? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final report = await _firestoreRepo.getReportById(widget.reportId);
      setState(() {
        _report = report;
        _isLoading = false;
      });
      debugPrint('✅ Loaded report: ${report?['reportType']}');
    } catch (e) {
      debugPrint('❌ Error loading report: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải báo cáo: $e'),
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
        appBar: AppBar(title: const Text('Chi tiết báo cáo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết báo cáo')),
        body: const Center(child: Text('Không tìm thấy báo cáo')),
      );
    }

    final status = _report!['status'] ?? 'pending';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết báo cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMenuDialog();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report info
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.report,
                              size: 30,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _report!['reportType'] ?? 'Báo cáo',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _report!['reporterName'] ?? 'Unknown',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Chip(
                            label: Text(
                              status == 'pending' ? 'Chờ xử lý' :
                              status == 'resolved' ? 'Đã xử lý' : 'Đã từ chối',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            backgroundColor: status == 'pending' ? Colors.orange[100] :
                                status == 'resolved' ? Colors.green[100] : Colors.red[100],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        'Nội dung báo cáo',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          _report!['content'] ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Ngày báo cáo: ${_formatDate(_report!['createdAt'])}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Related content
              if (_report!['deckId'] != null)
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.collections_bookmark, 
                                 color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Nội dung liên quan',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.collections_bookmark,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: const Text(
                              'Deck liên quan',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: const Text('Bấm để xem chi tiết deck'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.deckDetail,
                                arguments: _report!['deckId'],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Actions
              if (status == 'pending')
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.settings, 
                                 color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Xử lý báo cáo',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            _showAcceptDialog();
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Chấp nhận và xử lý'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showRejectDialog();
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Từ chối báo cáo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _markAsResolved();
                          },
                          icon: const Icon(Icons.done_all),
                          label: const Text('Đánh dấu đã xử lý'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      DateTime date;
      
      if (dateValue is DateTime) {
        date = dateValue;
      } else {
        String dateStr = dateValue.toString().trim();
        if (dateStr.isEmpty || dateStr == 'null') return 'N/A';
        
        // Handle Firestore Timestamp string representation
        if (dateStr.contains('Timestamp')) {
          final isoMatch = RegExp(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})').firstMatch(dateStr);
          if (isoMatch != null) {
            dateStr = isoMatch.group(1)!;
          } else {
            final match = RegExp(r'seconds=(\d+)').firstMatch(dateStr);
            if (match != null) {
              final seconds = int.parse(match.group(1)!);
              date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
              return '${date.day}/${date.month}/${date.year}';
            }
            return 'N/A';
          }
        }
        
        date = DateTime.parse(dateStr);
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showMenuDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tùy chọn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa báo cáo'),
              subtitle: const Text('Xóa vĩnh viễn báo cáo này'),
              onTap: () {
                Navigator.of(context).pop();
                _showDeleteConfirmDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa báo cáo này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              try {
                await _firestoreRepo.deleteReport(widget.reportId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã xóa báo cáo'),
                    backgroundColor: Colors.green,
                  ),
                );
                if (mounted) {
                  Navigator.of(context).pop(); // Return to previous screen
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi xóa báo cáo: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showAcceptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Xác nhận xử lý'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn có chắc chắn muốn chấp nhận báo cáo này?'),
            if (_report!['deckId'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn có thể ẩn deck liên quan sau khi chấp nhận báo cáo.',
                        style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreRepo.updateReportStatus(
                  reportId: widget.reportId,
                  status: 'resolved',
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadReport();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Báo cáo đã được xử lý'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Từ chối báo cáo'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn từ chối báo cáo này? Báo cáo sẽ được đánh dấu là "Đã từ chối".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreRepo.updateReportStatus(
                  reportId: widget.reportId,
                  status: 'rejected',
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                await _loadReport();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Báo cáo đã bị từ chối'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsResolved() async {
    try {
      await _firestoreRepo.updateReportStatus(
        reportId: widget.reportId,
        status: 'resolved',
      );
      if (!mounted) return;
      await _loadReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đánh dấu báo cáo là đã xử lý'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
