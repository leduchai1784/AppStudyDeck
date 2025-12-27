import 'package:flutter/material.dart';
import '../../../data/datasources/firestore_repository.dart';
import '../../routes/app_routes.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  
  const UserDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final FirestoreRepository _firestoreRepo = FirestoreRepository();
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _userStatistics;
  List<Map<String, dynamic>> _userDecks = [];
  bool _isLoading = true;
  bool _isLoadingDecks = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await _firestoreRepo.getUserById(widget.userId);
      if (user != null) {
        final stats = await _firestoreRepo.getUserStatistics(widget.userId);
        final decks = await _firestoreRepo.getDecksByAuthor(widget.userId);
        setState(() {
          _user = user;
          _userStatistics = stats;
          _userDecks = decks;
          _isLoading = false;
        });
        debugPrint('✅ Loaded user: ${user['name']}');
        debugPrint('✅ User statistics: $stats');
        debugPrint('✅ User decks: ${decks.length}');
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải thông tin người dùng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserDecks() async {
    setState(() {
      _isLoadingDecks = true;
    });
    try {
      final decks = await _firestoreRepo.getDecksByAuthor(widget.userId);
      setState(() {
        _userDecks = decks;
        _isLoadingDecks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDecks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết người dùng')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết người dùng')),
        body: const Center(child: Text('Không tìm thấy người dùng')),
      );
    }

    final isBlocked = (_user!['isBlocked'] as bool?) == true;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết người dùng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _showEditUserDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMenuDialog();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUser,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          if (isBlocked)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.block,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _user!['name'] ?? 'Unknown',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user!['email'] ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${widget.userId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          Chip(
                            label: Text(_user!['role'] == 'admin' ? 'Admin' : 'Người dùng'),
                            avatar: Icon(
                              _user!['role'] == 'admin' ? Icons.admin_panel_settings : Icons.person,
                              size: 18,
                            ),
                            backgroundColor: _user!['role'] == 'admin' 
                                ? Colors.purple[100] 
                                : Colors.blue[100],
                          ),
                          Chip(
                            label: Text(isBlocked ? 'Bị khóa' : 'Hoạt động'),
                            avatar: Icon(
                              isBlocked ? Icons.block : Icons.check_circle,
                              size: 18,
                              color: isBlocked ? Colors.red : Colors.green,
                            ),
                            backgroundColor: isBlocked ? Colors.red[100] : Colors.green[100],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_user!['createdAt'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Tham gia: ${_formatDate(_user!['createdAt'])}',
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
              
              // Statistics
              Card(
                child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Thống kê',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_userStatistics != null) ...[
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        children: [
                          _InfoCard(
                            icon: Icons.collections_bookmark,
                            label: 'Deck đã tạo',
                            value: '${_userStatistics!['totalDecks'] ?? 0}',
                            color: Colors.blue,
                          ),
                          _InfoCard(
                            icon: Icons.credit_card,
                            label: 'Flashcard đã tạo',
                            value: '${_userStatistics!['totalFlashcards'] ?? 0}',
                            color: Colors.green,
                          ),
                          _InfoCard(
                            icon: Icons.school,
                            label: 'Deck đã học',
                            value: '${_userStatistics!['decksStudied'] ?? 0}',
                            color: Colors.orange,
                          ),
                          _InfoCard(
                            icon: Icons.book,
                            label: 'Flashcard đã học',
                            value: '${_userStatistics!['flashcardsStudied'] ?? 0}',
                            color: Colors.purple,
                          ),
                          _InfoCard(
                            icon: Icons.access_time,
                            label: 'Phiên học',
                            value: '${_userStatistics!['studySessions'] ?? 0}',
                            color: Colors.teal,
                          ),
                          _InfoCard(
                            icon: Icons.calendar_today,
                            label: 'Ngày tham gia',
                            value: _formatDate(_userStatistics!['joinDate']),
                            color: Colors.indigo,
                          ),
                        ],
                      ),
                    ] else ...[
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      )),
                    ],
                  ],
                ),
              ),
              ),
              const SizedBox(height: 16),
              
              // User's Decks
              Card(
                child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.collections_bookmark, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Deck của người dùng',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _loadUserDecks,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Làm mới',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingDecks)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_userDecks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.collections_bookmark_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Chưa có deck nào',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _userDecks.length > 5 ? 5 : _userDecks.length,
                        itemBuilder: (context, index) {
                          final deck = _userDecks[index];
                          final status = deck['approvalStatus'] ?? 'pending';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.collections_bookmark,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Text(deck['name'] ?? 'Unknown'),
                            subtitle: Text('${deck['flashcardCount'] ?? 0} flashcard'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    status == 'approved' ? 'Đã duyệt' :
                                    status == 'rejected' ? 'Từ chối' : 'Chờ duyệt',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: status == 'approved' ? Colors.green[100] :
                                      status == 'rejected' ? Colors.red[100] : Colors.orange[100],
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.deckDetail,
                                arguments: deck['deckId'],
                              );
                            },
                          );
                        },
                      ),
                    if (_userDecks.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Center(
                          child: TextButton(
                            onPressed: () {
                              // TODO: Navigate to full deck list for this user
                            },
                            child: Text('Xem tất cả ${_userDecks.length} deck'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 16),
              
              // Actions
              Card(
                child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Thao tác',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        _showEditUserDialog();
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Chỉnh sửa thông tin'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_user!['role'] != 'admin')
                      OutlinedButton.icon(
                        onPressed: () {
                          _showChangeRoleDialog();
                        },
                        icon: const Icon(Icons.admin_panel_settings),
                        label: const Text('Thay đổi quyền'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    if (_user!['role'] != 'admin') const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        _showResetPasswordDialog();
                      },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Đặt lại mật khẩu'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        _toggleBlockUser();
                      },
                      icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                      label: Text(isBlocked ? 'Mở khóa tài khoản' : 'Khóa tài khoản'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        _showDeleteConfirmDialog();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa người dùng'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: Colors.red,
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

  void _showEditUserDialog() {
    final nameController = TextEditingController(text: _user?['name']?.toString());
    final emailController = TextEditingController(text: _user?['email']?.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa người dùng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tên không được để trống'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (emailController.text.trim().isEmpty || 
                  !emailController.text.trim().contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email không hợp lệ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await _firestoreRepo.updateUser(widget.userId, {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                });
                if (mounted) {
                  Navigator.of(context).pop();
                  await _loadUser();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật thông tin'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
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
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showChangeRoleDialog() {
    final currentRole = _user!['role'] ?? 'user';
    String? selectedRole = currentRole;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thay đổi quyền'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Người dùng'),
                subtitle: const Text('Quyền truy cập thông thường'),
                value: 'user',
                groupValue: selectedRole,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('Admin'),
                subtitle: const Text('Quyền quản trị hệ thống'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() {
                      selectedRole = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedRole == null || selectedRole == currentRole) {
                  Navigator.of(context).pop();
                  return;
                }
                
                try {
                  await _firestoreRepo.updateUser(widget.userId, {
                    'role': selectedRole,
                  });
                  if (mounted) {
                    Navigator.of(context).pop();
                    await _loadUser();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã thay đổi quyền thành ${selectedRole == 'admin' ? 'Admin' : 'Người dùng'}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Lỗi: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lưu ý: Tính năng này cần Cloud Functions hoặc Admin SDK',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mật khẩu phải có ít nhất 6 ký tự'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await _firestoreRepo.resetUserPassword(widget.userId, passwordController.text);
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã đặt lại mật khẩu'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
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
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
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
              leading: const Icon(Icons.delete_outline),
              title: const Text('Xóa người dùng'),
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
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa người dùng này? Tất cả dữ liệu liên quan sẽ bị xóa.'),
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
                await _firestoreRepo.deleteUser(widget.userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa người dùng'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop(); // Return to previous screen
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi xóa người dùng: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBlockUser() async {
    final currentIsBlocked = (_user!['isBlocked'] as bool?) == true;
    final action = currentIsBlocked ? 'Mở khóa' : 'Khóa';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xác nhận $action'),
        content: Text('Bạn có chắc chắn muốn $action tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _firestoreRepo.toggleBlockUser(widget.userId, !currentIsBlocked);
                Navigator.of(context).pop();
                await _loadUser();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã $action tài khoản'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
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
            child: Text(action),
          ),
        ],
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
        // FirestoreRepository converts Timestamp to ISO8601 string
        String dateStr = dateValue.toString().trim();
        if (dateStr.isEmpty || dateStr == 'null') return 'N/A';
        
        // Remove any extra text if it's a Timestamp string representation
        if (dateStr.contains('Timestamp')) {
          // Extract ISO8601 part if present
          final isoMatch = RegExp(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})').firstMatch(dateStr);
          if (isoMatch != null) {
            dateStr = isoMatch.group(1)!;
          } else {
            // Try to extract seconds
            final match = RegExp(r'seconds=(\d+)').firstMatch(dateStr);
            if (match != null) {
              final seconds = int.parse(match.group(1)!);
              date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
              return '${date.day}/${date.month}/${date.year}';
            }
            return 'N/A';
          }
        }
        
        // Parse ISO8601 string
        date = DateTime.parse(dateStr);
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      // Return a short fallback instead of the full error string
      return 'N/A';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: cardColor),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

