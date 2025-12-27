import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/datasources/firestore_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  File? _selectedImage;
  String? _avatarUrl;
  final _firestoreRepo = FirestoreRepository();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final currentUser = AuthService.currentUser;
    if (currentUser != null) {
      _nameController.text = currentUser['name'] ?? '';
      _emailController.text = currentUser['email'] ?? '';
      _avatarUrl = currentUser['avatarUrl'] ?? currentUser['photoUrl'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn ảnh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chụp ảnh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            if (_avatarUrl != null || _selectedImage != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa ảnh đại diện', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _avatarUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendVerificationEmail() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await AuthService.sendEmailVerification();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Email xác thực đã được gửi!\nVui lòng kiểm tra hộp thư của bạn.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(AuthService.getEmailVerificationErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final userId = AuthService.currentUserId;
    final firebaseUser = AuthService.firebaseUser;

    if (userId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin người dùng'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updates = <String, dynamic>{};
      final currentUser = AuthService.currentUser;
      final isEmailProvider = (currentUser?['provider'] ?? 'email') == 'email';
      final emailChanged = isEmailProvider &&
          _emailController.text.trim() != (currentUser?['email'] ?? '');

      // Handle avatar upload/delete
      if (_selectedImage != null) {
        // Upload new avatar
        setState(() {
          _isUploadingAvatar = true;
        });
        try {
          final downloadUrl = await StorageService.uploadAvatar(
            userId: userId,
            imageFile: _selectedImage!,
          );
          updates['avatarUrl'] = downloadUrl;
          if (firebaseUser != null) {
            await firebaseUser.updatePhotoURL(downloadUrl);
            await firebaseUser.reload();
          }
        } catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Lỗi upload ảnh: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() {
            _isSaving = false;
            _isUploadingAvatar = false;
          });
          return;
        }
        setState(() {
          _isUploadingAvatar = false;
        });
      } else if (_avatarUrl == null && currentUser?['avatarUrl'] != null) {
        // Delete avatar
        try {
          await StorageService.deleteAvatar(userId);
          updates['avatarUrl'] = null;
          if (firebaseUser != null) {
            await firebaseUser.updatePhotoURL(null);
            await firebaseUser.reload();
          }
        } catch (e) {
          debugPrint('Warning: Failed to delete avatar: $e');
        }
      }

      // Update name if changed
      if (_nameController.text.trim() != (currentUser?['name'] ?? '')) {
        updates['name'] = _nameController.text.trim();
        
        // Also update Firebase Auth displayName
        try {
          if (firebaseUser != null) {
            await firebaseUser.updateDisplayName(_nameController.text.trim());
            await firebaseUser.reload();
          }
        } catch (e) {
          debugPrint('Warning: Failed to update Firebase Auth displayName: $e');
        }
      }

      // Update email if changed (requires reauthentication)
      if (emailChanged) {
        if (_passwordController.text.isEmpty) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Vui lòng nhập mật khẩu để đổi email'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isSaving = false;
          });
          return;
        }

        try {
          await AuthService.updateEmail(
            newEmail: _emailController.text.trim(),
            currentPassword: _passwordController.text,
          );
          updates['email'] = _emailController.text.trim();
          updates['emailVerified'] = false; // Email mới cần verify lại
        } on FirebaseAuthException catch (e) {
          if (mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(AuthService.getEmailUpdateErrorMessage(e)),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      if (updates.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Không có thay đổi nào'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isSaving = false;
        });
        return;
      }

      // Update Firestore
      await _firestoreRepo.updateUser(userId, updates);

      // Reload user data
      await AuthService.initialize();

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thông tin thành công!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Chưa có';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Chưa có';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.currentUser;
    final provider = currentUser?['provider'] ?? 'email';
    final isEmailProvider = provider == 'email';
    final emailVerified = AuthService.firebaseUser?.emailVerified ?? false;
    final role = currentUser?['role'] ?? 'user';
    final createdAt = currentUser?['createdAt'];
    final lastLoginAt = currentUser?['lastLoginAt'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa thông tin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                      child: _selectedImage == null &&
                              (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? Text(
                              (_nameController.text.isNotEmpty
                                      ? _nameController.text[0]
                                      : 'U')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 20),
                          color: Theme.of(context).colorScheme.onPrimary,
                          onPressed: _isUploadingAvatar ? null : _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUploadingAvatar)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 24),

              // Info card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEmailProvider
                              ? 'Bạn có thể chỉnh sửa tên và email của mình'
                              : 'Bạn chỉ có thể chỉnh sửa tên. Email được quản lý bởi ${provider == 'google' ? 'Google' : 'Facebook'}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Họ và tên',
                  hintText: 'Nhập họ và tên',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập họ và tên';
                  }
                  if (value.trim().length < 2) {
                    return 'Họ và tên phải có ít nhất 2 ký tự';
                  }
                  if (value.trim().length > 50) {
                    return 'Họ và tên không được quá 50 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                enabled: isEmailProvider,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Nhập email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: isEmailProvider && !emailVerified
                      ? IconButton(
                          icon: const Icon(Icons.verified_user_outlined, color: Colors.orange),
                          tooltip: 'Email chưa được xác thực',
                          onPressed: _handleSendVerificationEmail,
                        )
                      : isEmailProvider && emailVerified
                          ? const Icon(Icons.verified, color: Colors.green)
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: isEmailProvider
                      ? (emailVerified
                          ? 'Email đã được xác thực'
                          : 'Email chưa được xác thực. Nhấn vào icon để gửi email xác thực')
                      : 'Email được quản lý bởi ${provider == 'google' ? 'Google' : 'Facebook'}',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập email';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Email không hợp lệ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field (only show if email changed)
              if (isEmailProvider &&
                  _emailController.text.trim() != (currentUser?['email'] ?? ''))
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu để xác nhận đổi email',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (_emailController.text.trim() != (currentUser?['email'] ?? '')) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu để đổi email';
                      }
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),

              // Read-only information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thông tin tài khoản',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Vai trò', role == 'admin' ? 'Quản trị viên' : 'Người dùng'),
                      const Divider(height: 1),
                      _buildInfoRow('Nhà cung cấp', provider == 'google'
                          ? 'Google'
                          : provider == 'facebook'
                              ? 'Facebook'
                              : 'Email'),
                      const Divider(height: 1),
                      _buildInfoRow('Ngày tạo', _formatDate(createdAt)),
                      const Divider(height: 1),
                      _buildInfoRow('Đăng nhập cuối', _formatDate(lastLoginAt)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save button
              FilledButton(
                onPressed: (_isSaving || _isUploadingAvatar) ? null : _handleSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: (_isSaving || _isUploadingAvatar)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
