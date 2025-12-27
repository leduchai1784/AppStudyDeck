import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tất cả';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final users = await _firestoreRepo.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
      debugPrint('✅ Loaded ${users.length} users');
    } catch (e) {
      debugPrint('❌ Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách người dùng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users;
    
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((user) {
        final name = (user['name'] as String? ?? '').toLowerCase();
        final email = (user['email'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || email.contains(lowerQuery);
      }).toList();
    }
    
    if (_selectedFilter == 'Người dùng') {
      filtered = filtered.where((user) => user['role'] == 'user').toList();
    } else if (_selectedFilter == 'Admin') {
      filtered = filtered.where((user) => user['role'] == 'admin').toList();
    } else if (_selectedFilter == 'Bị khóa') {
      filtered = filtered.where((user) => (user['isBlocked'] as bool?) == true).toList();
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
        title: const Text('Quản lý người dùng'),
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
                      hintText: 'Nhập tên hoặc email...',
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
                  label: const Text('Người dùng'),
                  selected: _selectedFilter == 'Người dùng',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Người dùng';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Admin'),
                  selected: _selectedFilter == 'Admin',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Admin';
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Bị khóa'),
                  selected: _selectedFilter == 'Bị khóa',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = 'Bị khóa';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? _EmptyUserList()
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.person,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(user['name'] ?? 'Unknown'),
                                subtitle: Text(user['email'] ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (user['role'] == 'admin')
                                      Chip(
                                        label: const Text('Admin'),
                                        labelStyle: const TextStyle(fontSize: 12),
                                      ),
                                    if ((user['isBlocked'] as bool?) == true)
                                      Chip(
                                        label: const Text('Khóa'),
                                        backgroundColor: Colors.red[100],
                                        labelStyle: const TextStyle(fontSize: 12),
                                      ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.userDetail,
                                    arguments: user['userId'] ?? user['id'],
                                  ).then((_) => _loadUsers());
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

class _EmptyUserList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có người dùng nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Danh sách người dùng sẽ hiển thị ở đây',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

