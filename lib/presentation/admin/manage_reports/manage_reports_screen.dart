import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';

class ManageReportsScreen extends StatefulWidget {
  const ManageReportsScreen({super.key});

  @override
  State<ManageReportsScreen> createState() => _ManageReportsScreenState();
}

class _ManageReportsScreenState extends State<ManageReportsScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tất cả';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final reports = await _firestoreRepo.getAllReports();
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
      debugPrint('✅ Loaded ${reports.length} reports');
    } catch (e) {
      debugPrint('❌ Error loading reports: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách báo cáo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    var filtered = _reports;
    
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((report) {
        return report['reportType'].toString().toLowerCase().contains(lowerQuery) ||
            report['content'].toString().toLowerCase().contains(lowerQuery);
      }).toList();
    }
    
    if (_selectedFilter == 'Chờ xử lý') {
      filtered = filtered.where((report) => report['status'] == 'pending').toList();
    } else if (_selectedFilter == 'Đã xử lý') {
      filtered = filtered.where((report) => report['status'] == 'resolved').toList();
    } else if (_selectedFilter == 'Đã từ chối') {
      filtered = filtered.where((report) => report['status'] == 'rejected').toList();
    }
    
    return filtered;
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý báo cáo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tìm kiếm'),
                  content: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Nhập từ khóa tìm kiếm...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      Navigator.of(context).pop();
                      _performSearch(value);
            },
          ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        Navigator.of(context).pop();
                        _performSearch('');
                      },
                      child: const Text('Xóa'),
                    ),
                    FilledButton(
            onPressed: () {
                        Navigator.of(context).pop();
                        _performSearch(_searchController.text);
                      },
                      child: const Text('Tìm'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _selectedFilter == 'Tất cả',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Tất cả';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chờ xử lý'),
                  selected: _selectedFilter == 'Chờ xử lý',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Chờ xử lý';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Đã xử lý'),
                  selected: _selectedFilter == 'Đã xử lý',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Đã xử lý';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Đã từ chối'),
                  selected: _selectedFilter == 'Đã từ chối',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Đã từ chối';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Reports list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? _EmptyReportsList()
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            final status = report['status'] ?? 'pending';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                  child: Icon(
                                    Icons.report,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                                title: Text(report['reportType'] ?? 'Báo cáo'),
                                subtitle: Text(
                                  '${report['reporterName'] ?? 'Unknown'} • ${report['content']?.toString().substring(0, report['content'].toString().length > 50 ? 50 : report['content'].toString().length)}${report['content'].toString().length > 50 ? '...' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(
                                        status == 'pending' ? 'Chờ xử lý' :
                                        status == 'resolved' ? 'Đã xử lý' : 'Đã từ chối',
                                      ),
                                      backgroundColor: status == 'pending' ? Colors.orange[100] :
                                          status == 'resolved' ? Colors.green[100] : Colors.red[100],
                                      labelStyle: const TextStyle(fontSize: 12),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.reportDetail,
                                    arguments: report['reportId'] ?? report['id'],
                                  ).then((_) => _loadReports());
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReportsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.report_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có báo cáo nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Danh sách báo cáo sẽ hiển thị ở đây',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}
