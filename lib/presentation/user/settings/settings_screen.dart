import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../routes/app_routes.dart';

class SettingsScreen extends StatelessWidget {
  final bool fromAdmin;
  
  const SettingsScreen({super.key, this.fromAdmin = false});

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      try {
        await AuthService.logout();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.login,
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi đăng xuất: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final userEmail = currentUser?['email'] ?? '';
    final userName = currentUser?['name'] ?? 'User';
    final provider = currentUser?['provider'] ?? 'email';
    final isEmailProvider = provider == 'email';
    final isAdmin = AuthService.isAdmin;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Card(
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.editProfile);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  provider == 'google'
                                      ? Icons.g_mobiledata
                                      : provider == 'facebook'
                                          ? Icons.facebook
                                          : Icons.email,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  provider == 'google'
                                      ? 'Google'
                                      : provider == 'facebook'
                                          ? 'Facebook'
                                          : 'Email',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
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
            ),
            const SizedBox(height: 16),

            // Account Settings
            Text(
              'Tài khoản',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Chỉnh sửa thông tin'),
                    subtitle: const Text('Thay đổi tên và email'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.editProfile);
                    },
                  ),
                  if (isEmailProvider) const Divider(height: 1),
                  if (isEmailProvider)
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Đổi mật khẩu'),
                      subtitle: const Text('Thay đổi mật khẩu tài khoản'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.changePassword);
                      },
                    ),
                  if (isAdmin && !fromAdmin) const Divider(height: 1),
                  if (isAdmin && !fromAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings),
                      title: const Text('Quản lý'),
                      subtitle: const Text('Trang quản trị'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.adminHome,
                          (route) => false,
                        );
                      },
                    ),
                  if (fromAdmin) const Divider(height: 1),
                  if (fromAdmin)
                    ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('Về trang chủ'),
                      subtitle: const Text('Trang chủ người dùng'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (route) => false,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Settings
            Text(
              'Ứng dụng',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                    ),
                    title: const Text('Chủ đề'),
                    subtitle: Text(
                      themeProvider.themeMode == ThemeMode.system
                          ? 'Theo hệ thống'
                          : themeProvider.themeMode == ThemeMode.dark
                              ? 'Tối'
                              : 'Sáng',
                    ),
                    trailing: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (value) {
                        themeProvider.toggleTheme();
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Về ứng dụng'),
                    subtitle: const Text('Thông tin phiên bản'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Flashcard Study Deck',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(Icons.school, size: 48),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout
            Card(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Đăng xuất',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _handleLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
