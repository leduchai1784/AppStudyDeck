import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
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
        final success = await AuthService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );

        // Hide loading
        if (context.mounted) Navigator.of(context).pop();

        // Check if registration was successful
        if (success) {
          // Registration successful - logout user and navigate to login
          // This ensures user must login explicitly after registration
          try {
            await AuthService.logout();
            debugPrint('✅ User logged out after successful registration');
          } catch (logoutError) {
            debugPrint('⚠️ Warning: Failed to logout after registration: $logoutError');
            // Continue anyway - navigation will still work
          }
          
          // Show success message and navigate to login
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đăng ký thành công! Vui lòng đăng nhập.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Navigate to login screen after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            });
          }
        } else {
          // Registration failed but no exception was thrown
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đăng ký thất bại. Vui lòng thử lại.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        // Hide loading
        if (context.mounted) Navigator.of(context).pop();
        
        if (context.mounted) {
          final errorMessage = AuthService.getErrorMessage(e);
          
          // Show error with action button if email already in use
          if (e.code == 'email-already-in-use') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Đăng nhập',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pop(); // Go back to login
                  },
                ),
              ),
            );
          } else if (e.code == 'network-request-failed') {
            // Show network error with longer duration
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Đóng',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        // Hide loading
        if (!context.mounted) return;
        Navigator.of(context).pop();
        
        // Log error details for debugging
        debugPrint('❌ Registration error: $e');
        debugPrint('❌ Error type: ${e.runtimeType}');
        debugPrint('❌ Stack trace: $stackTrace');
        
        // Extract error message
        String errorMessage = 'Đã xảy ra lỗi khi đăng ký';
        final errorStr = e.toString().toLowerCase();
        final errorMessageStr = e.toString();
        
        // Check for specific Firebase/Firestore errors first
        // Note: Type casting errors are now handled gracefully in AuthService
        // They should not cause registration to fail if document was created successfully
        if (errorStr.contains('permission-denied') || errorStr.contains('permission denied')) {
          errorMessage = 'Không có quyền truy cập Firestore.\nVui lòng kiểm tra Security Rules trong Firebase Console.';
        } else if (errorStr.contains('document was not created') || 
                   errorStr.contains('không thể xác minh') ||
                   errorStr.contains('không thể tạo tài khoản')) {
          errorMessage = 'Không thể tạo tài khoản trong database.\nVui lòng kiểm tra Security Rules hoặc thử lại sau.';
        } else if (errorStr.contains('user not authenticated') || 
                   errorStr.contains('authentication failed') ||
                   errorStr.contains('user authentication failed')) {
          errorMessage = 'Lỗi xác thực người dùng.\nVui lòng thử lại.';
        } else if (errorStr.contains('firestore error')) {
          // Extract the actual Firestore error code if available
          if (errorStr.contains('permission-denied')) {
            errorMessage = 'Không có quyền truy cập Firestore.\nVui lòng kiểm tra Security Rules.';
          } else if (errorStr.contains('unavailable')) {
            errorMessage = 'Firestore không khả dụng.\nVui lòng kiểm tra kết nối internet và thử lại.';
          } else {
            errorMessage = 'Lỗi kết nối với database.\nVui lòng thử lại sau.';
          }
        } else if (errorStr.contains('network-request-failed') || 
                   (errorStr.contains('network') && errorStr.contains('failed'))) {
          errorMessage = 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại.';
        } else if (errorStr.contains('unavailable') && !errorStr.contains('firestore')) {
          errorMessage = 'Dịch vụ không khả dụng.\nVui lòng thử lại sau.';
        } else {
          // Show detailed error for debugging (can be removed in production)
          errorMessage = 'Đã xảy ra lỗi khi đăng ký.\n\nChi tiết: ${errorMessageStr.length > 100 ? errorMessageStr.substring(0, 100) + '...' : errorMessageStr}';
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Đóng',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    }
  }

  void _handleGoogleRegister() {
    // TODO: Implement Google Sign In/Up
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đăng ký với Google - Tính năng sẽ được thêm sau'),
      ),
    );
    // After successful registration, navigate to home
    // Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  void _handleFacebookRegister() {
    // TODO: Implement Facebook Sign In/Up
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đăng ký với Facebook - Tính năng sẽ được thêm sau'),
      ),
    );
    // After successful registration, navigate to home
    // Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký'),
      ),
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
                  // Icon
                  Icon(
                    Icons.person_add,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    'Tạo tài khoản mới',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Họ và tên',
                      hintText: 'Nhập họ và tên của bạn',
                      prefixIcon: const Icon(Icons.person_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập họ và tên';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
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
                  const SizedBox(height: 16),
                  
                  // Confirm password field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận mật khẩu',
                      hintText: 'Nhập lại mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng xác nhận mật khẩu';
                      }
                      if (value != _passwordController.text) {
                        return 'Mật khẩu không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Register button
                  FilledButton(
                    onPressed: _handleRegister,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đăng ký',
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
                  
                  // Social register buttons
                  OutlinedButton.icon(
                    onPressed: () {
                      _handleGoogleRegister();
                    },
                    icon: Image.asset(
                      'assets/icons/google.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.g_mobiledata, size: 24);
                      },
                    ),
                    label: const Text('Đăng ký với Google'),
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
                      _handleFacebookRegister();
                    },
                    icon: const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2)),
                    label: const Text('Đăng ký với Facebook'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Đã có tài khoản? '),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Đăng nhập'),
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

