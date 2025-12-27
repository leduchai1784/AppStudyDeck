import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final success = await AuthService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Hide loading
        if (!context.mounted) return;
        Navigator.of(context).pop();

        if (success) {
          // Navigate to home screen (admin can access admin panel from Settings)
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email hoặc mật khẩu không đúng'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        // Hide loading
        if (!context.mounted) return;
        Navigator.of(context).pop();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AuthService.getErrorMessage(e)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Hide loading
        if (!context.mounted) return;
        Navigator.of(context).pop();
        
        // Extract error message
        String errorMessage = 'Đã xảy ra lỗi khi đăng nhập';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('permission-denied') || errorStr.contains('permission denied')) {
          errorMessage = 'Không có quyền truy cập.\nVui lòng kiểm tra Security Rules.';
        } else if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('unavailable')) {
          errorMessage = 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại.';
        } else if (errorStr.contains('firestore error')) {
          errorMessage = 'Lỗi kết nối với database.\nVui lòng thử lại sau.';
        } else {
          errorMessage = 'Đã xảy ra lỗi khi đăng nhập.\nVui lòng thử lại sau.';
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await AuthService.loginWithGoogle();
      
      if (context.mounted) Navigator.of(context).pop();

      if (success) {
        // Navigate to home screen (admin can access admin panel from Settings)
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng nhập với Google đã bị hủy'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AuthService.getErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
      } catch (e) {
        if (context.mounted) Navigator.of(context).pop();
        
        // Extract error message
        String errorMessage = 'Đã xảy ra lỗi khi đăng nhập với Google';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('bị khóa') || errorStr.contains('blocked')) {
          errorMessage = 'Tài khoản của bạn đã bị khóa.\nVui lòng liên hệ quản trị viên để được hỗ trợ.';
        } else if (errorStr.contains('sign_in_canceled') || errorStr.contains('cancelled')) {
          errorMessage = 'Đăng nhập với Google đã bị hủy';
        } else if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('unavailable')) {
          errorMessage = 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại.';
        } else if (errorStr.contains('permission-denied') || errorStr.contains('permission denied')) {
          errorMessage = 'Không có quyền truy cập.\nVui lòng kiểm tra Security Rules.';
        } else {
          errorMessage = 'Đã xảy ra lỗi khi đăng nhập với Google.\nVui lòng thử lại sau.';
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
  }

  Future<void> _handleFacebookLogin() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await AuthService.loginWithFacebook();
      
      if (context.mounted) Navigator.of(context).pop();

      if (success) {
        if (context.mounted) {
          if (AuthService.isAdmin) {
            Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng nhập với Facebook - Tính năng sẽ được thêm sau'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.school,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'Flashcard Study Deck',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập để tiếp tục',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Nhập email của bạn',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!value.contains('@')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Nhập mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outlined),
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
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.forgotPassword);
                      },
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login button
                  FilledButton(
                    onPressed: _handleLogin,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Divider with text
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Hoặc',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Social login buttons
                  OutlinedButton.icon(
                    onPressed: () {
                      _handleGoogleLogin();
                    },
                    icon: Image.asset(
                      'assets/icons/google.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.g_mobiledata, size: 24);
                      },
                    ),
                    label: const Text('Đăng nhập với Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      _handleFacebookLogin();
                    },
                    icon: const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2)),
                    label: const Text('Đăng nhập với Facebook'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Chưa có tài khoản? '),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.register);
                        },
                        child: const Text('Đăng ký'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

